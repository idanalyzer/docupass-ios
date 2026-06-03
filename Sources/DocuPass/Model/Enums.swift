import Foundation

/// API region, derived from the reference prefix.
/// - US: https://api2.idanalyzer.com/docupassappv3
/// - EU: https://api2-eu.idanalyzer.com/docupassappv3
public enum DocuPassRegion: String {
    case us
    case eu

    public var baseURL: String {
        switch self {
        case .us: return "https://api2.idanalyzer.com/docupassappv3"
        case .eu: return "https://api2-eu.idanalyzer.com/docupassappv3"
        }
    }

    /// A reference starting with `EU` (case-insensitive) is an EU session.
    public static func from(reference: String) -> DocuPassRegion {
        reference.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("EU") ? .eu : .us
    }
}

/// The live step the server is asking the client to perform (`task` field).
/// Terminal/completion states are NOT tasks — they arrive as `DocuPassError`.
public enum DocuPassTask: String {
    case phone
    case customForm = "customform"
    case document
    case face
    case contract
    case partyPending = "party_pending"
    case unknown = ""

    static func from(_ value: String?) -> DocuPassTask {
        guard let value else { return .unknown }
        return DocuPassTask(rawValue: value) ?? .unknown
    }
}

/// Which document sides the session requires.
public enum DocumentSide: Int {
    case auto = 0
    case frontOnly = 1
    case frontAndBack = 2

    static func from(_ code: Int) -> DocumentSide { DocumentSide(rawValue: code) ?? .auto }
}

/// Custom-form field input type. `.dropdown` carries options in `fieldData`.
public enum CustomFieldType: Int {
    case text = 0
    case multiline = 1
    case dropdown = 2

    static func from(_ code: Int) -> CustomFieldType { CustomFieldType(rawValue: code) ?? .text }
}

/// Phone-verification delivery channel.
public enum PhoneChannel: String {
    case sms
    case call
}
