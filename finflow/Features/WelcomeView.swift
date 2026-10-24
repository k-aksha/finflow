import FoundationModels
import SwiftData
import SwiftUI

struct WelcomeView: View {
    var onEnter: () -> Void

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                ZStack {
                    ProportionalImage(name: "WelcomeGlow", designWidth: 402, designHeight: 402)
                        .allowsHitTesting(false)
                    ProportionalImage(name: "WelcomeCharacter", designWidth: 141, designHeight: 241)
                }
                .padding(.top, 12)
                Spacer()
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("Welcome to FinFlow")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Your smart finance companion. Track, save, and grow your money effortlessly.")
                            .font(.system(size: 14))
                            .foregroundStyle(FinFlowTheme.muted)
                            .lineSpacing(3)
                    }
                    .multilineTextAlignment(.center)
                    Button(action: onEnter) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FinFlowTheme.backgroundBottom)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Text("No account. What you record stays on this device.")
                        .font(.system(size: 15))
                        .foregroundStyle(FinFlowTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
                .frame(maxWidth: 440)
            }
        }
    }

}

struct SettingsView: View {
    var embedded: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @State private var confirmErase = false
    @State private var eraseError: String?

    var body: some View {
        ZStack {
            if !embedded {
                ScreenBackground()
                PanelBackground()
            }
            VStack(alignment: .leading, spacing: 22) {
                Text("On this device")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, embedded ? 8 : 36)
                settingRow(
                    title: "Apple Intelligence",
                    value: SystemLanguageStatus.summary
                )
                settingRow(
                    title: "Speech",
                    value: "Transcribed on device. Tap the mic to start, then tap again to finish"
                )
                settingRow(
                    title: "From anywhere",
                    value: launchHint
                )
                settingRow(
                    title: "Storage",
                    value: "\(expenses.count) expenses saved locally"
                )
                Button(role: .destructive) {
                    confirmErase = true
                } label: {
                    Text("Erase all expenses")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(expenses.isEmpty)
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
        .confirmationDialog(
            "Erase every expense stored on this device?",
            isPresented: $confirmErase,
            titleVisibility: .visible
        ) {
            Button("Erase", role: .destructive) {
                do {
                    try ExpenseStore.erase(expenses, in: modelContext)
                } catch {
                    eraseError = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Couldn’t erase expenses",
            isPresented: Binding(
                get: { eraseError != nil },
                set: { if !$0 { eraseError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(eraseError ?? "")
        }
    }

    private var launchHint: String {
        #if os(macOS)
        "Click the FinFlow mic in the menu bar, or press Command-Shift-E. A desktop widget opens the same listening session."
        #elseif os(iOS)
        "Add the FinFlow widget, or add Log expense in Control Center. Siri, the Action Button, and Back Tap can run “Log an expense.” On iPhone 14 Pro and later, listening shows in the Dynamic Island."
        #else
        "Tap the mic to start listening."
        #endif
    }

    private func settingRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FinFlowTheme.muted)
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
        }
        #if os(macOS)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FinFlowTheme.cardRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        #endif
    }
}

enum SystemLanguageStatus {
    static var summary: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            "Ready. Expense notes are structured on device."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in Settings. Until then, amounts you phrase clearly are still saved on device."
        case .unavailable(.deviceNotEligible):
            "This device cannot run Apple Intelligence. Clear amounts are still saved on device."
        case .unavailable(.modelNotReady):
            "The on-device model is still getting ready."
        @unknown default:
            "Checking the on-device model."
        }
    }
}
