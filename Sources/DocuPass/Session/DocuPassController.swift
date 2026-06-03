import Foundation

/// Observable state of the verification flow.
public enum DocuPassState {
    case idle
    case loading
    case step(DocuPassSession)
    case finished(DocuPassResult)
}

/// Headless driver for a DocuPass session. Owns the protocol state machine and
/// publishes it; SwiftUI (the bundled `DocuPassView` or your own) observes `state`
/// and calls the submit* methods with captured data. Capture lives in the UI.
@MainActor
public final class DocuPassController: ObservableObject {
    public let config: DocuPassConfig
    public let client: DocuPassClient

    @Published public private(set) var state: DocuPassState = .idle
    /// Last recoverable rejection (DOCUMENT_REJECTED / FACE_REJECTED / …).
    @Published public var transientError: DocuPassError?

    public init(config: DocuPassConfig) {
        self.config = config
        self.client = DocuPassClient(config: config)
    }

    public func setGeolocation(latitude: Double, longitude: Double, accuracy: Double) {
        client.setGeolocation(latitude: latitude, longitude: longitude, accuracy: accuracy)
    }

    public func start() async { await run { try await self.client.getAction() } }
    public func refresh() async { await run { try await self.client.getAction() } }

    public func submitDocumentSelection(country: String, type: String) async {
        await run { try await self.client.saveDocumentSelection(country: country, type: type) }
    }
    public func submitDocument(frontBase64: String, backBase64: String?) async {
        await run { try await self.client.uploadDocument(frontBase64: frontBase64, backBase64: backBase64) }
    }
    public func submitForm(answers: [String: String]) async {
        await run { try await self.client.saveForm(answers: answers) }
    }
    public func submitFace(frames: [String], faceVideo: String? = nil) async {
        await run { try await self.client.uploadFace(frames: frames, faceVideo: faceVideo) }
    }
    public func submitContract(signatures: [String: String]) async {
        await run { try await self.client.submitContract(signatures: signatures) }
    }

    public func sendPhoneCode(number: String?, channel: PhoneChannel) async {
        do { _ = try await client.createPhoneVerification(number: number, channel: channel) }
        catch let e as DocuPassError { handle(e) } catch {}
    }
    public func verifyPhoneCode(number: String?, code: String) async {
        do {
            _ = try await client.checkPhoneVerification(number: number, code: code)
            await run { try await self.client.getAction() }
        } catch let e as DocuPassError { handle(e) } catch {}
    }

    public func cancel() { state = .finished(.cancelled(reference: config.reference)) }

    private func run(_ call: @escaping () async throws -> DocuPassSession) async {
        if case .step = state {} else { state = .loading }
        do {
            let session = try await call()
            state = .step(session)
        } catch let e as DocuPassError {
            handle(e)
        } catch {
            state = .finished(.error(reference: config.reference,
                                     error: DocuPassError(code: "UNEXPECTED", message: error.localizedDescription)))
        }
    }

    private func handle(_ err: DocuPassError) {
        if err.isTerminal {
            state = .finished(mapTerminal(err))
        } else if err.isFatal || err.code == nil {
            state = .finished(.error(reference: config.reference, error: err))
        } else {
            transientError = err
            Task { await refresh() }
        }
    }

    private func mapTerminal(_ err: DocuPassError) -> DocuPassResult {
        let redirect = (err.message?.isEmpty == false) ? err.message : nil
        if err.code == DocuPassErrorCode.failed {
            return .failed(reference: config.reference, code: err.code, message: err.message, redirectURL: redirect)
        }
        return .completed(reference: config.reference, redirectURL: redirect, code: err.code)
    }
}
