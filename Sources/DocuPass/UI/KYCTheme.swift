import SwiftUI

enum KYCTheme {
    static let background = Color(red: 5 / 255, green: 10 / 255, blue: 8 / 255)
    static let panel = Color.white.opacity(0.08)
    static let accent = Color(red: 0, green: 1, blue: 171 / 255)
    static let accentText = Color(red: 0, green: 38 / 255, blue: 26 / 255)
    static let muted = Color.white.opacity(0.62)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .black))
            .foregroundColor(KYCTheme.accentText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(KYCTheme.accent.opacity(configuration.isPressed ? 0.75 : 1))
            .cornerRadius(6)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.white.opacity(configuration.isPressed ? 0.18 : 0.1))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2)))
            .cornerRadius(6)
    }
}

struct StepLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 13, weight: .bold)).foregroundColor(KYCTheme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KYCTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(14).foregroundColor(.white).background(Color.white.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2))).cornerRadius(6)
    }
}
