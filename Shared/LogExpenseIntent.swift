import AppIntents
import Foundation

nonisolated struct LogExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log an expense"
    static let description = IntentDescription("Opens FinFlow and starts listening for an expense.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        CaptureLaunch.request()
        await MainActor.run {
            NotificationCenter.default.post(name: CaptureLaunch.notification, object: nil)
        }
        return .result()
    }
}
