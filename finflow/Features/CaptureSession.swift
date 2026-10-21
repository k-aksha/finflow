import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CaptureSession {
    private(set) var phase: CapturePhase = .idle
    var transcript = ""
    var recoveryAmount = ""
    var recoveryTitle = ""

    private let capture = SpeechCapture()
    private var task: Task<Void, Never>?
    private var isRecording = false

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

    func dismiss() {
        guard phase != .listening, phase != .analyzing else { return }
        reset()
    }

    private func runCapture(using context: ModelContext) async {
        defer {
            task = nil
            isRecording = false
        }
        phase = .listening
        transcript = ""
        let allowed = await capture.prepareAccess()
        guard allowed else {
            phase = .failed("Microphone and speech recognition stay on this device. Allow both to record an expense.")
            return
        }
        guard isRecording else {
            phase = .idle
            return
        }
        do {
            try await capture.start()
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }
        while isRecording, !Task.isCancelled {
            transcript = capture.transcript
            try? await Task.sleep(for: .milliseconds(120))
        }
        let spoken = await capture.stop()
        transcript = spoken
        guard !spoken.isEmpty else {
            phase = .failed("I didn’t catch that. Tap the mic and say what you spent.")
            return
        }
        await finishAnalysis(of: spoken, using: context)
    }

    private func finishAnalysis(of spoken: String, using context: ModelContext) async {
        phase = .analyzing
        do {
            let drafts = try await ExpenseParser.parse(spoken)
            guard !drafts.isEmpty else { throw ParserError.nothingRecognized }
            try ExpenseStore.save(drafts, in: context)
            await showDone()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func finishSaving(_ drafts: [DraftExpense], using context: ModelContext) async {
        do {
            try ExpenseStore.save(drafts, in: context)
            await showDone()
        } catch {
            phase = .failed(error.localizedDescription)
        }
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
    }
}
