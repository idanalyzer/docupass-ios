import Combine
import Foundation

public final class DocupassSubscription {
    private var cancellable: AnyCancellable?
    init(_ cancellable: AnyCancellable) { self.cancellable = cancellable }
    public func close() { cancellable?.cancel(); cancellable = nil }
    deinit { close() }
}

@MainActor
public final class DocupassKycSession {
    public let controller: DocupassKycController

    public init(config: DocupassApiConfig, workflow: [KYCStep] = DocupassWorkflow.defaultWorkflow()) {
        controller = .init(config: config, workflow: workflow)
    }

    public var currentState: DocupassKycUiState { controller.state }

    public func subscribe(_ listener: @escaping (DocupassKycUiState) -> Void) -> DocupassSubscription {
        DocupassSubscription(controller.$state.sink(receiveValue: listener))
    }

    public func start() { controller.emit(.start) }
    public func refresh() { controller.emit(.refresh) }
    public func back() { controller.emit(.back) }
    public func clearError() { controller.emit(.clearError) }
    public func restart() { controller.emit(.restart) }
    public func sendPhoneCode(number: String?, type: String) { controller.emit(.sendPhoneCode(number: number, type: type)) }
    public func verifyPhoneCode(number: String?, code: String) { controller.emit(.verifyPhoneCode(number: number, code: code)) }
    public func saveCustomForm(answers: [String: String]) { controller.emit(.saveCustomForm(answers: answers)) }
    public func selectDocumentCountry(_ code: String) { controller.emit(.selectDocumentCountry(countryCode: code)) }
    public func selectDocumentType(_ code: String) { controller.emit(.selectDocumentType(documentTypeCode: code)) }
    public func uploadDocument(frontBase64: String, backBase64: String?) { controller.emit(.uploadDocument(frontBase64: frontBase64, backBase64: backBase64)) }
    public func uploadFace(_ images: [String]) { controller.emit(.uploadFace(faceBase64List: images)) }
    public func submitContract(_ signatures: [String: String]) { controller.emit(.submitContract(signatures: signatures)) }
    public func close() { controller.close() }
}
