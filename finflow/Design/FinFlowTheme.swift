import SwiftUI

enum FinFlowTheme {
    static let backgroundTop = Color(red: 17.0 / 255, green: 17.0 / 255, blue: 17.0 / 255)
    static let backgroundBottom = Color(red: 9.0 / 255, green: 9.0 / 255, blue: 9.0 / 255)
    static let panelTop = Color.white.opacity(0.045)
    static let panelBottom = Color.white.opacity(0.02)
    static let card = Color(red: 28.0 / 255, green: 28.0 / 255, blue: 28.0 / 255)
    static let cardRaised = Color(red: 42.0 / 255, green: 42.0 / 255, blue: 42.0 / 255)
    static let tabBar = Color(red: 23.0 / 255, green: 23.0 / 255, blue: 23.0 / 255)
    static let tabSelected = Color(red: 46.0 / 255, green: 46.0 / 255, blue: 46.0 / 255)
    static let pill = Color(red: 36.0 / 255, green: 36.0 / 255, blue: 36.0 / 255)
    static let category = Color(red: 51.0 / 255, green: 51.0 / 255, blue: 51.0 / 255)
    static let muted = Color.white.opacity(0.7)
    static let faint = Color(red: 0.671, green: 0.671, blue: 0.671).opacity(0.9)
    static let placeholder = Color(red: 0.416, green: 0.416, blue: 0.416)

    static func rupees(_ amount: Double, prominent: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "₹\(amount)"
    }
}

struct ScreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [FinFlowTheme.backgroundTop, FinFlowTheme.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct PanelBackground: View {
    var body: some View {
        #if os(macOS)
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(FinFlowTheme.card)
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        #else
        RoundedRectangle(cornerRadius: 39, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [FinFlowTheme.panelTop, FinFlowTheme.panelBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(.horizontal, 9)
            .padding(.top, 8)
            .padding(.bottom, 6)
        #endif
    }
}
