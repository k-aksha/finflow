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
    @Environment(CaptureSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HomeScreen(session: session, modelContext: modelContext)
            .onAppear {
                guard CaptureLaunch.take() else { return }
                session.beginFromLaunch(using: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: CaptureLaunch.notification)) { _ in
                guard CaptureLaunch.take() else { return }
                session.beginFromLaunch(using: modelContext)
            }
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
                            .padding(.horizontal, contentInset)
                        if case .failed = session.phase {
                            recoveryForm
                                .padding(.top, 16)
                                .padding(.horizontal, contentInset)
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
                .padding(.bottom, micBottomPadding)
            }
        }
    }

    private var micBottomPadding: CGFloat {
        #if os(macOS)
        50
        #else
        8
        #endif
    }

    private var contentInset: CGFloat {
        #if os(macOS)
        44
        #else
        36
        #endif
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
            #if os(macOS)
            VStack(spacing: 8) {
                Text("Hello There, Good Day")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Tap to speak your expenses, then tap again to finish")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(FinFlowTheme.muted)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)
            #else
            Text("Hello There, Good Day,\nTap to speak your expenses, then tap again to finish")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .frame(maxWidth: 280)
            #endif
        case .listening:
            Text("I am listening...")
                .font(.system(size: statusSize, weight: statusWeight))
                .foregroundStyle(.white)
        case .analyzing:
            Text("Give me a moment.. analyzing")
                .font(.system(size: statusSize, weight: statusWeight))
                .foregroundStyle(.white)
        case .done:
            Text("It’s Done..")
                .font(.system(size: statusSize, weight: statusWeight))
                .foregroundStyle(.white)
        case .failed:
            Text("Couldn’t analyze that")
                .font(.system(size: statusSize, weight: statusWeight))
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
                .amountField()
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
            .background(fieldFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statusSize: CGFloat {
        #if os(macOS)
        18
        #else
        12
        #endif
    }

    private var statusWeight: Font.Weight {
        #if os(macOS)
        .semibold
        #else
        .regular
        #endif
    }

    private var fieldFill: Color {
        #if os(macOS)
        FinFlowTheme.cardRaised
        #else
        Color.white.opacity(0.08)
        #endif
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
                .padding(failedTranscriptPadding)
                .modifier(NoteCard(radius: 24))
                .accessibilityLabel("Spoken note")
        case .analyzing:
            Text(session.transcript.isEmpty ? "…" : session.transcript)
                .font(.system(size: transcriptSize))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 46.0 / 255, green: 46.0 / 255, blue: 46.0 / 255),
                                    FinFlowTheme.card
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
                .font(.system(size: transcriptSize, weight: transcriptWeight))
                .foregroundStyle(session.transcript.isEmpty ? FinFlowTheme.placeholder : .white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .top)
                .padding(22)
                .modifier(NoteCard(radius: 24))
        }
    }

    private var transcriptSize: CGFloat {
        #if os(macOS)
        15
        #else
        12
        #endif
    }

    private var transcriptWeight: Font.Weight {
        #if os(macOS)
        session.transcript.isEmpty ? .regular : .medium
        #else
        .regular
        #endif
    }

    private var failedTranscriptPadding: CGFloat {
        #if os(macOS)
        22
        #else
        12
        #endif
    }
}

private struct NoteCard: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        content.background {
            #if os(macOS)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(FinFlowTheme.cardRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            #else
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(FinFlowTheme.card)
            #endif
        }
    }
}

private extension View {
    @ViewBuilder
    func amountField() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}
