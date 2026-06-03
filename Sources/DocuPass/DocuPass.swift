import Foundation

/// Library version.
public let DocuPassSDKVersion = "0.1.0"

/// Outcome of a DocuPass verification. The verification *data* lives server-side —
/// fetch it with the ID Analyzer v2 server SDK `GET /docupass/{reference}`.
public enum DocuPassResult {
    /// Finished successfully (accepted / under-review).
    case completed(reference: String, redirectURL: String?, code: String?)
    /// Finished with a rejection/failure.
    case failed(reference: String, code: String?, message: String?, redirectURL: String?)
    /// User dismissed/aborted before completion.
    case cancelled(reference: String)
    /// Unrecoverable error (network / fatal session error).
    case error(reference: String, error: DocuPassError)

    public var reference: String {
        switch self {
        case let .completed(r, _, _), let .failed(r, _, _, _), let .cancelled(r), let .error(r, _): return r
        }
    }
}
