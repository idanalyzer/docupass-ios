import Foundation

/// Authoritative DocuPass error / terminal codes (from the DocuPass API).
/// Delivered in `error.code` with `success:false` and HTTP 200 — branch on these,
/// not on HTTP status.
public enum DocuPassErrorCode {
    public static let completed = "DOCUPASS_COMPLETED"
    public static let failed = "DOCUPASS_FAILED"
    public static let accepted = "DOCUPASS_ACCEPTED"
    public static let underReview = "DOCUPASS_UNDER_REVIEW"
    public static let redirect = "DOCUPASS_REDIRECT"
    public static let reviewContract = "DOCUPASS_REVIEW_CONTRACT"
    public static let successMessage = "DOCUPASS_SUCCESS_MESSAGE"
    public static let errorMessage = "DOCUPASS_ERROR_MESSAGE"
    public static let errorPopup = "DOCUPASS_ERROR_POPUP"

    public static let documentRejected = "DOCUPASS_DOCUMENT_REJECTED"
    public static let faceRejected = "DOCUPASS_FACE_REJECTED"
    public static let genericError = "DOCUPASS_GENERIC_ERROR"
    public static let invalidAction = "DOCUPASS_INVALID_ACTION"
    public static let fatalError = "DOCUPASS_FATAL_ERROR"

    static let terminal: Set<String> = [completed, failed, accepted, underReview, redirect]
    static let fatal: Set<String> = [fatalError]

    public static func isTerminal(_ code: String?) -> Bool { code.map { terminal.contains($0) } ?? false }
    public static func isFatal(_ code: String?) -> Bool { code.map { fatal.contains($0) } ?? false }
}

/// A structured DocuPass error. `message` carries human text or, for completion/
/// redirect codes, the redirect URL.
public struct DocuPassError: Error {
    public let code: String?
    public let message: String?
    public let httpStatus: Int?
    public let rawBody: String?

    public init(code: String?, message: String?, httpStatus: Int? = nil, rawBody: String? = nil) {
        self.code = code
        self.message = message
        self.httpStatus = httpStatus
        self.rawBody = rawBody
    }

    public var isTerminal: Bool { DocuPassErrorCode.isTerminal(code) }
    public var isFatal: Bool { DocuPassErrorCode.isFatal(code) }
}
