#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

struct MenuBarCapture: View {
    @Environment(CaptureSession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @State private var today = ExpenseSummary.Today(total: 0, count: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IslandMark()
                VStack(alignment: .leading, spacing: 2) {
                    Text("FinFlow")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(ExpenseMoney.rupees(today.total))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            Text(status)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                session.toggle(using: modelContext)
            } label: {
                MicControl(listening: session.phase == .listening)
            }
            .buttonStyle(.plain)
            .disabled(session.phase == .analyzing)
            .frame(maxWidth: .infinity)
            Button(needsFix ? "Fix in FinFlow" : "Open FinFlow") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
        }
        .padding(18)
        .frame(width: 320)
        .background(ScreenBackground())
        .onAppear {
            refresh()
            consumeLaunch()
        }
        .onChange(of: session.phase) { _, _ in
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: CaptureLaunch.notification)) { _ in
            consumeLaunch()
        }
    }

    private var needsFix: Bool {
        if case .failed = session.phase { return true }
        return false
    }

    private var status: String {
        switch session.phase {
        case .idle:
            today.count == 1 ? "1 expense today. Click the mic to add another." : "\(today.count) expenses today. Click the mic to add one."
        case .listening:
            session.transcript.isEmpty ? "Listening…" : session.transcript
        case .analyzing:
            "Saving what you just said."
        case .done:
            "Saved on this Mac."
        case .failed(let message):
            message
        }
    }

    private func refresh() {
        today = ExpenseSummary.today()
    }

    private func consumeLaunch() {
        guard CaptureLaunch.take() else { return }
        session.beginFromLaunch(using: modelContext)
    }
}

private struct IslandMark: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.62, green: 0.4, blue: 1))
                .frame(width: 8, height: 22)
                .rotationEffect(.degrees(-16))
                .offset(x: -6, y: -8)
            Capsule()
                .fill(Color(red: 0.5, green: 0.25, blue: 1))
                .frame(width: 8, height: 22)
                .rotationEffect(.degrees(14))
                .offset(x: 6, y: -8)
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
        }
        .frame(width: 36, height: 36)
    }
}
#endif
