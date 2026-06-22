import SwiftUI

public struct KYCSettings {
    public var apiConfig: DocupassApiConfig
    public var maskCircleRadius: Double
    public var maskCircleY: Double
    public var turnTimeSeconds: Double
    public var onFinish: (KYCResult) -> Void
    public var onBackAtFirstStep: () -> Void

    public init(
        apiConfig: DocupassApiConfig = .init(), maskCircleRadius: Double = 0.42,
        maskCircleY: Double = 0.45, turnTimeSeconds: Double = 2,
        onFinish: @escaping (KYCResult) -> Void = { _ in }, onBackAtFirstStep: @escaping () -> Void = {}
    ) {
        self.apiConfig = apiConfig; self.maskCircleRadius = maskCircleRadius; self.maskCircleY = maskCircleY
        self.turnTimeSeconds = turnTimeSeconds; self.onFinish = onFinish; self.onBackAtFirstStep = onBackAtFirstStep
    }

    public static func fromReference(
        _ reference: String, partyId: String? = nil, geolocation: String? = nil, enabled: Bool = true,
        onFinish: @escaping (KYCResult) -> Void = { _ in }, onBackAtFirstStep: @escaping () -> Void = {}
    ) -> Self {
        .init(apiConfig: .fromReference(reference, partyId: partyId, geolocation: geolocation, enabled: enabled), onFinish: onFinish, onBackAtFirstStep: onBackAtFirstStep)
    }
}

public struct KYCScreen: View {
    private let settings: KYCSettings
    @StateObject private var controller: DocupassKycController
    @State private var started = false

    public init(settings: KYCSettings) {
        self.settings = settings
        _controller = StateObject(wrappedValue: DocupassKycController(config: settings.apiConfig))
    }

    public init(
        reference: String, partyId: String? = nil, geolocation: String? = nil,
        onFinish: @escaping (KYCResult) -> Void = { _ in }, onBackAtFirstStep: @escaping () -> Void = {}
    ) {
        self.init(settings: .fromReference(reference, partyId: partyId, geolocation: geolocation, onFinish: onFinish, onBackAtFirstStep: onBackAtFirstStep))
    }

    public var body: some View {
        ZStack {
            KYCTheme.background.ignoresSafeArea()
            eventView
            if controller.state.isBusy { busyOverlay }
            if showBackButton { backButton }
            if let error = controller.state.error { errorOverlay(error) }
        }
        .preferredColorScheme(.dark)
        .onAppear { if !started { started = true; controller.start() } }
        .onDisappear { controller.close() }
    }

    @ViewBuilder private var eventView: some View {
        switch controller.state.event {
        case .loading:
            VStack(spacing: 14) { ProgressView().tint(KYCTheme.accent); Text("INITIALIZING VERIFICATION").font(.system(size: 14, weight: .bold)).foregroundColor(.white) }
        case let .phoneVerification(state, codeSent, currentNumber):
            PhoneVerificationView(state: state, isBusy: controller.state.isBusy, codeSent: codeSent, currentNumber: currentNumber, onSend: { controller.emit(.sendPhoneCode(number: $0, type: $1)) }, onVerify: { controller.emit(.verifyPhoneCode(number: $0, code: $1)) })
        case let .customForm(fields):
            CustomFormView(fields: fields, isBusy: controller.state.isBusy) { controller.emit(.saveCustomForm(answers: $0)) }
        case let .documentCountrySelection(countries, _):
            CountryPickerView(countries: countries) { controller.emit(.selectDocumentCountry(countryCode: $0.code)) }
        case let .documentSelection(country, types, _):
            DocumentTypePickerView(country: country, types: types, isBusy: controller.state.isBusy) { controller.emit(.selectDocumentType(documentTypeCode: $0.apiTypeCode)) }
        case let .documentCapture(_, type, side, _):
            DocumentCaptureView(documentType: type, documentSide: side, isBusy: controller.state.isBusy) { controller.emit(.uploadDocument(frontBase64: $0, backBase64: $1)) }
        case let .faceVerification(actions):
            BiometricView(actions: actions, settings: settings, isBusy: controller.state.isBusy) { controller.emit(.uploadFace(faceBase64List: $0)) }
        case let .contract(state, _, fields):
            ContractView(state: state, signatureFields: fields, isBusy: controller.state.isBusy) { controller.emit(.submitContract(signatures: $0)) }
        case .partyPending:
            PartyPendingView(isBusy: controller.state.isBusy) { controller.emit(.refresh) }
        case let .completed(result):
            ResultView(success: true, error: nil) { settings.onFinish(result) }
        case let .failed(result, error):
            ResultView(success: false, error: error) { settings.onFinish(result) }
        }
    }

    private var showBackButton: Bool {
        controller.state.event != .loading && !controller.state.event.isResultScreen
    }

    private var backButton: some View {
        VStack { HStack {
            Button(action: goBack) { Image(systemName: "chevron.left").font(.system(size: 19, weight: .bold)).frame(width: 44, height: 44).background(Color.black.opacity(0.42)).clipShape(Circle()) }
                .foregroundColor(.white).disabled(controller.state.isBusy).accessibilityLabel("Back")
            Spacer()
        }.padding(.horizontal, 14).padding(.top, 4); Spacer() }
    }

    private var busyOverlay: some View {
        ZStack { Color.black.opacity(0.18).ignoresSafeArea(); VStack { Spacer(); ProgressView().tint(KYCTheme.accent).padding(.bottom, 24) } }
            .allowsHitTesting(true)
    }

    private func errorOverlay(_ error: DocupassKycErrorEvent) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { controller.emit(.clearError) }
            VStack(alignment: .leading, spacing: 14) {
                HStack { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow); Text(error.normalized?.title ?? "Verification error").font(.headline); Spacer() }
                Text(error.message).foregroundColor(KYCTheme.muted)
                if let suggestion = error.normalized?.suggestion { Text(suggestion).font(.subheadline).foregroundColor(.white) }
                Button("DISMISS") { controller.emit(.clearError) }.buttonStyle(PrimaryButtonStyle())
            }.padding(20).background(Color(red: 18 / 255, green: 24 / 255, blue: 21 / 255)).cornerRadius(8).padding(24)
        }
    }

    private func goBack() {
        if controller.state.canGoBack { controller.emit(.back) } else { settings.onBackAtFirstStep() }
    }
}
