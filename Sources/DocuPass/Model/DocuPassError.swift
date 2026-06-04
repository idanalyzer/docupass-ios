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

    // Terminal success end-states. successMessage shows a success notice; the
    // server delivers reviewContract (with the review HTML) once a party has
    // signed — for the drop-in flow that's a stable "signed / under review"
    // end-state (full inline review parity is tracked separately).
    static let successTerminal: Set<String> = [completed, accepted, underReview, redirect, successMessage, reviewContract]
    // Terminal failure end-states. errorMessage is a hard stop (e.g. session
    // expired) — it must NOT be retried/resynced or the flow loops forever.
    static let failureTerminal: Set<String> = [failed, errorMessage]
    static let terminal: Set<String> = successTerminal.union(failureTerminal)
    // Display-only: show the message but stay on the current step (errorPopup =
    // recoverable phone-step alerts where the user simply retries).
    static let display: Set<String> = [errorPopup]
    static let fatal: Set<String> = [fatalError]

    public static func isTerminal(_ code: String?) -> Bool { code.map { terminal.contains($0) } ?? false }
    public static func isFatal(_ code: String?) -> Bool { code.map { fatal.contains($0) } ?? false }
    /// Show the message but keep the user on the current step (do not resync/end).
    public static func isDisplay(_ code: String?) -> Bool { code.map { display.contains($0) } ?? false }
    /// A successful end-state (vs. an outright failure/rejection).
    public static func isSuccessTerminal(_ code: String?) -> Bool { code.map { successTerminal.contains($0) } ?? false }
    /// Codes whose `message` is a redirect URL (vs. human-readable display text).
    public static func carriesRedirectURL(_ code: String?) -> Bool {
        code.map { [completed, accepted, underReview, redirect, failed].contains($0) } ?? false
    }
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
    public var isDisplay: Bool { DocuPassErrorCode.isDisplay(code) }
}
