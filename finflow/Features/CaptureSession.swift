import Foundation
import Observation
import SwiftData
#if os(iOS)
import UIKit
#endif

@MainActor
@Observable
final class CaptureSession {
    private(set) var phase: CapturePhase = .idle
    var transcript = ""
    var recoveryAmount = ""
    var recoveryTitle = ""

    private let speech: any SpeechListening
    private let island: any IslandDisplaying
    private let interpret: (String) async throws -> [DraftExpense]
    private var task: Task<Void, Never>?
    private var isRecording = false
    private var lastIslandDetail = ""
    private var lastIslandPush = Date.distantPast
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif

    init(
        speech: (any SpeechListening)? = nil,
        island: (any IslandDisplaying)? = nil,
        interpret: ((String) async throws -> [DraftExpense])? = nil
    ) {
        self.speech = speech ?? SpeechCapture()
        self.island = island ?? SystemIsland()
        self.interpret = interpret ?? { try await ExpenseParser.parse($0) }
    }

    var canSaveRecovery: Bool {
        !recoveryAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func toggle(using context: ModelContext) {
        if phase == .listening {
            isRecording = false
            return
        }
        guard task == nil, phase != .analyzing else { return }
        isRecording = true
        recoveryAmount = ""
        recoveryTitle = ""
        task = Task { await runCapture(using: context) }
    }

    func retry(using context: ModelContext) {
        let note = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard task == nil, !note.isEmpty else { return }
        task = Task {
            defer { task = nil }
            await finishAnalysis(of: note, using: context)
        }
    }

    func saveRecovery(using context: ModelContext) {
        guard task == nil else { return }
        let amountText = recoveryAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let spokenTitle = recoveryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let draft = DraftExpense.recovered(amountText: amountText, title: spokenTitle) else {
            phase = .failed(ExpenseStoreError.nothingToSave.localizedDescription)
            return
        }
        task = Task {
            defer { task = nil }
            await finishSaving([draft], using: context)
        }
    }

    func beginFromLaunch(using context: ModelContext) {
        guard phase != .listening, phase != .analyzing else { return }
        toggle(using: context)
    }

    func stopIfListening() {
        guard phase == .listening else { return }
        #if os(iOS)
        if backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "FinFlowSave") { [weak self] in
                Task { @MainActor in
                    self?.endBackgroundTask()
                }
            }
        }
        #endif
        isRecording = false
    }

    func dismiss() {
        guard phase != .listening, phase != .analyzing else { return }
        reset()
    }

    private func runCapture(using context: ModelContext) async {
        defer {
            task = nil
            isRecording = false
            endBackgroundTask()
        }
        phase = .listening
        transcript = ""
        let allowed = await speech.prepareAccess()
        guard allowed else {
            phase = .failed("Microphone and speech recognition stay on this device. Allow both to record an expense.")
            return
        }
        guard isRecording else {
            phase = .idle
            return
        }
        do {
            try await speech.start()
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }
        publishIsland(title: "Listening", detail: "Say the amount and what it was for.", symbol: "waveform", force: true)
        while isRecording, !Task.isCancelled {
            transcript = speech.transcript
            publishIsland(
                title: "Listening",
                detail: transcript.isEmpty ? "Say the amount and what it was for." : transcript,
                symbol: "waveform"
            )
            try? await Task.sleep(for: .milliseconds(120))
        }
        let spoken = await speech.stop()
        transcript = spoken
        guard !spoken.isEmpty else {
            let message = "I didn’t catch that. Tap the mic and say what you spent."
            phase = .failed(message)
            publishIsland(title: "Didn’t catch that", detail: message, symbol: "exclamationmark", ending: true, force: true)
            return
        }
        await finishAnalysis(of: spoken, using: context)
    }

    private func finishAnalysis(of spoken: String, using context: ModelContext) async {
        phase = .analyzing
        publishIsland(title: "Saving", detail: spoken, symbol: "hourglass", force: true)
        do {
            let drafts = try await interpret(spoken)
            guard !drafts.isEmpty else { throw ParserError.nothingRecognized }
            try ExpenseStore.save(drafts, in: context)
            noteSaved(drafts)
            await showDone()
        } catch {
            phase = .failed(error.localizedDescription)
            publishIsland(title: "Needs a look", detail: error.localizedDescription, symbol: "exclamationmark", ending: true, force: true)
        }
    }

    private func finishSaving(_ drafts: [DraftExpense], using context: ModelContext) async {
        do {
            try ExpenseStore.save(drafts, in: context)
            noteSaved(drafts)
            await showDone()
        } catch {
            phase = .failed(error.localizedDescription)
            publishIsland(title: "Needs a look", detail: error.localizedDescription, symbol: "exclamationmark", ending: true, force: true)
        }
    }

    private func noteSaved(_ drafts: [DraftExpense]) {
        let total = drafts.reduce(0) { $0 + $1.amount }
        let name = drafts.count == 1 ? drafts[0].title : "\(drafts.count) expenses"
        publishIsland(
            title: "Saved",
            detail: "\(FinFlowTheme.rupees(total)) · \(name)",
            symbol: "checkmark",
            ending: true,
            force: true
        )
    }

    private func showDone() async {
        phase = .done
        try? await Task.sleep(for: .seconds(1.4))
        if phase == .done { reset() }
    }

    private func reset() {
        phase = .idle
        transcript = ""
        recoveryAmount = ""
        recoveryTitle = ""
        lastIslandDetail = ""
    }

    private func publishIsland(title: String, detail: String, symbol: String, ending: Bool = false, force: Bool = false) {
        let clipped = String(detail.prefix(140))
        let now = Date()
        if !force && !ending {
            guard now.timeIntervalSince(lastIslandPush) >= 0.5, clipped != lastIslandDetail else { return }
        }
        lastIslandDetail = clipped
        lastIslandPush = now
        if ending {
            island.end(title: title, detail: clipped, symbol: symbol)
        } else if island.isRunning {
            island.update(title: title, detail: clipped, symbol: symbol)
        } else {
            island.start(title: title, detail: clipped, symbol: symbol)
        }
    }

    private func endBackgroundTask() {
        #if os(iOS)
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        #endif
    }
}
