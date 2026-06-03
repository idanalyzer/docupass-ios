import Foundation

/// A country entry from the bundled `country.json` (ported from the web flow).
public struct Country: Decodable, Identifiable {
    public let iso: String
    public let name_en: String
    public let licencetypes: String
    public var id: String { iso }
    public var documentTypeCodes: [String] { licencetypes.map { String($0) } }

    enum CodingKeys: String, CodingKey { case iso, name_en, licencetypes }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        iso = (try? c.decode(String.self, forKey: .iso)) ?? ""
        name_en = (try? c.decode(String.self, forKey: .name_en)) ?? ""
        licencetypes = (try? c.decode(String.self, forKey: .licencetypes)) ?? ""
    }
}

public struct DocumentTypeOption: Identifiable {
    public let code: String
    public let label: String
    public var id: String { code }
}

/// Loads and filters the bundled country + document-type catalog (cached).
public final class CountryCatalog {
    public static let shared = CountryCatalog()
    private var all: [Country] = []
    private var loaded = false

    private init() {}

    public func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let url = DocuPassBundle.resources.url(forResource: "country", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Country].self, from: data) else { return }
        all = list
    }

    public func countries(accepted: [String]) -> [Country] {
        loadIfNeeded()
        return accepted.isEmpty ? all : all.filter { accepted.contains($0.iso) }
    }

    public func country(iso: String) -> Country? {
        loadIfNeeded()
        return all.first { $0.iso.caseInsensitiveCompare(iso) == .orderedSame }
    }

    public func documentTypes(iso: String, accepted: [String]) -> [DocumentTypeOption] {
        let codes = country(iso: iso)?.documentTypeCodes ?? []
        return codes.filter { accepted.isEmpty || accepted.contains($0) }
            .map { DocumentTypeOption(code: $0, label: Self.documentTypeLabel($0)) }
    }

    public static func documentTypeLabel(_ code: String) -> String {
        switch code.uppercased() {
        case "P": return "Passport"
        case "D": return "Driver License"
        case "I": return "Identity Card"
        case "R": return "Residence Permit"
        case "V": return "Visa"
        case "H": return "Health Card"
        case "T": return "Travel Document"
        default: return "Document (\(code))"
        }
    }
}
