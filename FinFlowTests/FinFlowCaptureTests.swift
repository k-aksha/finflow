import SwiftData
import XCTest
@testable import finflow

@MainActor
final class FinFlowCaptureTests: XCTestCase {
    func testSpokenExpenseOpensTheIslandThenSaves() async throws {
        let island = IslandRecorder()
        let session = CaptureSession(
            speech: ScriptedSpeech(spoken: "five hundred rupees for coffee"),
            island: island,
            interpret: { LocalExpenseParser.parse($0) }
        )
        let container = try ModelContainer(
            for: Expense.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        session.toggle(using: context)
        try await waitUntil { island.events.contains { $0.title == "Listening" } }
        XCTAssertEqual(session.phase, .listening)

        session.toggle(using: context)
        try await waitUntil {
            let rows = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
            return rows.count == 1
        }

        let saved = try XCTUnwrap((try context.fetch(FetchDescriptor<Expense>())).first)
        XCTAssertEqual(saved.amount, 500)
        XCTAssertEqual(saved.title, "Coffee")
        XCTAssertEqual(saved.category, "Food & drink")
        XCTAssertTrue(island.events.contains { $0.action == "end" && $0.title == "Saved" && $0.detail.contains("Coffee") })
    }

    func testSilenceClosesTheIslandWithoutSaving() async throws {
        let island = IslandRecorder()
        let session = CaptureSession(
            speech: ScriptedSpeech(spoken: ""),
            island: island,
            interpret: { LocalExpenseParser.parse($0) }
        )
        let container = try ModelContainer(
            for: Expense.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        session.toggle(using: context)
        try await waitUntil { island.events.contains { $0.title == "Listening" } }
        session.toggle(using: context)
        try await waitUntil {
            if case .failed = session.phase { return true }
            return false
        }

        let rows = try context.fetch(FetchDescriptor<Expense>())
        XCTAssertTrue(rows.isEmpty)
        XCTAssertTrue(island.events.contains { $0.action == "end" && $0.title == "Didn’t catch that" })
    }

    func testDeniedMicrophoneNeverOpensTheIsland() async throws {
        let island = IslandRecorder()
        let speech = ScriptedSpeech(spoken: "five hundred for coffee")
        speech.allowsAccess = false
        let session = CaptureSession(
            speech: speech,
            island: island,
            interpret: { LocalExpenseParser.parse($0) }
        )
        let container = try ModelContainer(
            for: Expense.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        session.toggle(using: ModelContext(container))
        try await waitUntil {
            if case .failed = session.phase { return true }
            return false
        }
        XCTAssertTrue(island.events.isEmpty)
    }

    func testLiveActivityCanOpenWhileListening() throws {
        #if os(iOS)
        IslandActivity.end(title: "Clear", detail: "Clear", symbol: "xmark")
        IslandActivity.start(title: "Listening", detail: "Say the amount and what it was for.", symbol: "waveform")
        try XCTSkipUnless(IslandActivity.isRunning, "Live Activities are turned off on this device")
        IslandActivity.end(title: "Saved", detail: "₹500.00 · Coffee", symbol: "checkmark")
        XCTAssertFalse(IslandActivity.isRunning)
        #else
        throw XCTSkip("Dynamic Island is the iPhone listening view")
        #endif
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        let start = Date()
        while !condition() {
            if Date().timeIntervalSince(start) > 5 {
                XCTFail("Timed out waiting for capture")
                return
            }
            try await Task.sleep(for: .milliseconds(40))
        }
    }
}

@MainActor
private final class ScriptedSpeech: SpeechListening {
    var transcript: String
    var allowsAccess = true

    init(spoken: String) {
        transcript = spoken
    }

    func prepareAccess() async -> Bool { allowsAccess }
    func start() async throws {}
    func stop() async -> String { transcript }
}

@MainActor
private final class IslandRecorder: IslandDisplaying {
    struct Event: Equatable {
        var action: String
        var title: String
        var detail: String
    }

    var events: [Event] = []
    private(set) var isRunning = false

    func start(title: String, detail: String, symbol: String) {
        isRunning = true
        events.append(Event(action: "start", title: title, detail: detail))
    }

    func update(title: String, detail: String, symbol: String) {
        events.append(Event(action: "update", title: title, detail: detail))
    }

    func end(title: String, detail: String, symbol: String) {
        isRunning = false
        events.append(Event(action: "end", title: title, detail: detail))
    }
}
