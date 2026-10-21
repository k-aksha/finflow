import SwiftData
import SwiftUI

enum CapturePhase: Equatable {
    case idle
    case listening
    case analyzing
    case done
    case failed(String)
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var session = CaptureSession()

    var body: some View {
        HomeScreen(session: session, modelContext: modelContext)
    }
}

private struct HomeScreen: View {
    @Bindable var session: CaptureSession
    var modelContext: ModelContext

    var body: some View {
        ZStack {
            ScreenBackground()
            PanelBackground()
            VStack(spacing: 0) {
                NucleusAvatar(mood: mood)
                    .padding(.top, session.phase == .idle ? 78 : 28)
                ScrollView {
                    VStack(spacing: 0) {
                        statusLine
                            .padding(.top, session.phase == .idle ? 18 : 8)
                        transcriptCard
                            .padding(.top, 18)
                            .padding(.horizontal, 36)
                        if case .failed = session.phase {
                            recoveryForm
                                .padding(.top, 16)
                                .padding(.horizontal, 36)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: .infinity)
                Button {
                    session.toggle(using: modelContext)
                } label: {
                    MicControl(listening: session.phase == .listening)
                }
                .buttonStyle(.plain)
                .disabled(session.phase == .analyzing)
                .padding(.bottom, 8)
            }
        }
    }

    private var mood: NucleusMood {
        switch session.phase {
        case .idle: .happy
        case .listening: .focused
        case .analyzing, .failed: .skeptical
        case .done: .done
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch session.phase {
        case .idle:
            Text("Hello There, Good Day,\nTap to speak your expenses, then tap again to finish")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .frame(maxWidth: 280)
        case .listening:
            Text("I am listening...")
                .font(.system(size: 12))
                .foregroundStyle(.white)
        case .analyzing:
            Text("Give me a moment.. analyzing")
                .font(.system(size: 12))
                .foregroundStyle(.white)
        case .done:
            Text("It’s Done..")
                .font(.system(size: 12))
                .foregroundStyle(.white)
        case .failed:
            Text("Couldn’t analyze that")
                .font(.system(size: 12))
                .foregroundStyle(.white)
        }
    }

    private var recoveryForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .failed(let message) = session.phase {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(FinFlowTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            recoveryField("Amount, such as 1500 or one lakh", text: $session.recoveryAmount)
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Amount")
            recoveryField("What it was for", text: $session.recoveryTitle)
                .accessibilityLabel("What it was for")
            Button {
                session.saveRecovery(using: modelContext)
            } label: {
                Text("Save this expense")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(FinFlowTheme.category, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!session.canSaveRecovery)
            .opacity(session.canSaveRecovery ? 1 : 0.45)
            HStack(spacing: 18) {
                Button("Analyze again") {
                    session.retry(using: modelContext)
                }
                .disabled(session.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Dismiss") {
                    session.dismiss()
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
    }

    private func recoveryField(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var transcriptCard: some View {
        switch session.phase {
        case .idle:
            EmptyView()
        case .failed:
            TextEditor(text: $session.transcript)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 88)
                .padding(12)
                .background(FinFlowTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityLabel("Spoken note")
        case .analyzing:
            Text(session.transcript.isEmpty ? "…" : session.transcript)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.42, green: 0.33, blue: 0.62),
                                    Color(red: 0.58, green: 0.08, blue: 0.91).opacity(0.35)
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: 140
                            )
                        )
                        .blur(radius: 16)
                }
        default:
            Text(session.transcript.isEmpty ? "Transcription Goes here..." : session.transcript)
                .font(.system(size: 12))
                .foregroundStyle(session.transcript.isEmpty ? FinFlowTheme.placeholder : .white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .top)
                .padding(22)
                .background(FinFlowTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
