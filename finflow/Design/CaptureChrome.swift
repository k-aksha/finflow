import SwiftUI

enum AppTab: Hashable {
    case home
    case ledger
    case settings
}

struct FlowTabBar: View {
    @Binding var selection: AppTab

    @Environment(\.screenScale) private var screenScale

    var body: some View {
        HStack(spacing: 2 * screenScale) {
            tab(.home, asset: "TabIconHome", label: "Home")
            tab(.ledger, asset: "TabIconDays", label: "Expense")
            tab(.settings, asset: "TabIconSettings", label: "Settings")
        }
        .padding(5 * screenScale)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().fill(FinFlowTheme.tabBar)
                }
        }
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.16), lineWidth: 0.6)
        }
        .shadow(
            color: Color(red: 0.27, green: 0.05, blue: 0.85).opacity(0.45),
            radius: 18 * screenScale,
            y: 10 * screenScale
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: selection)
    }

    private func tab(_ tab: AppTab, asset: String, label: String) -> some View {
        let selected = selection == tab
        return Button {
            selection = tab
        } label: {
            HStack(spacing: 8 * screenScale) {
                ProportionalImage(name: asset, designWidth: 20, designHeight: 20)
                    .opacity(selected ? 1 : 0.62)
                if selected {
                    Text(label)
                        .font(.system(size: 15 * screenScale, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, (selected ? 16 : 14) * screenScale)
            .frame(height: 48 * screenScale)
            .background {
                if selected {
                    Capsule().fill(FinFlowTheme.tabSelected)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct MicControl: View {
    var listening: Bool
    @Environment(\.screenScale) private var screenScale

    private var side: CGFloat { 88 * screenScale }

    var body: some View {
        ZStack {
            if listening {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.55, green: 0.28, blue: 1),
                                Color(red: 0.32, green: 0.08, blue: 0.72)
                            ],
                            center: .center,
                            startRadius: 4 * screenScale,
                            endRadius: side / 2
                        )
                    )
                    .frame(width: side, height: side)
                    .shadow(color: Color(red: 0.45, green: 0.2, blue: 1).opacity(0.7), radius: 18 * screenScale, y: 8 * screenScale)
                RoundedRectangle(cornerRadius: 4 * screenScale, style: .continuous)
                    .fill(.white)
                    .frame(width: 22 * screenScale, height: 22 * screenScale)
            } else {
                ProportionalImage(name: "MicButton", designWidth: 88, designHeight: 88)
            }
        }
        .accessibilityLabel(listening ? "Stop" : "Tap to speak expenses")
    }
}
