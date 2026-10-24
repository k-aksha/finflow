import Foundation
#if os(iOS)
import ActivityKit

@MainActor
enum IslandActivity {
    private static var current: Activity<CaptureActivityAttributes>?

    static var isRunning: Bool { current != nil }

    static func start(title: String, detail: String, symbol: String) {
        guard current == nil else {
            update(title: title, detail: detail, symbol: symbol)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = CaptureActivityAttributes(startedAt: .now)
        let content = ActivityContent(
            state: CaptureActivityAttributes.ContentState(title: title, detail: detail, symbol: symbol),
            staleDate: nil
        )
        current = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    static func update(title: String, detail: String, symbol: String) {
        guard let current else {
            start(title: title, detail: detail, symbol: symbol)
            return
        }
        let content = ActivityContent(
            state: CaptureActivityAttributes.ContentState(title: title, detail: detail, symbol: symbol),
            staleDate: nil
        )
        Task { await current.update(content) }
    }

    static func end(title: String, detail: String, symbol: String) {
        guard let activity = current else { return }
        current = nil
        let content = ActivityContent(
            state: CaptureActivityAttributes.ContentState(title: title, detail: detail, symbol: symbol),
            staleDate: nil
        )
        Task {
            await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(4)))
        }
    }
}
#else
@MainActor
enum IslandActivity {
    static var isRunning: Bool { false }
    static func start(title: String, detail: String, symbol: String) {}
    static func update(title: String, detail: String, symbol: String) {}
    static func end(title: String, detail: String, symbol: String) {}
}
#endif

@MainActor
protocol IslandDisplaying: AnyObject {
    var isRunning: Bool { get }
    func start(title: String, detail: String, symbol: String)
    func update(title: String, detail: String, symbol: String)
    func end(title: String, detail: String, symbol: String)
}

@MainActor
final class SystemIsland: IslandDisplaying {
    var isRunning: Bool { IslandActivity.isRunning }

    func start(title: String, detail: String, symbol: String) {
        IslandActivity.start(title: title, detail: detail, symbol: symbol)
    }

    func update(title: String, detail: String, symbol: String) {
        IslandActivity.update(title: title, detail: detail, symbol: symbol)
    }

    func end(title: String, detail: String, symbol: String) {
        IslandActivity.end(title: title, detail: detail, symbol: symbol)
    }
}
