import Foundation
#if os(iOS)
import ActivityKit

nonisolated struct CaptureActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var title: String
        var detail: String
        var symbol: String
    }

    var startedAt: Date
}
#endif
