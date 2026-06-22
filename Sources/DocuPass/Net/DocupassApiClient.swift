import Foundation

public actor DocupassApiClient {
    private let config: DocupassApiConfig
    private let session: URLSession
    private var runtimeSessionId: String?

    public init(config: DocupassApiConfig) {
        self.config = config
        self.runtimeSessionId = config.sessionId
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = config.timeout
        configuration.timeoutIntervalForResource = config.timeout
        self.session = URLSession(configuration: configuration, delegate: config.disableSSLValidation ? UnsafeTrustDelegate() : nil, delegateQueue: nil)
    }

    public func getAction() async -> DocupassApiResult<DocupassSessionState> { await requestSession(method: "GET", path: "get_action") }
    public func saveDocumentSelection(countryCode: String, documentType: String) async -> DocupassApiResult<DocupassSessionState> {
        await requestSession(method: "POST", path: "save_document_selection", body: ["country": countryCode, "type": documentType])
    }
    public func uploadDocument(frontDocumentBase64: String, backDocumentBase64: String?) async -> DocupassApiResult<DocupassSessionState> {
        guard !frontDocumentBase64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failure(.init(message: "Front document image is required.", code: "LOCAL_VALIDATION")) }
        var body = ["document": frontDocumentBase64]
        if let backDocumentBase64, !backDocumentBase64.isEmpty { body["documentBack"] = backDocumentBase64 }
        return await requestSession(method: "POST", path: "upload_document", body: body)
    }
    public func uploadFace(_ faceBase64List: [String]) async -> DocupassApiResult<DocupassSessionState> {
        let faces = faceBase64List.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !faces.isEmpty else { return .failure(.init(message: "At least one face image is required.", code: "LOCAL_VALIDATION")) }
        return await requestSession(method: "POST", path: "upload_face", body: ["face": faces.joined(separator: ",")])
    }
    public func createPhoneVerification(number: String?, type: String) async -> DocupassApiResult<Void> {
        await requestUnit(method: "POST", path: "create_phone_verification", body: ["type": type, "number": clean(number) ?? NSNull()])
    }
    public func checkPhoneVerification(number: String?, code: String) async -> DocupassApiResult<DocupassSessionState> {
        await requestSession(method: "POST", path: "check_phone_verification", body: ["code": code.trimmingCharacters(in: .whitespacesAndNewlines), "number": clean(number) ?? NSNull()])
    }
    public func saveForm(_ answers: [String: String]) async -> DocupassApiResult<DocupassSessionState> {
        await requestSession(method: "POST", path: "save_form", body: answers)
    }
    public func submitContract(_ signatures: [String: String]) async -> DocupassApiResult<DocupassSessionState> {
        await requestSession(method: "POST", path: "submit_contract", body: signatures)
    }
    public func logAuditData(action: String, data: [String]) async -> DocupassApiResult<Void> {
        await requestUnit(method: "POST", path: "audit", body: ["action": action, "data": data])
    }
    public func close() { session.invalidateAndCancel() }

    func authorizationHeader() -> String? {
        if let authorization = clean(config.authorization) { return authorization }
        if let sessionId = clean(runtimeSessionId) { return "DOCUPASS_SESSION \(sessionId)" }
        guard let reference = clean(config.reference) else { return nil }
        return clean(config.partyId).map { "DOCUPASS \(reference) \($0)" } ?? "DOCUPASS \(reference)"
    }

    private func requestSession(method: String, path: String, body: [String: Any]? = nil) async -> DocupassApiResult<DocupassSessionState> {
        switch await requestJSON(method: method, path: path, body: body) {
        case let .success((json, raw)):
            let state = parseSession(json, raw: raw)
            if let sessionId = state.sessionId, !sessionId.isEmpty { runtimeSessionId = sessionId }
            return .success(state)
        case let .failure(error): return .failure(error)
        }
    }

    private func requestUnit(method: String, path: String, body: [String: Any]? = nil) async -> DocupassApiResult<Void> {
        switch await requestJSON(method: method, path: path, body: body) {
        case .success: return .success(())
        case let .failure(error): return .failure(error)
        }
    }

    private func requestJSON(method: String, path: String, body: [String: Any]?) async -> DocupassApiResult<([String: Any], String)> {
        guard let url = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) else {
            return .failure(.init(message: "Invalid DocuPass API URL.", code: "LOCAL_VALIDATION"))
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = config.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authorization = authorizationHeader() { request.setValue(authorization, forHTTPHeaderField: "Authorization") }
        if let geolocation = clean(config.geolocation) { request.setValue(geolocation, forHTTPHeaderField: "Geolocation") }
        if method == "POST" { request.httpBody = try? JSONSerialization.data(withJSONObject: body ?? [:]) }

        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? ""
            let json = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
            if !(200...299).contains(status) || json["error"] is [String: Any] || bool(json["success"], default: true) == false {
                let errorJSON = json["error"] as? [String: Any] ?? json
                let message = string(errorJSON["message"]) ?? string(json["message"]) ?? (status > 0 ? "HTTP \(status)" : "DocuPass API returned error")
                let error = DocupassApiError(message: message, code: string(errorJSON["code"]), httpStatus: status, rawBody: raw)
                log(error, method: method, url: url)
                return .failure(error)
            }
            return .success((json, raw))
        } catch {
            let apiError = DocupassApiError(message: error.localizedDescription, code: "NETWORK_ERROR")
            log(apiError, method: method, url: url)
            return .failure(apiError)
        }
    }

    private var baseURL: String {
        clean(config.baseURL) ?? resolveDocupassEndpoint(config.reference)
    }

    private func log(_ error: DocupassApiError, method: String, url: URL) {
        var parts = ["[DocuPassApiError]", "endpoint=\(url.absoluteString)", "method=\(method)"]
        if let status = error.httpStatus { parts.append("httpStatus=\(status)") }
        if let code = error.code { parts.append("code=\(code)") }
        parts.append("message=\(error.message)")
        if let raw = error.rawBody, !raw.isEmpty { parts.append("rawBody=\(String(raw.prefix(2_000)))") }
        NSLog("%@", parts.joined(separator: " "))
    }
}

private func parseSession(_ json: [String: Any], raw: String) -> DocupassSessionState {
    let fields = (json["customField"] as? [[String: Any]] ?? []).map {
        DocupassCustomField(fieldId: string($0["fieldId"]) ?? "", fieldLabel: string($0["fieldLabel"]) ?? "", fieldDescription: string($0["fieldDescription"]) ?? "", fieldType: int($0["fieldType"]), fieldData: string($0["fieldData"]) ?? "")
    }
    let countryCodes = (json["phoneCountryCode"] as? [[String: Any]] ?? []).compactMap { value -> DocupassPhoneCountryCode? in
        guard let dialCode = string(value["dial_code"]), !dialCode.isEmpty else { return nil }
        return .init(name: string(value["name"]) ?? "", dialCode: dialCode, code: string(value["code"]) ?? "")
    }
    return .init(
        success: bool(json["success"]), sessionId: string(json["sessionId"]), task: string(json["task"]), reference: string(json["reference"]),
        acceptedDocumentCountry: string(json["acceptedDocumentCountry"]), acceptedDocumentType: string(json["acceptedDocumentType"]),
        selectedDocumentCountry: string(json["selectedDocumentCountry"]), selectedDocumentType: string(json["selectedDocumentType"]),
        allowFileUpload: bool(json["allowFileUpload"]), documentSide: int(json["documentSide"]), gps: bool(json["gps"]), reviewData: bool(json["reviewData"]),
        logoURL: string(json["logoURL"]), companyName: string(json["companyName"]), welcomeMessage: string(json["welcomeMessage"]), language: string(json["language"]), userPhone: string(json["userPhone"]),
        hasFaceFile: bool(json["hasFaceFile"]), hasDocumentFile: bool(json["hasDocumentFile"]), verifyDocumentNo: string(json["verifyDocumentNo"]), verifyName: string(json["verifyName"]), verifyDob: string(json["verifyDob"]), verifyAge: string(json["verifyAge"]), verifyAddress: string(json["verifyAddress"]), verifyPostcode: string(json["verifyPostcode"]), preloadFaceLib: bool(json["preloadFaceLib"]), contractSource: string(json["contractSource"]), customFields: fields, phoneCountryCodes: countryCodes, rawJSON: raw
    )
}

private func clean(_ value: String?) -> String? {
    let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return clean?.isEmpty == false ? clean : nil
}
private func string(_ value: Any?) -> String? {
    if value is NSNull { return nil }
    let result = value as? String
    return result?.isEmpty == false ? result : nil
}
private func bool(_ value: Any?, default defaultValue: Bool = false) -> Bool {
    if let value = value as? Bool { return value }
    if let value = value as? NSNumber { return value.boolValue }
    if let value = value as? String { return ["true", "1"].contains(value.lowercased()) }
    return defaultValue
}
private func int(_ value: Any?) -> Int {
    if let value = value as? Int { return value }
    if let value = value as? NSNumber { return value.intValue }
    if let value = value as? String { return Int(value) ?? 0 }
    return 0
}

private final class UnsafeTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else { completionHandler(.performDefaultHandling, nil); return }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
