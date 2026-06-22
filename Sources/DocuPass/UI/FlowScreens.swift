import SwiftUI

struct PhoneVerificationView: View {
    let state: DocupassSessionState
    let isBusy: Bool
    let codeSent: Bool
    let currentNumber: String?
    let onSend: (String?, String) -> Void
    let onVerify: (String?, String) -> Void
    @State private var dialCode = "+1"
    @State private var number = ""
    @State private var otp = ""

    private var builtNumber: String? {
        if state.userPhone?.isEmpty == false { return nil }
        let digits = number.drop(while: { $0 == "0" })
        return digits.isEmpty ? nil : dialCode + digits
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StepLabel(text: "STEP: PHONE VERIFICATION")
                Text("Verify your phone number to continue.").foregroundColor(KYCTheme.muted)
                if let preset = state.userPhone, !preset.isEmpty {
                    VStack(alignment: .leading, spacing: 5) { Text("Phone number").font(.caption).foregroundColor(KYCTheme.muted); Text(preset).font(.title3.bold()) }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(KYCTheme.panel).cornerRadius(6)
                } else {
                    if !state.phoneCountryCodes.isEmpty {
                        Menu {
                            ForEach(state.phoneCountryCodes, id: \.dialCode) { item in Button("\(item.name) \(item.dialCode)") { dialCode = item.dialCode } }
                        } label: { HStack { Text("Country code"); Spacer(); Text(dialCode); Image(systemName: "chevron.up.chevron.down") }.modifier(KYCTextFieldStyle()) }
                    }
                    HStack { Text(dialCode).foregroundColor(KYCTheme.muted); TextField("Phone number", text: $number).keyboardType(.phonePad).onChange(of: number) { number = $0.filter(\.isNumber) } }.modifier(KYCTextFieldStyle())
                }
                HStack(spacing: 10) {
                    Button { onSend(builtNumber, "sms") } label: { Label("SEND SMS", systemImage: "message.fill") }.buttonStyle(PrimaryButtonStyle())
                    Button { onSend(builtNumber, "call") } label: { Label("CALL", systemImage: "phone.fill") }.buttonStyle(SecondaryButtonStyle())
                }.disabled(isBusy || (state.userPhone?.isEmpty != false && builtNumber == nil))
                if codeSent {
                    TextField("6 digit code", text: $otp).keyboardType(.numberPad).onChange(of: otp) { otp = String($0.filter(\.isNumber).prefix(6)) }.modifier(KYCTextFieldStyle())
                    Button("VERIFY CODE") { onVerify(currentNumber, otp) }.buttonStyle(PrimaryButtonStyle()).disabled(isBusy || otp.count != 6)
                }
            }.padding(.horizontal, 24).padding(.top, 90).padding(.bottom, 30)
        }
    }
}

struct CustomFormView: View {
    let fields: [DocupassCustomField]
    let isBusy: Bool
    let onSubmit: ([String: String]) -> Void
    @State private var answers: [String: String] = [:]

    private var complete: Bool { !fields.isEmpty && fields.allSatisfy { !(answers[key(for: $0)] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StepLabel(text: "STEP: CUSTOM FORM")
                ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(field.fieldLabel.isEmpty ? key(for: field) : field.fieldLabel).font(.headline)
                        if !field.fieldDescription.isEmpty { Text(field.fieldDescription).font(.caption).foregroundColor(KYCTheme.muted) }
                        if field.fieldType == 2 {
                            ForEach(parseOptions(field.fieldData), id: \.value) { option in
                                Button { answers[key(for: field)] = option.value } label: {
                                    HStack { Image(systemName: answers[key(for: field)] == option.value ? "checkmark.circle.fill" : "circle"); Text(option.label); Spacer() }
                                        .padding(14).foregroundColor(answers[key(for: field)] == option.value ? KYCTheme.accentText : .white)
                                        .background(answers[key(for: field)] == option.value ? KYCTheme.accent : KYCTheme.panel).cornerRadius(6)
                                }
                            }
                        } else if field.fieldType == 1 {
                            ZStack(alignment: .topLeading) { TextEditor(text: binding(for: field)).frame(minHeight: 110).padding(8).foregroundColor(.white); RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2)) }
                        } else { TextField("", text: binding(for: field)).modifier(KYCTextFieldStyle()) }
                    }
                }
                Button("SAVE FORM") { onSubmit(answers) }.buttonStyle(PrimaryButtonStyle()).disabled(isBusy || !complete)
            }.padding(.horizontal, 24).padding(.top, 90).padding(.bottom, 30)
        }
    }

    private func key(for field: DocupassCustomField) -> String { field.fieldId.isEmpty ? field.fieldLabel : field.fieldId }
    private func binding(for field: DocupassCustomField) -> Binding<String> { Binding(get: { answers[key(for: field)] ?? "" }, set: { answers[key(for: field)] = $0 }) }
}

private struct FormOption { let label: String; let value: String }
private func parseOptions(_ raw: String) -> [FormOption] {
    raw.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.map { line in
        let separator = [";", "\t", "|"].first { line.contains($0) }
        guard let separator else { return .init(label: line, value: line) }
        let parts = line.components(separatedBy: separator)
        let label = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? line
        let value = parts.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
        return .init(label: label, value: value.isEmpty ? label : value)
    }
}

struct CountryPickerView: View {
    let countries: [KYCCountry]
    let onSelected: (KYCCountry) -> Void
    @State private var query = ""
    private var filtered: [KYCCountry] { query.isEmpty ? countries : countries.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.code.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepLabel(text: "STEP: SELECT COUNTRY")
            HStack { Image(systemName: "magnifyingglass"); TextField("Search", text: $query) }.modifier(KYCTextFieldStyle())
            ScrollView { LazyVStack(spacing: 8) {
                ForEach(filtered) { country in Button { onSelected(country) } label: {
                    HStack { Text(country.flag); Text(country.name).font(.system(size: 17, weight: .medium)); Spacer(); Text(country.code).font(.caption).foregroundColor(KYCTheme.muted); Image(systemName: "chevron.right") }
                        .padding(16).foregroundColor(.white).background(KYCTheme.panel).cornerRadius(6)
                } }
            } }
        }.padding(.horizontal, 24).padding(.top, 90).padding(.bottom, 20)
    }
}

struct DocumentTypePickerView: View {
    let country: KYCCountry
    let types: [KYCDocumentType]
    let isBusy: Bool
    let onSelected: (KYCDocumentType) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StepLabel(text: "STEP: SELECT DOCUMENT")
            Text("For \(country.flag) \(country.name)").foregroundColor(KYCTheme.muted).padding(.bottom, 18)
            ForEach(types) { type in Button { onSelected(type) } label: {
                HStack { Image(systemName: icon(for: type)).frame(width: 26); Text(type.label).font(.headline); Spacer(); Image(systemName: "chevron.right") }.padding(.horizontal, 18)
            }.buttonStyle(SecondaryButtonStyle()).disabled(isBusy) }
            Spacer()
        }.padding(.horizontal, 24).padding(.top, 110).padding(.bottom, 30)
    }
    private func icon(for type: KYCDocumentType) -> String { type == .passport ? "book.closed.fill" : type == .driverLicense ? "car.fill" : "person.text.rectangle.fill" }
}

struct PartyPendingView: View {
    let isBusy: Bool
    let onRefresh: () -> Void
    var body: some View {
        VStack(spacing: 18) { Image(systemName: "clock.badge.checkmark").font(.system(size: 48)).foregroundColor(KYCTheme.accent); Text("VERIFICATION PENDING").font(.title3.bold()); Text("Another party or a manual review must finish before this session can continue.").multilineTextAlignment(.center).foregroundColor(KYCTheme.muted); Button { onRefresh() } label: { Label("REFRESH", systemImage: "arrow.clockwise") }.buttonStyle(PrimaryButtonStyle()).disabled(isBusy) }.padding(28)
    }
}

struct ResultView: View {
    let success: Bool
    let error: DocupassNormalizedError?
    let onFinish: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.octagon.fill").font(.system(size: 58)).foregroundColor(success ? KYCTheme.accent : Color(red: 1, green: 0.52, blue: 0.52))
            Text(success ? "VERIFICATION COMPLETE" : "VERIFICATION FAILED").font(.title3.bold())
            if let error { Text(error.displayMessage()).font(.subheadline).multilineTextAlignment(.center).foregroundColor(KYCTheme.muted) }
            Button("FINISH", action: onFinish).buttonStyle(success ? AnyButtonStyle(PrimaryButtonStyle()) : AnyButtonStyle(SecondaryButtonStyle()))
        }.padding(28)
    }
}

private struct AnyButtonStyle: ButtonStyle {
    private let bodyBuilder: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { bodyBuilder = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { bodyBuilder(configuration) }
}
