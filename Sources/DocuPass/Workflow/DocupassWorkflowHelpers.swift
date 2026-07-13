import Foundation

func normalizeWorkflow(_ input: [KYCStep]) -> [KYCStep] {
    if input.contains(where: { if case .captureDocument = $0 { true } else { false } }) { return input }
    return input.flatMap { step -> [KYCStep] in
        if case .selectDocument = step { return [step, .captureDocument] }
        return [step]
    }
}

func firstFaceActions(in workflow: [KYCStep]) -> [KYCAction] {
    for case let .faceVerification(actions) in workflow where !actions.isEmpty { return actions }
    return KYCAction.allCases
}

func randomizedFaceActions(_ candidates: [KYCAction], minimumCount: Int = 2) -> [KYCAction] {
    var selected = Array(Set(candidates)).shuffled()
    let desired = min(max(minimumCount, 1), KYCAction.allCases.count)
    if selected.count < desired { selected.append(contentsOf: KYCAction.allCases.filter { !selected.contains($0) }.shuffled()) }
    return Array(selected.prefix(desired))
}

func countriesForFilter(_ codes: [String]?) -> [KYCCountry] {
    guard let codes, !codes.isEmpty else { return ALL_COUNTRIES }
    let known = Dictionary(uniqueKeysWithValues: ALL_COUNTRIES.map { ($0.code.uppercased(), $0) })
    return Array(Set(codes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }))
        .filter { !$0.isEmpty }.map { known[$0] ?? KYCCountry(code: $0, name: $0) }.sorted { $0.name < $1.name }
}

func countryFromCode(_ code: String) -> KYCCountry {
    let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    return ALL_COUNTRIES.first { $0.code.caseInsensitiveCompare(normalized) == .orderedSame }
        ?? KYCCountry(code: normalized, name: normalized)
}

func documentTypeFromCode(_ code: String) -> KYCDocumentType? {
    KYCDocumentType(rawValue: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
}

func documentTypesForFilter(_ codes: [String]?) -> [KYCDocumentType] {
    let accepted = Set(codes?.flatMap { Optional($0).documentTypeCodeValues } ?? [])
    return accepted.isEmpty ? KYCDocumentType.allCases : KYCDocumentType.allCases.filter { accepted.contains($0.rawValue) }
}

func extractContractSignatureFields(_ source: String) -> [DocupassContractSignatureField] {
    guard let tagRegex = try? NSRegularExpression(pattern: #"<(?:img|div)\b[^>]*data-signature[^>]*>"#, options: .caseInsensitive) else { return [] }
    let range = NSRange(source.startIndex..., in: source)
    var seen = Set<String>()
    return tagRegex.matches(in: source, range: range).compactMap { match in
        guard let swiftRange = Range(match.range, in: source) else { return nil }
        let tag = String(source[swiftRange])
        guard let uid = htmlAttribute("data-uid", in: tag), !uid.isEmpty, seen.insert(uid).inserted else { return nil }
        return .init(uid: uid, label: htmlAttribute("data-label", in: tag).flatMap { $0.isEmpty ? nil : $0 } ?? "Signature", party: htmlAttribute("data-party", in: tag))
    }
}

private func htmlAttribute(_ name: String, in tag: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: #"\b"# + NSRegularExpression.escapedPattern(for: name) + #"\s*=\s*[\"']([^\"']*)[\"']"#, options: .caseInsensitive),
          let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
          let range = Range(match.range(at: 1), in: tag) else { return nil }
    return String(tag[range]).replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
}

func formatApiErrorMessage(_ error: DocupassApiError) -> String {
    let message = error.message.trimmingCharacters(in: .whitespacesAndNewlines)
    if !message.isEmpty && !message.isDiagnosticTokenList { return message }
    let normalized = normalizeDocupassError(error)
    return normalized.detail.isEmpty ? normalized.title : normalized.detail
}

private extension String {
    var isDiagnosticTokenList: Bool {
        let parts = components(separatedBy: CharacterSet(charactersIn: ",;\n")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !parts.isEmpty, let regex = try? NSRegularExpression(pattern: #"^[A-Z][A-Z0-9_ -]{2,}$"#) else { return false }
        return parts.allSatisfy { regex.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
    }
}
