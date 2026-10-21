import SwiftData
import SwiftUI

@main
struct finflowApp: App {
    private let container = ExpenseContainer.make()

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .modelContainer(container)
            } else {
                StoreFailureView()
            }
        }
    }
}

private enum ExpenseContainer {
    static func make() -> ModelContainer? {
        try? ModelContainer(for: Expense.self)
    }
}

private struct StoreFailureView: View {
    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 12) {
                Text("FinFlow couldn’t open its saved expenses.")
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("Your notes stay on this device. Quit the app and open it again.")
                    .font(.system(size: 15))
                    .foregroundStyle(FinFlowTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(32)
        }
    }
}

struct RootView: View {
    @AppStorage("hasEnteredFinFlow") private var hasEntered = false
    @State private var showSplash = true
    @State private var tab: AppTab = .home

    var body: some View {
        ScreenScaleReader {
            ZStack {
                if showSplash {
                    splash
                } else if !hasEntered {
                    WelcomeView {
                        hasEntered = true
                    }
                } else {
                    main
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var splash: some View {
        ZStack {
            ScreenBackground()
            CharacterAnimation(
                name: "Splash",
                designWidth: 402,
                designHeight: 874,
                loop: false,
                fillsCanvas: true
            ) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showSplash = false
                }
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeOut(duration: 0.35)) {
                showSplash = false
            }
        }
    }

    private var main: some View {
        ZStack {
            HomeView()
                .opacity(tab == .home ? 1 : 0)
                .allowsHitTesting(tab == .home)
            TimelineView()
                .opacity(tab == .ledger ? 1 : 0)
                .allowsHitTesting(tab == .ledger)
            SettingsView()
                .opacity(tab == .settings ? 1 : 0)
                .allowsHitTesting(tab == .settings)
        }
        .safeAreaInset(edge: .bottom, spacing: 10) {
            FlowTabBar(selection: $tab)
                .padding(.bottom, 6)
        }
    }
}
