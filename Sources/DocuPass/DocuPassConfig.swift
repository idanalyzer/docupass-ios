import Foundation

/// Configuration for a DocuPass verification session. The only required value is
/// `reference` (created server-side via the ID Analyzer v2 API). The device never
/// holds your API key — fetch the result server-side with `GET /docupass/{ref}`.
public struct DocuPassConfig {
    public let reference: String
    public let partyId: String?
    public let baseURLOverride: String?
    public let liveness: LivenessConfig
    public let timeout: TimeInterval

    public init(
        reference: String,
        partyId: String? = nil,
        baseURLOverride: String? = nil,
        liveness: LivenessConfig = LivenessConfig(),
        timeout: TimeInterval = 30
    ) {
        precondition(!reference.trimmingCharacters(in: .whitespaces).isEmpty, "DocuPass reference must not be blank")
        self.reference = reference
        self.partyId = partyId
        self.baseURLOverride = baseURLOverride
        self.liveness = liveness
        self.timeout = timeout
    }

    public var region: DocuPassRegion { DocuPassRegion.from(reference: reference) }

    public var baseURL: String {
        if let o = baseURLOverride, !o.isEmpty {
            return o.hasSuffix("/") ? String(o.dropLast()) : o
        }
        return region.baseURL
    }
}

/// Active-liveness parameters, ported 1:1 from the DocuPass v3 web client
/// (DOCUPASS_PROTOCOL_SPEC §8). Change with care — tuned to the bundled model.
public struct LivenessConfig {
    public var thresholdOffsetPercent: Double
    public var thresholdTurnPercent: Double
    public var frontStayMs: Double
    public var leftStayMs: Double
    public var rightStayMs: Double
    public var successStayMs: Double
    public var maxImageSize: CGFloat
    public var jpegQuality: CGFloat

    public init(
        thresholdOffsetPercent: Double = 10,
        thresholdTurnPercent: Double = 40,
        frontStayMs: Double = 3000,
        leftStayMs: Double = 3000,
        rightStayMs: Double = 3000,
        successStayMs: Double = 2000,
        maxImageSize: CGFloat = 800,
        jpegQuality: CGFloat = 0.9
    ) {
        self.thresholdOffsetPercent = thresholdOffsetPercent
        self.thresholdTurnPercent = thresholdTurnPercent
        self.frontStayMs = frontStayMs
        self.leftStayMs = leftStayMs
        self.rightStayMs = rightStayMs
        self.successStayMs = successStayMs
        self.maxImageSize = maxImageSize
        self.jpegQuality = jpegQuality
    }
}
