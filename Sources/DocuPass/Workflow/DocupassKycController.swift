import Combine
import Foundation

public enum DocupassKycEvent: Equatable, Sendable {
    case loading
    case phoneVerification(state: DocupassSessionState, codeSent: Bool, currentNumber: String?)
    case customForm(fields: [DocupassCustomField])
    case documentCountrySelection(countries: [KYCCountry], selectedCountry: KYCCountry?)
    case documentSelection(country: KYCCountry, documentTypes: [KYCDocumentType], selectedDocumentType: KYCDocumentType?)
    case documentCapture(country: KYCCountry?, documentType: KYCDocumentType?, documentSide: Int?, allowFileUpload: Bool)
    case faceVerification(actions: [KYCAction])
    case contract(state: DocupassSessionState, html: String, signatureFields: [DocupassContractSignatureField])
    case partyPending
    case completed(result: KYCResult)
    case failed(result: KYCResult, error: DocupassNormalizedError?)

    public var kind: DocupassKycEventKind {
        switch self {
        case .loading: .loading
        case .phoneVerification: .phoneVerification
        case .customForm: .customForm
        case .documentCountrySelection: .documentCountrySelection
        case .documentSelection: .documentSelection
        case .documentCapture: .documentCapture
        case .faceVerification: .faceVerification
        case .contract: .contract
        case .partyPending: .partyPending
        case .completed: .completed
        case .failed: .failed
        }
    }

    var isResultScreen: Bool {
        if case .completed = self { return true }
        if case .failed = self { return true }
        return false
    }
}

public enum DocupassKycEventKind: String, Sendable {
    case loading, phoneVerification, customForm, documentCountrySelection, documentSelection
    case documentCapture, faceVerification, contract, partyPending, completed, failed
}

public enum DocupassKycIntent: Sendable {
    case start, refresh, back, clearError, restart
    case sendPhoneCode(number: String?, type: String)
    case verifyPhoneCode(number: String?, code: String)
    case saveCustomForm(answers: [String: String])
    case selectDocumentCountry(countryCode: String)
    case selectDocumentType(documentTypeCode: String)
    case uploadDocument(frontBase64: String, backBase64: String?)
    case uploadFace(faceBase64List: [String])
    case submitContract(signatures: [String: String])
}

public struct DocupassKycErrorEvent: Equatable, Sendable {
    public let message: String
    public let normalized: DocupassNormalizedError?

    public init(message: String, normalized: DocupassNormalizedError? = nil) {
        self.message = message; self.normalized = normalized
    }
}

public struct DocupassKycUiState: Equatable, Sendable {
    public var event: DocupassKycEvent
    public var result: KYCResult
    public var isBusy: Bool
    public var canGoBack: Bool
    public var error: DocupassKycErrorEvent?

    public init(event: DocupassKycEvent = .loading, result: KYCResult = .init(), isBusy: Bool = false, canGoBack: Bool = false, error: DocupassKycErrorEvent? = nil) {
        self.event = event; self.result = result; self.isBusy = isBusy; self.canGoBack = canGoBack; self.error = error
    }
}

@MainActor
public final class DocupassKycController: ObservableObject {
    @Published public private(set) var state = DocupassKycUiState()

    private let config: DocupassApiConfig
    private let workflow: [KYCStep]
    private let faceActionCandidates: [KYCAction]
    private let apiClient: DocupassApiClient
    private var runningTask: Task<Void, Never>?
    private var currentStepIndex = 0
    private var result = KYCResult()
    private var phoneCodeSent = false
    private var currentPhoneNumber: String?
    private var eventBackStack: [DocupassKycEvent] = []

    public init(config: DocupassApiConfig, workflow: [KYCStep] = DocupassWorkflow.defaultWorkflow(), apiClient: DocupassApiClient? = nil) {
        self.config = config
        self.workflow = normalizeWorkflow(workflow)
        self.faceActionCandidates = firstFaceActions(in: self.workflow)
        self.apiClient = apiClient ?? DocupassApiClient(config: config)
    }

    public func emit(_ intent: DocupassKycIntent) {
        switch intent {
        case .clearError: update { $0.error = nil }
        case .back: goBack()
        case .start: launch { await self.runStart() }
        case .refresh: launch { await self.refreshFromServer() }
        case .restart: launch { self.resetLocalState(); await self.runStart() }
        case let .sendPhoneCode(number, type): launch { await self.sendPhoneCode(number: number, type: type) }
        case let .verifyPhoneCode(number, code): launch { await self.verifyPhoneCode(number: number, code: code) }
        case let .saveCustomForm(answers): launch { await self.saveCustomForm(answers) }
        case let .selectDocumentCountry(code): selectDocumentCountry(code)
        case let .selectDocumentType(code): launch { await self.selectDocumentType(code) }
        case let .uploadDocument(front, back): launch { await self.uploadDocument(front: front, back: back) }
        case let .uploadFace(faces): launch { await self.uploadFace(faces) }
        case let .submitContract(signatures): launch { await self.submitContract(signatures) }
        }
    }

    public func start() { emit(.start) }
    public func refresh() { emit(.refresh) }
    public func close() {
        runningTask?.cancel()
        Task { await apiClient.close() }
    }

    private func launch(_ operation: @escaping @MainActor () async -> Void) {
        runningTask?.cancel()
        runningTask = Task { await operation() }
    }

    private func runStart() async {
        update { $0.event = .loading; $0.isBusy = config.enabled; $0.error = nil }
        if config.enabled { await refreshFromServer() } else { publishLocalStep() }
    }

    private func refreshFromServer() async {
        setBusy(true)
        defer { setBusy(false) }
        switch await apiClient.getAction() {
        case let .success(session): applySessionState(session)
        case let .failure(error): await handleApiError(error)
        }
    }

    private func sendPhoneCode(number: String?, type: String) async {
        setBusy(true); clearError()
        defer { setBusy(false) }
        switch await apiClient.createPhoneVerification(number: number, type: type) {
        case .success:
            phoneCodeSent = true; currentPhoneNumber = number; republishPhoneEvent()
        case let .failure(error): await handleApiError(error)
        }
    }

    private func verifyPhoneCode(number: String?, code: String) async {
        setBusy(true); clearError()
        defer { setBusy(false) }
        switch await apiClient.checkPhoneVerification(number: number, code: code) {
        case let .success(session): applySessionState(session)
        case let .failure(error): await handleApiError(error)
        }
    }

    private func saveCustomForm(_ answers: [String: String]) async {
        setBusy(true); clearError()
        defer { setBusy(false) }
        switch await apiClient.saveForm(answers) {
        case let .success(session): applySessionState(session)
        case let .failure(error): await handleApiError(error)
        }
    }

    private func selectDocumentCountry(_ code: String) {
        let country = countryFromCode(code)
        result.country = country
        setEvent(.documentSelection(country: country, documentTypes: documentTypesForFilter(result.sessionState?.acceptedDocumentTypeCodes), selectedDocumentType: result.documentType), recordHistory: true)
    }

    private func selectDocumentType(_ code: String) async {
        guard let country = result.country else { showLocalError("Please select country first."); return }
        guard let documentType = documentTypeFromCode(code) else { showLocalError("Unsupported document type."); return }
        result.documentType = documentType; update { $0.result = result; $0.error = nil }
        if !config.enabled {
            publishEvent(for: .captureDocument)
            return
        }
        setBusy(true); defer { setBusy(false) }
        switch await apiClient.saveDocumentSelection(countryCode: country.code, documentType: documentType.apiTypeCode) {
        case let .success(session): applySessionState(session)
        case let .failure(error): await handleApiError(error)
        }
    }

    private func uploadDocument(front: String, back: String?) async {
        result.documentFrontBase64 = front; result.documentBackBase64 = back
        if !config.enabled {
            currentStepIndex = nextWorkflowIndex(after: { if case .captureDocument = $0 { true } else { false } })
            publishLocalStep(); return
        }
        setBusy(true); clearError(); defer { setBusy(false) }
        switch await apiClient.uploadDocument(frontDocumentBase64: front, backDocumentBase64: back) {
        case let .success(session): applySessionState(session)
        case let .failure(error): await handleApiError(error)
        }
    }

    private func uploadFace(_ faces: [String]) async {
        result.faceBase64List = faces; result.isFaceVerified = true
        if !config.enabled {
            currentStepIndex = nextWorkflowIndex(after: { if case .faceVerification = $0 { true } else { false } })
            publishLocalStep(); return
        }
        setBusy(true); clearError(); defer { setBusy(false) }
        switch await apiClient.uploadFace(faces) {
        case let .success(session): applySessionState(session)
        case let .failure(error): await handleApiError(error)
        }
    }

    private func submitContract(_ signatures: [String: String]) async {
        setBusy(true); clearError(); defer { setBusy(false) }
        switch await apiClient.submitContract(signatures) {
        case let .success(session): applySessionState(session)
        case let .failure(error): await handleApiError(error)
        }
    }

    private func applySessionState(_ session: DocupassSessionState) {
        if let country = session.selectedDocumentCountry { result.country = countryFromCode(country) }
        if let type = session.selectedDocumentType { result.documentType = documentTypeFromCode(type) }
        result.serverTask = session.task; result.sessionId = session.sessionId; result.sessionState = session; result.terminalError = nil
        phoneCodeSent = false; currentPhoneNumber = nil
        setEvent(event(for: session), recordHistory: true)
    }

    private func handleApiError(_ error: DocupassApiError) async {
        let normalized = normalizeDocupassError(error)
        result.terminalError = normalized
        switch normalized.action {
        case .showCompleted: setEvent(.completed(result: result), recordHistory: true)
        case .showFailed: setEvent(.failed(result: result, error: normalized), recordHistory: true)
        case .resyncSession: await refreshFromServer()
        default: update { $0.result = result; $0.error = .init(message: formatApiErrorMessage(error), normalized: normalized) }
        }
    }

    private func event(for session: DocupassSessionState) -> DocupassKycEvent {
        switch session.task?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "phone": return .phoneVerification(state: session, codeSent: phoneCodeSent, currentNumber: currentPhoneNumber)
        case "customform": return .customForm(fields: session.customFields)
        case "document": return documentEvent(for: session)
        case "face": return .faceVerification(actions: randomizedFaceActions(faceActionCandidates))
        case "contract": return .contract(state: session, html: session.contractSource ?? "", signatureFields: extractContractSignatureFields(session.contractSource ?? ""))
        case "party_pending": return .partyPending
        default: return .completed(result: result)
        }
    }

    private func documentEvent(for session: DocupassSessionState) -> DocupassKycEvent {
        let selectedCountry = session.selectedDocumentCountry ?? result.country?.code
        let selectedType = session.selectedDocumentType ?? result.documentType?.apiTypeCode
        if selectedCountry?.isEmpty != false {
            return .documentCountrySelection(countries: countriesForFilter(session.acceptedDocumentCountryCodes.isEmpty ? nil : session.acceptedDocumentCountryCodes), selectedCountry: result.country)
        }
        if selectedType?.isEmpty != false {
            let country = countryFromCode(selectedCountry!)
            result.country = country
            return .documentSelection(country: country, documentTypes: documentTypesForFilter(session.acceptedDocumentTypeCodes), selectedDocumentType: result.documentType)
        }
        return .documentCapture(country: result.country, documentType: result.documentType, documentSide: session.documentSide, allowFileUpload: session.allowFileUpload)
    }

    private func publishLocalStep() { publishEvent(for: workflow.indices.contains(currentStepIndex) ? workflow[currentStepIndex] : .success) }

    private func publishEvent(for step: KYCStep) {
        let event: DocupassKycEvent
        switch step {
        case let .phoneVerification(session): event = .phoneVerification(state: session, codeSent: phoneCodeSent, currentNumber: currentPhoneNumber)
        case let .customForm(fields): event = .customForm(fields: fields)
        case let .selectCountry(filter): event = .documentCountrySelection(countries: countriesForFilter(filter), selectedCountry: result.country)
        case .selectDocument:
            if let country = result.country { event = .documentSelection(country: country, documentTypes: documentTypesForFilter(nil), selectedDocumentType: result.documentType) }
            else { event = .documentCountrySelection(countries: countriesForFilter(nil), selectedCountry: nil) }
        case .captureDocument: event = .documentCapture(country: result.country, documentType: result.documentType, documentSide: nil, allowFileUpload: false)
        case let .faceVerification(actions): event = .faceVerification(actions: randomizedFaceActions(actions))
        case let .contract(session): event = .contract(state: session, html: session.contractSource ?? "", signatureFields: extractContractSignatureFields(session.contractSource ?? ""))
        case .partyPending: event = .partyPending
        case .success: event = .completed(result: result)
        case let .failed(error): event = .failed(result: result, error: error)
        }
        setEvent(event, recordHistory: true)
        update { $0.isBusy = false }
    }

    private func republishPhoneEvent() {
        guard case let .phoneVerification(session, _, _) = state.event else { return }
        setEvent(.phoneVerification(state: session, codeSent: phoneCodeSent, currentNumber: currentPhoneNumber))
    }

    private func nextWorkflowIndex(after predicate: (KYCStep) -> Bool) -> Int {
        let current = workflow.firstIndex(where: predicate) ?? currentStepIndex
        return min(current + 1, workflow.count)
    }

    private func resetLocalState() {
        currentStepIndex = 0; result = .init(); phoneCodeSent = false; currentPhoneNumber = nil; eventBackStack = []; state = .init()
    }

    private func goBack() {
        guard !state.isBusy, let previous = eventBackStack.popLast() else { return }
        update { $0.event = previous; $0.error = nil }
    }

    private func setEvent(_ event: DocupassKycEvent, recordHistory: Bool = false) {
        let previous = state.event
        if recordHistory && previous != event && previous != .loading && !previous.isResultScreen { eventBackStack.append(previous) }
        if event.isResultScreen { eventBackStack.removeAll() }
        update { $0.event = event; $0.result = result; $0.error = nil }
    }

    private func setBusy(_ busy: Bool) { update { $0.isBusy = busy } }
    private func clearError() { update { $0.error = nil } }
    private func showLocalError(_ message: String) { update { $0.error = .init(message: message, normalized: nil) } }
    private func update(_ mutate: (inout DocupassKycUiState) -> Void) {
        var next = state; mutate(&next); next.canGoBack = !eventBackStack.isEmpty && !next.event.isResultScreen; state = next
    }
}
