import Foundation

public enum DocupassErrorAction: String, Sendable {
    case showCompleted, showFailed, resyncSession, requestLocation, retry
    case retakeDocument, retakeFace, editInput, fixSignature, fatal, contactSupport
}

public struct DocupassNormalizedError: Error, Equatable, Sendable {
    public let code: String?
    public let subCode: String?
    public let title: String
    public let detail: String
    public let suggestion: String
    public let action: DocupassErrorAction
    public let warningCodes: [String]
    public let httpStatus: Int?
    public let rawMessage: String?
    public let rawBody: String?

    public init(
        code: String?, subCode: String?, title: String, detail: String, suggestion: String,
        action: DocupassErrorAction, warningCodes: [String] = [], httpStatus: Int? = nil,
        rawMessage: String? = nil, rawBody: String? = nil
    ) {
        self.code = code; self.subCode = subCode; self.title = title; self.detail = detail
        self.suggestion = suggestion; self.action = action; self.warningCodes = warningCodes
        self.httpStatus = httpStatus; self.rawMessage = rawMessage; self.rawBody = rawBody
    }

    public func displayMessage(includeCode: Bool = true) -> String {
        let codes = [code, subCode].compactMap { $0 }.filter { !$0.isEmpty }
        let codeLine = includeCode && !codes.isEmpty ? "\nCode: \(codes.joined(separator: " / "))" : ""
        let warningLine = warningCodes.isEmpty ? "" : "\nWarnings: \(warningCodes.joined(separator: ", "))"
        return "\(title)\n\(detail)\n\(suggestion)\(warningLine)\(codeLine)"
    }
}

private struct ErrorTemplate {
    let title: String
    let detail: String
    let suggestion: String
    let action: DocupassErrorAction
}

public enum DocupassErrorNormalizer {
    public static func normalize(_ error: DocupassApiError) -> DocupassNormalizedError { normalizeDocupassError(error) }
    public static func normalize(code: String?, message: String?, httpStatus: Int? = nil, rawBody: String? = nil) -> DocupassNormalizedError {
        normalizeDocupassError(code: code, message: message, httpStatus: httpStatus, rawBody: rawBody)
    }
}

public func normalizeDocupassError(_ error: DocupassApiError) -> DocupassNormalizedError {
    normalizeDocupassError(code: error.code, message: error.message, httpStatus: error.httpStatus, rawBody: error.rawBody)
}

public func normalizeDocupassError(code: String?, message: String?, httpStatus: Int? = nil, rawBody: String? = nil) -> DocupassNormalizedError {
    let normalizedCode = normalizedKey(code)
    let rawMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines)

    switch normalizedCode {
    case "DOCUPASS_COMPLETED":
        return make(code: normalizedCode, title: "Verification completed", detail: "The DocuPass verification has already been completed successfully.", suggestion: "Show the completed state and stop submitting more verification data.", action: .showCompleted, status: httpStatus, rawMessage: rawMessage, rawBody: rawBody)
    case "DOCUPASS_FAILED":
        return make(code: normalizedCode, title: "Verification failed", detail: "The DocuPass verification has already reached a failed result.", suggestion: "Show the failed state and stop submitting more verification data.", action: .showFailed, status: httpStatus, rawMessage: rawMessage, rawBody: rawBody)
    case "DOCUPASS_FATAL_ERROR":
        let subCode = normalizedKey(rawMessage)
        let template = subCode.flatMap { fatalTemplates[$0] } ?? ErrorTemplate(title: "Fatal DocuPass session error", detail: "The server rejected the reference, session, or required context.", suggestion: "Restart from a valid DocuPass link. If this repeats, ask the issuer to create a new link.", action: .fatal)
        return make(code: normalizedCode, subCode: subCode, template: template, status: httpStatus, rawMessage: rawMessage, rawBody: rawBody)
    case "DOCUPASS_GENERIC_ERROR":
        let subCode = normalizedKey(rawMessage)
        let template = subCode.flatMap { genericTemplates[$0] } ?? ErrorTemplate(title: "DocuPass input error", detail: "The server rejected the current input.", suggestion: "Review the entered data and try again.", action: .editInput)
        return make(code: normalizedCode, subCode: subCode, template: template, status: httpStatus, rawMessage: rawMessage, rawBody: rawBody)
    case "DOCUPASS_DOCUMENT_REJECTED":
        return rejected(code: normalizedCode, message: rawMessage, templates: documentTemplates, fallback: ErrorTemplate(title: "Document rejected", detail: "The document verification was rejected by the server.", suggestion: "Retake the document with all edges visible, focused, and free of glare.", action: .retakeDocument), status: httpStatus, rawBody: rawBody)
    case "DOCUPASS_FACE_REJECTED":
        return rejected(code: normalizedCode, message: rawMessage, templates: faceTemplates, fallback: ErrorTemplate(title: "Face verification failed", detail: "The face verification was rejected by the server.", suggestion: "Retake the selfie in good lighting and follow the liveness instructions.", action: .retakeFace), status: httpStatus, rawBody: rawBody)
    case "ERROR_INVALID_VALUE":
        let subCode = normalizedKey(rawMessage)
        let action: DocupassErrorAction = subCode == "DOCUMENT" ? .retakeDocument : subCode == "FACE" ? .retakeFace : .editInput
        return make(code: normalizedCode, subCode: subCode, title: "Invalid value", detail: "One or more submitted values are invalid.", suggestion: "Review the submitted value and try again.", action: action, status: httpStatus, rawMessage: rawMessage, rawBody: rawBody)
    case "ERROR_OPERATION_FAILED":
        let subCode = normalizedKey(rawMessage)
        let template = subCode.flatMap { operationTemplates[$0] } ?? ErrorTemplate(title: "Operation failed", detail: rawMessage?.isEmpty == false ? rawMessage! : "The server rejected the requested operation.", suggestion: "Review the request settings and try again.", action: .editInput)
        return make(code: normalizedCode, subCode: subCode, template: template, status: httpStatus, rawMessage: rawMessage, rawBody: rawBody)
    case "ERROR_INTERNAL_ERROR":
        return make(code: normalizedCode, title: "Technical error", detail: "The server hit an internal error while processing the request.", suggestion: "Retry once. If the same error repeats, contact support with the reference and request step.", action: .contactSupport, status: httpStatus, rawMessage: rawMessage, rawBody: rawBody)
    default:
        if let key = normalizedCode, let template = mainTemplates[key] ?? commonTemplates[key] ?? localTemplates[key] {
            return make(code: normalizedCode, template: template, status: httpStatus, rawMessage: rawMessage, rawBody: rawBody)
        }
        let detail = rawMessage?.isEmpty == false ? rawMessage! : "An unexpected DocuPass error occurred."
        return make(code: normalizedCode, title: "Unexpected DocuPass error", detail: detail, suggestion: "Show this message and keep the raw error for debugging.", action: .contactSupport, status: httpStatus, rawMessage: rawMessage, rawBody: rawBody)
    }
}

private func rejected(code: String?, message: String?, templates: [String: ErrorTemplate], fallback: ErrorTemplate, status: Int?, rawBody: String?) -> DocupassNormalizedError {
    let warnings = message?.split(separator: ",").compactMap { normalizedKey(String($0)) } ?? []
    let subCode = warnings.first
    let template = subCode.flatMap { templates[$0] } ?? fallback
    return make(code: code, subCode: subCode, template: template, warnings: warnings, status: status, rawMessage: message, rawBody: rawBody)
}

private func make(code: String?, subCode: String? = nil, template: ErrorTemplate, warnings: [String] = [], status: Int?, rawMessage: String?, rawBody: String?) -> DocupassNormalizedError {
    make(code: code, subCode: subCode, title: template.title, detail: template.detail, suggestion: template.suggestion, action: template.action, warnings: warnings, status: status, rawMessage: rawMessage, rawBody: rawBody)
}

private func make(code: String?, subCode: String? = nil, title: String, detail: String, suggestion: String, action: DocupassErrorAction, warnings: [String] = [], status: Int?, rawMessage: String?, rawBody: String?) -> DocupassNormalizedError {
    .init(code: code, subCode: subCode, title: title, detail: detail, suggestion: suggestion, action: action, warningCodes: warnings, httpStatus: status, rawMessage: rawMessage, rawBody: rawBody)
}

private func normalizedKey(_ value: String?) -> String? {
    let key = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    return key?.isEmpty == false ? key : nil
}

private let mainTemplates: [String: ErrorTemplate] = [
    "DOCUPASS_INVALID_ACTION": .init(title: "Session changed", detail: "This action no longer matches the server session.", suggestion: "Refresh the verification session and continue from the current step.", action: .resyncSession),
    "DOCUPASS_REDIRECT": .init(title: "Verification redirected", detail: "The verification flow has moved to another destination.", suggestion: "Stop this session and follow the redirect supplied by your backend.", action: .showCompleted),
    "DOCUPASS_ACCEPTED": .init(title: "Verification accepted", detail: "The verification was accepted.", suggestion: "Show the completed state.", action: .showCompleted),
    "DOCUPASS_UNDER_REVIEW": .init(title: "Verification under review", detail: "The submitted verification is waiting for review.", suggestion: "Show the pending state and check again later.", action: .showCompleted),
    "DOCUPASS_CUSTOM_URL_ERROR": .init(title: "Redirect unavailable", detail: "The configured completion URL is invalid.", suggestion: "Contact the link issuer to correct the DocuPass configuration.", action: .editInput)
]

private let fatalTemplates: [String: ErrorTemplate] = [
    "REFERENCE_NOT_FOUND": .init(title: "Link not found", detail: "This DocuPass reference does not exist or has expired.", suggestion: "Request a new verification link.", action: .fatal),
    "SESSION_NOT_FOUND": .init(title: "Session not found", detail: "The DocuPass session is no longer available.", suggestion: "Restart with the original link or request a new one.", action: .fatal),
    "LOCATION_HEADER_MISSING": .init(title: "Location required", detail: "This verification requires a geolocation header.", suggestion: "Obtain consent and restart with geolocation in the SDK configuration.", action: .requestLocation)
]

private let genericTemplates: [String: ErrorTemplate] = [
    "INVALID_PHONE_NUMBER": input("Invalid phone number", "Enter a complete phone number including the country code."),
    "PHONE NUMBER NOT IN ACCEPTED COUNTRY": input("Phone country not accepted", "Use a phone number from an accepted country."),
    "SMS_LIMIT_REACHED": retry("SMS limit reached", "Wait before requesting another SMS code."),
    "CALL_LIMIT_REACHED": retry("Call limit reached", "Wait before requesting another voice call."),
    "PHONE_VERIFICATION_LIMIT_REACHED": fatal("Phone verification limit reached", "Request a new verification link."),
    "NUMBER_NOT_SUPPORTED": input("Phone number not supported", "Use a mobile number that can receive SMS or calls."),
    "INVALID_PHONE_VERIFICATION_CODE": input("Incorrect verification code", "Check the six-digit code and try again."),
    "PHONE_VERIFICATION_EXPIRED": retry("Verification code expired", "Request a new code."),
    "CUSTOM_FIELD_EMPTY": input("Required answer missing", "Complete every required field."),
    "INVALID_SIGNATURE_IMAGE": signature("Invalid signature", "Clear and draw the signature again."),
    "SIGNATURE_MISSING": signature("Signature required", "Sign the contract before submitting.")
]

private let documentTemplates: [String: ErrorTemplate] = {
    var map: [String: ErrorTemplate] = [:]
    let retake = ["UNRECOGNIZED_DOCUMENT", "UNRECOGNIZED_BACK_DOCUMENT", "UNRECOGNIZED_BACK_BARCODE", "INVALID_BACK_DOCUMENT", "DOCUPASS_BACK_DOCUMENT_NOT_UPLOADED", "DOCUPASS_BACK_DOCUMENT_MISMATCH", "DOCUPASS_DOCUMENT_MISSING_FACE", "DOCUMENT_FACE_NOT_FOUND", "DOCUMENT_FACE_LANDMARK_ERR", "LOW_TEXT_CONFIDENCE", "MISSING_EXPIRY_DATE", "MISSING_ISSUE_DATE", "MISSING_BIRTH_DATE", "MISSING_DOCUMENT_NUMBER", "MISSING_PERSONAL_NUMBER", "MISSING_ADDRESS", "MISSING_POSTCODE", "MISSING_NAME", "MISSING_LOCAL_NAME", "MISSING_GENDER", "MISSING_HEIGHT", "MISSING_WEIGHT", "MISSING_HAIR_COLOR", "MISSING_EYE_COLOR", "MISSING_RESTRICTIONS", "IMAGE_TOO_SMALL", "IMAGE_TOO_BLURRY", "GLARE_DETECTED", "BLACK_WHITE_DOCUMENT", "RECAPTURED_DOCUMENT", "SCREEN_DETECTED"]
    retake.forEach { map[$0] = .init(title: "Document image not accepted", detail: "The document image could not be verified (\($0)).", suggestion: "Retake it with all edges visible, sharp focus, even lighting, and no screen or photocopy.", action: .retakeDocument) }
    ["DOCUPASS_DOCUMENT_TYPE_MISMATCH", "DOCUPASS_DOCUMENT_COUNTRY_MISMATCH"].forEach { map[$0] = .init(title: "Document mismatch", detail: "The selected document details do not match the captured document.", suggestion: "Reselect the country or type, or capture the matching document.", action: .retakeDocument) }
    ["TYPE_NOT_ACCEPTED", "COUNTRY_NOT_ACCEPTED", "STATE_NOT_ACCEPTED"].forEach { map[$0] = input("Document not accepted", "Choose an accepted country and document type, then capture that document.") }
    ["UNDER_18", "UNDER_19", "UNDER_20", "UNDER_21"].forEach { map[$0] = .init(title: "Age requirement not met", detail: "The document holder does not meet the required minimum age (\($0)).", suggestion: "Stop the verification and show the failed result.", action: .showFailed) }
    ["NAME_VERIFICATION_FAILED", "DOB_VERIFICATION_FAILED", "AGE_VERIFICATION_FAILED", "ID_NUMBER_VERIFICATION_FAILED", "ADDRESS_VERIFICATION_FAILED", "POSTCODE_VERIFICATION_FAILED"].forEach { map[$0] = .init(title: "Document details do not match", detail: "A required document field did not match the expected value (\($0)).", suggestion: "Retake the correct document or review the expected data.", action: .retakeDocument) }
    ["IMAGE_FORGERY", "IMAGE_EDITED", "TEXT_FORGERY", "FEATURE_VERIFICATION_FAILED", "FAKE_ID", "ARTIFICIAL_IMAGE", "ARTIFICIAL_TEXT", "DOCUPASS_TOO_MANY_ATTEMPTS", "DOCUPASS_EXPIRED"].forEach { map[$0] = .init(title: "Document rejected", detail: "The document failed a security or validity check (\($0)).", suggestion: "Use the original, valid document or request a new link.", action: .showFailed) }
    map["DOCUMENT_EXPIRED"] = input("Document expired", "Use a valid, non-expired document.")
    map["DOCUPASS_NOT_FROM_CAMERA"] = .init(title: "Camera capture required", detail: "This verification does not accept uploaded files.", suggestion: "Capture the original document with the camera.", action: .retakeDocument)
    return map
}()

private let faceTemplates: [String: ErrorTemplate] = {
    var map: [String: ErrorTemplate] = [:]
    ["SELFIE_FACE_NOT_FOUND", "SELFIE_MULTIPLE_FACES", "SELFIE_FACE_LANDMARK_ERR", "FACE_MISMATCH", "FACE_IDENTICAL", "FACE_LIVENESS_ERR", "RECAPTURED_FACE"].forEach { map[$0] = .init(title: "Face verification failed", detail: "The selfie could not be verified (\($0)).", suggestion: "Use good lighting, keep only one face visible, and repeat the liveness actions.", action: .retakeFace) }
    map["DOCUPASS_TOO_MANY_ATTEMPTS"] = .init(title: "Too many face attempts", detail: "The session exceeded its face verification attempts.", suggestion: "Stop this session and request a new verification link if appropriate.", action: .showFailed)
    return map
}()

private let commonTemplates: [String: ErrorTemplate] = [
    "ERROR_INVALID_LICENSE": contact("Service license invalid", "Contact the service administrator."),
    "SERVICE_UNAVAILABLE": retry("Service unavailable", "Wait a moment and try again."),
    "ERROR_MAX_EXECUTION_TIME_EXCEEDED": retry("Request timed out", "Try again."),
    "ERROR_REQUEST_TOO_LARGE": .init(title: "Upload too large", detail: "The request exceeded the upload size limit.", suggestion: "Retake or compress the document image.", action: .retakeDocument),
    "ERROR_INVALID_JSON": contact("Invalid server request", "Contact support if this continues."),
    "ERROR_UNAUTHORIZED": fatal("Unauthorized session", "Restart from a valid DocuPass link."),
    "ERROR_USER_BANNED": fatal("Access blocked", "Contact the link issuer."),
    "ERROR_QUOTA_EXCEEDED": fatal("Service quota exceeded", "Contact the link issuer."),
    "ERROR_EXECUTION_CANCEL": retry("Request cancelled", "Try again."),
    "ERROR_INVALID_ENCODING": .init(title: "Invalid image encoding", detail: "The image could not be decoded from base64.", suggestion: "Capture the document image again.", action: .retakeDocument),
    "ERROR_REMOTE_IMAGE_FAILED": retry("Image upload failed", "Capture and upload the image again."),
    "ERROR_IMAGE_CORRUPTED": .init(title: "Image corrupted", detail: "The image is unsupported or corrupted.", suggestion: "Capture the document image again.", action: .retakeDocument)
]

private let localTemplates: [String: ErrorTemplate] = [
    "LOCAL_VALIDATION": input("Missing information", "Complete the required information and try again."),
    "NETWORK_ERROR": retry("Network error", "Check the connection and try again."),
    "UNEXPECTED_ERROR": contact("Unexpected error", "Try again. If this continues, contact support.")
]

private let operationTemplates: [String: ErrorTemplate] = [:]

private func input(_ title: String, _ suggestion: String) -> ErrorTemplate { .init(title: title, detail: title + ".", suggestion: suggestion, action: .editInput) }
private func retry(_ title: String, _ suggestion: String) -> ErrorTemplate { .init(title: title, detail: title + ".", suggestion: suggestion, action: .retry) }
private func fatal(_ title: String, _ suggestion: String) -> ErrorTemplate { .init(title: title, detail: title + ".", suggestion: suggestion, action: .fatal) }
private func signature(_ title: String, _ suggestion: String) -> ErrorTemplate { .init(title: title, detail: title + ".", suggestion: suggestion, action: .fixSignature) }
private func contact(_ title: String, _ suggestion: String) -> ErrorTemplate { .init(title: title, detail: title + ".", suggestion: suggestion, action: .contactSupport) }
