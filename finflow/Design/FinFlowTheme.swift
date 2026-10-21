import SwiftUI

enum FinFlowTheme {
    static let backgroundTop = Color(red: 0.035, green: 0, blue: 0.137)
    static let backgroundBottom = Color(red: 0.051, green: 0, blue: 0.196)
    static let panelTop = Color(red: 0.467, green: 0.082, blue: 1).opacity(0.10)
    static let panelBottom = Color(red: 0.439, green: 0.125, blue: 1).opacity(0.04)
    static let card = Color(red: 0.094, green: 0, blue: 0.318)
    static let tabBar = Color(red: 0.184, green: 0, blue: 0.639).opacity(0.8)
    static let tabSelected = Color(red: 0.545, green: 0.247, blue: 1)
    static let pill = Color(red: 0.302, green: 0.035, blue: 0.522)
    static let category = Color(red: 0.467, green: 0.082, blue: 1)
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
    }
}
