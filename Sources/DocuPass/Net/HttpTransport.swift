import Foundation

/// Thin HTTP layer for the docupassappv3 protocol: applies the evolving DocuPass
/// `Authorization` header (and optional `Geolocation`), and parses the
/// `{success,error{code,message}}` envelope. Auth-state aware: switches to
/// `DOCUPASS_SESSION <id>` once a sessionId is seen.
final class HttpTransport {
    private let baseURL: String
    private let reference: String
    private let partyId: String?
    private let session: URLSession

    /// Set after the first get_action; switches auth to the session form.
    var sessionId: String?
    /// "lat,lng,accuracy" — sent as the Geolocation header when present.
    var geolocation: String?

    init(baseURL: String, reference: String, partyId: String?, timeout: TimeInterval) {
        self.baseURL = baseURL
        self.reference = reference
        self.partyId = partyId
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = timeout
        cfg.waitsForConnectivity = true
        self.session = URLSession(configuration: cfg)
    }

    private func authHeader() -> String {
        if let sid = sessionId, !sid.isEmpty { return "DOCUPASS_SESSION \(sid)" }
        if let pid = partyId, !pid.isEmpty { return "DOCUPASS \(reference) \(pid)" }
        return "DOCUPASS \(reference)"
    }

    private func request(path: String, method: String, body: Data?) -> URLRequest {
        let url = URL(string: "\(baseURL)/\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        if let geo = geolocation, !geo.isEmpty { req.setValue(geo, forHTTPHeaderField: "Geolocation") }
        if let body {
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        return req
    }

    func get(_ path: String) async throws -> Data {
        try await execute(request(path: path, method: "GET", body: nil))
    }

    func post(_ path: String, json: [String: Any]) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: json)
        return try await execute(request(path: path, method: "POST", body: body))
    }

    /// Fire-and-forget POST (audit); never throws.
    func postQuietly(_ path: String, json: [String: Any]) async {
        guard let body = try? JSONSerialization.data(withJSONObject: json) else { return }
        _ = try? await session.data(for: request(path: path, method: "POST", body: body))
    }

    /// Runs a request and validates the DocuPass envelope, throwing `DocuPassError`.
    private func execute(_ req: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw DocuPassError(code: "NETWORK_ERROR", message: error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let obj else {
            throw DocuPassError(code: "PARSE_ERROR", message: "Non-JSON response",
                                httpStatus: status, rawBody: String(data: data, encoding: .utf8))
        }
        let success = (obj["success"] as? Bool) ?? false
        let errorObj = obj["error"] as? [String: Any]
        if !success || errorObj != nil || !(200...299).contains(status) {
            let code = errorObj?["code"] as? String
            let message = (errorObj?["message"] as? String) ?? (obj["message"] as? String)
            throw DocuPassError(code: code, message: message, httpStatus: status,
                                rawBody: String(data: data, encoding: .utf8))
        }
        return data
    }
}
