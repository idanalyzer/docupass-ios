import SwiftUI

/// Every user-facing label in the drop-in UI, with English defaults. Override any
/// subset to re-word or localize the flow to any language:
///
/// ```swift
/// var strings = DocuPassStrings()
/// strings.phoneTitle = "Vérifiez votre téléphone"
/// strings.phoneSendSms = "Envoyer le SMS"
/// DocuPassView(config: cfg, strings: strings) { result in … }
/// ```
///
/// For full control of layout/look, use the headless API (`DocuPassController`).
public struct DocuPassStrings {
    // Common
    public var start = "Start"
    public var continueButton = "Continue"
    public var pleaseWaitTitle = "Please wait"
    public var pleaseWaitBody = "Preparing the next step…"
    public var waitingTitle = "Waiting"
    public var waitingBody = "Waiting for another party to complete their part."
    public var cameraPermissionRequired = "Camera permission is required"

    // Welcome
    public var welcomeFallback = "You'll be guided through a quick identity verification."

    // Document selection
    public var selectDocumentTitle = "Select your document"
    public var countryLabel = "Country"
    public var documentTypeLabel = "Document type"
    public var pleaseMakeSure = "Please make sure"
    public var reqClear = "The whole document is in frame, in focus, and free of glare."
    public var reqDocumentNo = "The document number is clearly visible."
    public var reqName = "Your full name is readable."
    public var reqDob = "Your date of birth is readable."
    public var reqAddress = "Your address is readable."
    public var reqPostcode = "Your postcode is readable."

    // Document capture
    public var capturePassport = "Capture the passport data page"
    public var captureFront = "Capture the front of your document"
    public var captureBack = "Capture the back of your document"
    public var capture = "Capture"
    public var captureBackButton = "Capture back"

    // Face / liveness
    public var faceLoading = "Loading face check…"
    public var faceForward = "Face forward and hold still"
    public var faceGreat = "Great — keep going"
    public var faceTurnLeft = "Slowly turn your head to the left"
    public var faceTurnRight = "Slowly turn your head to the right"
    public var faceDone = "All done"
    public var faceNoFace = "No face detected — center your face"

    // Custom form
    public var customFormTitle = "A few more details"

    // Phone
    public var phoneTitle = "Verify your phone"
    /// Shown as `"<phonePresetPrefix><number>"` when the number is preset.
    public var phonePresetPrefix = "We'll send a code to "
    public var phoneCodeLabel = "Code"
    public var phoneNumberLabel = "Phone number"
    public var phoneSendSms = "Send SMS"
    public var phoneCall = "Call me"
    public var phoneCodeEntryLabel = "6-digit code"
    public var phoneVerify = "Verify"

    // Contract / e-signature
    public var contractTitle = "Review & sign"
    public var contractSignature = "Signature"
    public var contractClear = "Clear"
    public var contractAccept = "Accept & Submit"
    public var contractSubmit = "Submit signatures"

    public init() {}

    /// Copy with overrides keyed by property name (used by the RN / Flutter bridges).
    public func applying(_ o: [String: String]) -> DocuPassStrings {
        var s = self
        if let v = o["start"] { s.start = v }
        if let v = o["continueButton"] { s.continueButton = v }
        if let v = o["pleaseWaitTitle"] { s.pleaseWaitTitle = v }
        if let v = o["pleaseWaitBody"] { s.pleaseWaitBody = v }
        if let v = o["waitingTitle"] { s.waitingTitle = v }
        if let v = o["waitingBody"] { s.waitingBody = v }
        if let v = o["cameraPermissionRequired"] { s.cameraPermissionRequired = v }
        if let v = o["welcomeFallback"] { s.welcomeFallback = v }
        if let v = o["selectDocumentTitle"] { s.selectDocumentTitle = v }
        if let v = o["countryLabel"] { s.countryLabel = v }
        if let v = o["documentTypeLabel"] { s.documentTypeLabel = v }
        if let v = o["pleaseMakeSure"] { s.pleaseMakeSure = v }
        if let v = o["reqClear"] { s.reqClear = v }
        if let v = o["reqDocumentNo"] { s.reqDocumentNo = v }
        if let v = o["reqName"] { s.reqName = v }
        if let v = o["reqDob"] { s.reqDob = v }
        if let v = o["reqAddress"] { s.reqAddress = v }
        if let v = o["reqPostcode"] { s.reqPostcode = v }
        if let v = o["capturePassport"] { s.capturePassport = v }
        if let v = o["captureFront"] { s.captureFront = v }
        if let v = o["captureBack"] { s.captureBack = v }
        if let v = o["capture"] { s.capture = v }
        if let v = o["captureBackButton"] { s.captureBackButton = v }
        if let v = o["faceLoading"] { s.faceLoading = v }
        if let v = o["faceForward"] { s.faceForward = v }
        if let v = o["faceGreat"] { s.faceGreat = v }
        if let v = o["faceTurnLeft"] { s.faceTurnLeft = v }
        if let v = o["faceTurnRight"] { s.faceTurnRight = v }
        if let v = o["faceDone"] { s.faceDone = v }
        if let v = o["faceNoFace"] { s.faceNoFace = v }
        if let v = o["customFormTitle"] { s.customFormTitle = v }
        if let v = o["phoneTitle"] { s.phoneTitle = v }
        if let v = o["phonePresetPrefix"] { s.phonePresetPrefix = v }
        if let v = o["phoneCodeLabel"] { s.phoneCodeLabel = v }
        if let v = o["phoneNumberLabel"] { s.phoneNumberLabel = v }
        if let v = o["phoneSendSms"] { s.phoneSendSms = v }
        if let v = o["phoneCall"] { s.phoneCall = v }
        if let v = o["phoneCodeEntryLabel"] { s.phoneCodeEntryLabel = v }
        if let v = o["phoneVerify"] { s.phoneVerify = v }
        if let v = o["contractTitle"] { s.contractTitle = v }
        if let v = o["contractSignature"] { s.contractSignature = v }
        if let v = o["contractClear"] { s.contractClear = v }
        if let v = o["contractAccept"] { s.contractAccept = v }
        if let v = o["contractSubmit"] { s.contractSubmit = v }
        return s
    }
}

extension Color {
    /// Parse a #RGB / #RRGGBB / #AARRGGBB hex string (used by the bridges).
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        guard let int = UInt64(h, radix: 16) else { return nil }
        let r, g, b, a: Double
        switch h.count {
        case 3:
            r = Double((int >> 8) & 0xF) / 15; g = Double((int >> 4) & 0xF) / 15; b = Double(int & 0xF) / 15; a = 1
        case 6:
            r = Double((int >> 16) & 0xFF) / 255; g = Double((int >> 8) & 0xFF) / 255; b = Double(int & 0xFF) / 255; a = 1
        case 8:
            a = Double((int >> 24) & 0xFF) / 255; r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255; b = Double(int & 0xFF) / 255
        default:
            return nil
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Branding for the drop-in UI.
/// - `primaryColor`: brand tint for buttons/controls (nil = system accent).
/// - `logoURL`: a logo for the welcome screen (nil = server-configured `logoURL`).
/// - `showLogo`: set false to never show a logo.
public struct DocuPassTheme {
    public var primaryColor: Color?
    public var logoURL: String?
    public var showLogo: Bool

    public init(primaryColor: Color? = nil, logoURL: String? = nil, showLogo: Bool = true) {
        self.primaryColor = primaryColor
        self.logoURL = logoURL
        self.showLogo = showLogo
    }
}

private struct DocuPassStringsKey: EnvironmentKey { static let defaultValue = DocuPassStrings() }
private struct DocuPassThemeKey: EnvironmentKey { static let defaultValue = DocuPassTheme() }

extension EnvironmentValues {
    var docuPassStrings: DocuPassStrings {
        get { self[DocuPassStringsKey.self] }
        set { self[DocuPassStringsKey.self] = newValue }
    }
    var docuPassTheme: DocuPassTheme {
        get { self[DocuPassThemeKey.self] }
        set { self[DocuPassThemeKey.self] = newValue }
    }
}
