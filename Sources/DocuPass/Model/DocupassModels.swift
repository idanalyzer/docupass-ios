import Foundation

public let DOCUPASS_API_ENDPOINT_US = "https://api2.idanalyzer.com/docupassappv3"
public let DOCUPASS_API_ENDPOINT_EU = "https://api2-eu.idanalyzer.com/docupassappv3"

public struct DocupassApiConfig: Sendable {
    public var enabled: Bool
    public var baseURL: String?
    public var reference: String?
    public var partyId: String?
    public var sessionId: String?
    public var authorization: String?
    public var geolocation: String?
    public var disableSSLValidation: Bool
    public var timeout: TimeInterval

    public init(
        enabled: Bool = true,
        baseURL: String? = nil,
        reference: String? = nil,
        partyId: String? = nil,
        sessionId: String? = nil,
        authorization: String? = nil,
        geolocation: String? = nil,
        disableSSLValidation: Bool = false,
        timeout: TimeInterval = 20
    ) {
        self.enabled = enabled
        self.baseURL = baseURL
        self.reference = reference
        self.partyId = partyId
        self.sessionId = sessionId
        self.authorization = authorization
        self.geolocation = geolocation
        self.disableSSLValidation = disableSSLValidation
        self.timeout = timeout
    }

    public static func fromReference(
        _ reference: String,
        partyId: String? = nil,
        geolocation: String? = nil,
        enabled: Bool = true
    ) -> Self {
        .init(
            enabled: enabled,
            baseURL: resolveDocupassEndpoint(reference),
            reference: reference,
            partyId: partyId,
            geolocation: geolocation
        )
    }
}

public func resolveDocupassEndpoint(_ reference: String?) -> String {
    reference?.trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased().hasPrefix("eu") == true
        ? DOCUPASS_API_ENDPOINT_EU
        : DOCUPASS_API_ENDPOINT_US
}

public func docupassConfigFromReference(
    _ reference: String,
    partyId: String? = nil,
    geolocation: String? = nil,
    enabled: Bool = true
) -> DocupassApiConfig {
    .fromReference(reference, partyId: partyId, geolocation: geolocation, enabled: enabled)
}

public struct DocupassCustomField: Equatable, Sendable {
    public let fieldId: String
    public let fieldLabel: String
    public let fieldDescription: String
    public let fieldType: Int
    public let fieldData: String

    public init(fieldId: String, fieldLabel: String, fieldDescription: String, fieldType: Int, fieldData: String) {
        self.fieldId = fieldId
        self.fieldLabel = fieldLabel
        self.fieldDescription = fieldDescription
        self.fieldType = fieldType
        self.fieldData = fieldData
    }
}

public struct DocupassPhoneCountryCode: Equatable, Sendable {
    public let name: String
    public let dialCode: String
    public let code: String

    public init(name: String, dialCode: String, code: String) {
        self.name = name; self.dialCode = dialCode; self.code = code
    }
}

public struct DocupassSessionState: Equatable, Sendable {
    public let success: Bool
    public let sessionId: String?
    public let task: String?
    public let reference: String?
    public let acceptedDocumentCountry: String?
    public let acceptedDocumentType: String?
    public let selectedDocumentCountry: String?
    public let selectedDocumentType: String?
    public let allowFileUpload: Bool
    public let documentSide: Int
    public let gps: Bool
    public let reviewData: Bool
    public let logoURL: String?
    public let companyName: String?
    public let welcomeMessage: String?
    public let language: String?
    public let userPhone: String?
    public let hasFaceFile: Bool
    public let hasDocumentFile: Bool
    public let verifyDocumentNo: String?
    public let verifyName: String?
    public let verifyDob: String?
    public let verifyAge: String?
    public let verifyAddress: String?
    public let verifyPostcode: String?
    public let preloadFaceLib: Bool
    public let contractSource: String?
    public let customFields: [DocupassCustomField]
    public let phoneCountryCodes: [DocupassPhoneCountryCode]
    public let rawJSON: String

    public init(
        success: Bool = false, sessionId: String? = nil, task: String? = nil,
        reference: String? = nil, acceptedDocumentCountry: String? = nil,
        acceptedDocumentType: String? = nil, selectedDocumentCountry: String? = nil,
        selectedDocumentType: String? = nil, allowFileUpload: Bool = false,
        documentSide: Int = 0, gps: Bool = false, reviewData: Bool = false,
        logoURL: String? = nil, companyName: String? = nil, welcomeMessage: String? = nil,
        language: String? = nil, userPhone: String? = nil, hasFaceFile: Bool = false,
        hasDocumentFile: Bool = false, verifyDocumentNo: String? = nil,
        verifyName: String? = nil, verifyDob: String? = nil, verifyAge: String? = nil,
        verifyAddress: String? = nil, verifyPostcode: String? = nil,
        preloadFaceLib: Bool = false, contractSource: String? = nil,
        customFields: [DocupassCustomField] = [],
        phoneCountryCodes: [DocupassPhoneCountryCode] = [], rawJSON: String = "{}"
    ) {
        self.success = success; self.sessionId = sessionId; self.task = task; self.reference = reference
        self.acceptedDocumentCountry = acceptedDocumentCountry; self.acceptedDocumentType = acceptedDocumentType
        self.selectedDocumentCountry = selectedDocumentCountry; self.selectedDocumentType = selectedDocumentType
        self.allowFileUpload = allowFileUpload; self.documentSide = documentSide; self.gps = gps
        self.reviewData = reviewData; self.logoURL = logoURL; self.companyName = companyName
        self.welcomeMessage = welcomeMessage; self.language = language; self.userPhone = userPhone
        self.hasFaceFile = hasFaceFile; self.hasDocumentFile = hasDocumentFile
        self.verifyDocumentNo = verifyDocumentNo; self.verifyName = verifyName; self.verifyDob = verifyDob
        self.verifyAge = verifyAge; self.verifyAddress = verifyAddress; self.verifyPostcode = verifyPostcode
        self.preloadFaceLib = preloadFaceLib; self.contractSource = contractSource
        self.customFields = customFields; self.phoneCountryCodes = phoneCountryCodes; self.rawJSON = rawJSON
    }

    public var acceptedDocumentCountryCodes: [String] { acceptedDocumentCountry.commaSeparatedValues }
    public var acceptedDocumentTypeCodes: [String] { acceptedDocumentType.commaSeparatedValues }
}

public enum DocupassApiResult<Value: Sendable>: Sendable {
    case success(Value)
    case failure(DocupassApiError)
}

public struct DocupassApiError: Error, Equatable, Sendable {
    public let message: String
    public let code: String?
    public let httpStatus: Int?
    public let rawBody: String?

    public init(message: String, code: String? = nil, httpStatus: Int? = nil, rawBody: String? = nil) {
        self.message = message; self.code = code; self.httpStatus = httpStatus; self.rawBody = rawBody
    }
}

public enum KYCDocumentType: String, CaseIterable, Identifiable, Sendable {
    case passport = "P"
    case driverLicense = "D"
    case identityCard = "I"

    public var id: String { rawValue }
    public var apiTypeCode: String { rawValue }
    public var label: String {
        switch self { case .passport: "Passport"; case .driverLicense: "Driver License"; case .identityCard: "Identity Card" }
    }
    public var requiresBackSide: Bool { self != .passport }
}

public struct KYCCountry: Equatable, Identifiable, Sendable {
    public let code: String
    public let name: String
    public let flag: String
    public var id: String { code }

    public init(code: String, name: String, flag: String = "") {
        self.code = code; self.name = name; self.flag = flag
    }
}

public enum KYCAction: String, CaseIterable, Identifiable, Sendable {
    case turnLeft, turnRight, turnUp, mouthOpen
    public var id: String { rawValue }
    public var instruction: String {
        switch self {
        case .turnLeft: "TURN HEAD LEFT"
        case .turnRight: "TURN HEAD RIGHT"
        case .turnUp: "TURN HEAD UP"
        case .mouthOpen: "OPEN MOUTH O-SHAPE"
        }
    }
}

public struct DocupassContractSignatureField: Equatable, Identifiable, Sendable {
    public let uid: String
    public let label: String
    public let party: String?
    public var id: String { uid }

    public init(uid: String, label: String, party: String? = nil) {
        self.uid = uid; self.label = label; self.party = party
    }
}

public struct KYCResult: Equatable, Sendable {
    public var country: KYCCountry?
    public var documentType: KYCDocumentType?
    public var documentFrontBase64: String?
    public var documentBackBase64: String?
    public var faceBase64List: [String]
    public var isFaceVerified: Bool
    public var serverTask: String?
    public var sessionId: String?
    public var sessionState: DocupassSessionState?
    public var terminalError: DocupassNormalizedError?

    public init(
        country: KYCCountry? = nil, documentType: KYCDocumentType? = nil,
        documentFrontBase64: String? = nil, documentBackBase64: String? = nil,
        faceBase64List: [String] = [], isFaceVerified: Bool = false,
        serverTask: String? = nil, sessionId: String? = nil,
        sessionState: DocupassSessionState? = nil, terminalError: DocupassNormalizedError? = nil
    ) {
        self.country = country; self.documentType = documentType
        self.documentFrontBase64 = documentFrontBase64; self.documentBackBase64 = documentBackBase64
        self.faceBase64List = faceBase64List; self.isFaceVerified = isFaceVerified
        self.serverTask = serverTask; self.sessionId = sessionId
        self.sessionState = sessionState; self.terminalError = terminalError
    }
}

public enum KYCStep: Equatable, Sendable {
    case phoneVerification(DocupassSessionState)
    case customForm([DocupassCustomField])
    case selectCountry(filterCodes: [String]? = nil)
    case selectDocument
    case captureDocument
    case faceVerification([KYCAction])
    case contract(DocupassSessionState)
    case partyPending
    case success
    case failed(DocupassNormalizedError? = nil)
}

public enum DocupassWorkflow {
    public static func defaultWorkflow() -> [KYCStep] {
        [.selectCountry(), .selectDocument, .captureDocument, .faceVerification(KYCAction.allCases)]
    }
}

public let ALL_COUNTRIES: [KYCCountry] = [
    .init(code: "TW", name: "Taiwan"), .init(code: "US", name: "United States"),
    .init(code: "JP", name: "Japan"), .init(code: "KR", name: "South Korea"),
    .init(code: "HK", name: "Hong Kong"), .init(code: "SG", name: "Singapore"),
    .init(code: "GB", name: "United Kingdom"), .init(code: "AU", name: "Australia"),
    .init(code: "CA", name: "Canada"), .init(code: "DE", name: "Germany"),
    .init(code: "FR", name: "France"), .init(code: "TH", name: "Thailand")
].sorted { $0.name < $1.name }

extension Optional where Wrapped == String {
    var commaSeparatedValues: [String] {
        self?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
    }
}
