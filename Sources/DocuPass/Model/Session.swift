import Foundation

/// The flat `get_action` response.
/// Also returned by every successful POST step. Unknown keys are ignored.
public struct DocuPassSession: Decodable {
    public let success: Bool
    public let task: String?
    public let sessionId: String?
    public let reference: String?

    // Branding / behaviour
    public let companyName: String
    public let welcomeMessage: String
    public let logoURL: String
    public let language: String
    public let gps: Bool
    public let allowFileUpload: Bool
    public let reviewData: Bool
    public let preloadFaceLib: Bool

    // Document
    public let documentSide: Int
    public let acceptedDocumentCountry: String
    public let acceptedDocumentType: String
    public let selectedDocumentCountry: String
    public let selectedDocumentType: String
    public let hasDocumentFile: Bool
    public let hasFaceFile: Bool
    public let verifyDocumentNo: String
    public let verifyName: String
    public let verifyDob: String
    public let verifyAge: String
    public let verifyAddress: String
    public let verifyPostCode: String

    // Phone
    public let userPhone: String
    public let phoneCountryCode: [PhoneCode]

    // Custom form
    public let customField: [CustomField]

    // Contract
    public let contractSource: String

    public var parsedTask: DocuPassTask { DocuPassTask.from(task) }
    public var parsedDocumentSide: DocumentSide { DocumentSide.from(documentSide) }

    /// Front-only when the session says so or the selected doc is a passport ("P").
    public var isFrontOnly: Bool {
        parsedDocumentSide == .frontOnly || selectedDocumentType.uppercased() == "P"
    }

    public var acceptedCountries: [String] {
        acceptedDocumentCountry.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public var acceptedTypes: [String] {
        acceptedDocumentType.map { String($0) }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    enum CodingKeys: String, CodingKey {
        case success, task, sessionId, reference, companyName, welcomeMessage, logoURL, language
        case gps, allowFileUpload, reviewData, preloadFaceLib, documentSide
        case acceptedDocumentCountry, acceptedDocumentType, selectedDocumentCountry, selectedDocumentType
        case hasDocumentFile, hasFaceFile, verifyDocumentNo, verifyName, verifyDob, verifyAge, verifyAddress
        case verifyPostCode = "verifyPostcode"
        case userPhone, phoneCountryCode, customField, contractSource
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func s(_ k: CodingKeys) -> String { (try? c.decode(String.self, forKey: k)) ?? "" }
        func b(_ k: CodingKeys) -> Bool { (try? c.decode(Bool.self, forKey: k)) ?? false }
        func i(_ k: CodingKeys) -> Int { (try? c.decode(Int.self, forKey: k)) ?? 0 }
        success = b(.success)
        task = try? c.decode(String.self, forKey: .task)
        sessionId = try? c.decode(String.self, forKey: .sessionId)
        reference = try? c.decode(String.self, forKey: .reference)
        companyName = s(.companyName); welcomeMessage = s(.welcomeMessage); logoURL = s(.logoURL); language = s(.language)
        gps = b(.gps); allowFileUpload = b(.allowFileUpload); reviewData = b(.reviewData); preloadFaceLib = b(.preloadFaceLib)
        documentSide = i(.documentSide)
        acceptedDocumentCountry = s(.acceptedDocumentCountry); acceptedDocumentType = s(.acceptedDocumentType)
        selectedDocumentCountry = s(.selectedDocumentCountry); selectedDocumentType = s(.selectedDocumentType)
        hasDocumentFile = b(.hasDocumentFile); hasFaceFile = b(.hasFaceFile)
        verifyDocumentNo = s(.verifyDocumentNo); verifyName = s(.verifyName); verifyDob = s(.verifyDob)
        verifyAge = s(.verifyAge); verifyAddress = s(.verifyAddress); verifyPostCode = s(.verifyPostCode)
        userPhone = s(.userPhone)
        phoneCountryCode = (try? c.decode([PhoneCode].self, forKey: .phoneCountryCode)) ?? []
        customField = (try? c.decode([CustomField].self, forKey: .customField)) ?? []
        contractSource = s(.contractSource)
    }
}

public struct PhoneCode: Decodable {
    public let dialCode: String
    public let code: String
    public let name: String
    enum CodingKeys: String, CodingKey { case dialCode = "dial_code", code, name }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dialCode = (try? c.decode(String.self, forKey: .dialCode)) ?? ""
        code = (try? c.decode(String.self, forKey: .code)) ?? ""
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
    }
}

/// Custom-form field. `fieldId` (server hash of `fieldLabel`) is the save_form key.
public struct CustomField: Decodable, Identifiable {
    public let fieldLabel: String
    public let fieldDescription: String
    public let fieldId: String
    public let fieldType: Int
    public let fieldData: String

    public var id: String { fieldId }
    public var parsedType: CustomFieldType { CustomFieldType.from(fieldType) }

    /// Parsed dropdown options ("Display\tvalue|..."), empty for non-dropdown fields.
    public var dropdownOptions: [DropdownOption] {
        guard !fieldData.isEmpty else { return [] }
        return fieldData.split(separator: "|").compactMap { raw in
            let parts = raw.split(separator: "\t", maxSplits: 1).map(String.init)
            if parts.count == 2 { return DropdownOption(display: parts[0], value: parts[1]) }
            if parts.count == 1 { return DropdownOption(display: parts[0], value: parts[0]) }
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fieldLabel = (try? c.decode(String.self, forKey: .fieldLabel)) ?? ""
        fieldDescription = (try? c.decode(String.self, forKey: .fieldDescription)) ?? ""
        fieldId = (try? c.decode(String.self, forKey: .fieldId)) ?? ""
        fieldType = (try? c.decode(Int.self, forKey: .fieldType)) ?? 0
        fieldData = (try? c.decode(String.self, forKey: .fieldData)) ?? ""
    }
    enum CodingKeys: String, CodingKey { case fieldLabel, fieldDescription, fieldId, fieldType, fieldData }
}

public struct DropdownOption: Identifiable {
    public let display: String
    public let value: String
    public var id: String { value }
}
