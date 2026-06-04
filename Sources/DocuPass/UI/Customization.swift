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
