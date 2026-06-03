import Foundation

/// Headless client for the DocuPass v3 mobile protocol (docupassappv3).
///
/// One instance == one session. Each call returns the latest ``DocuPassSession``
/// (POSTs return the next state too). Terminal/error states are thrown as
/// ``DocuPassError`` — inspect `code` against ``DocuPassErrorCode``.
public final class DocuPassClient {
    public let config: DocuPassConfig
    private let transport: HttpTransport
    private let decoder = JSONDecoder()

    public init(config: DocuPassConfig) {
        self.config = config
        self.transport = HttpTransport(
            baseURL: config.baseURL,
            reference: config.reference,
            partyId: config.partyId,
            timeout: config.timeout
        )
    }

    /// Set the GPS header (sent on subsequent requests) when the session asks for it.
    public func setGeolocation(latitude: Double, longitude: Double, accuracy: Double) {
        transport.geolocation = "\(latitude),\(longitude),\(accuracy)"
    }

    /// GET get_action — the state machine.
    public func getAction() async throws -> DocuPassSession {
        try parse(await transport.get("get_action"))
    }

    public func saveDocumentSelection(country: String, type: String) async throws -> DocuPassSession {
        try parse(await transport.post("save_document_selection", json: ["country": country, "type": type]))
    }

    public func uploadDocument(frontBase64: String, backBase64: String? = nil) async throws -> DocuPassSession {
        var body: [String: Any] = ["document": frontBase64]
        if let back = backBase64, !back.isEmpty { body["documentBack"] = back }
        return try parse(await transport.post("upload_document", json: body))
    }

    public func saveForm(answers: [String: String]) async throws -> DocuPassSession {
        try parse(await transport.post("save_form", json: answers))
    }

    public func uploadFace(frames: [String], faceVideo: String? = nil) async throws -> DocuPassSession {
        var body: [String: Any] = ["face": frames.joined(separator: ",")]
        if let v = faceVideo, !v.isEmpty { body["faceVideo"] = v }
        return try parse(await transport.post("upload_face", json: body))
    }

    public func submitContract(signatures: [String: String]) async throws -> DocuPassSession {
        try parse(await transport.post("submit_contract", json: signatures))
    }

    public func createPhoneVerification(number: String?, channel: PhoneChannel) async throws -> DocuPassSession {
        var body: [String: Any] = ["type": channel.rawValue]
        if let n = number, !n.isEmpty { body["number"] = n }
        return try parse(await transport.post("create_phone_verification", json: body))
    }

    public func checkPhoneVerification(number: String?, code: String) async throws -> DocuPassSession {
        var body: [String: Any] = ["code": code]
        if let n = number, !n.isEmpty { body["number"] = n }
        return try parse(await transport.post("check_phone_verification", json: body))
    }

    /// POST audit — best-effort telemetry; never throws.
    public func audit(action: String, data: [String] = []) async {
        await transport.postQuietly("audit", json: ["action": action, "data": data])
    }

    private func parse(_ data: Data) throws -> DocuPassSession {
        let session = try decoder.decode(DocuPassSession.self, from: data)
        if let sid = session.sessionId, !sid.isEmpty { transport.sessionId = sid }
        return session
    }
}
