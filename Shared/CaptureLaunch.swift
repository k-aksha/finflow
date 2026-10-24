import Foundation

nonisolated enum CaptureLaunch {
    static let notification = Notification.Name("in.akshaux.finflow.startCapture")
    private static let key = "startCaptureOnLaunch"

    static var isPending: Bool {
        defaults?.bool(forKey: key) ?? false
    }

    static func request() {
        defaults?.set(true, forKey: key)
    }

    static func take() -> Bool {
        guard defaults?.bool(forKey: key) == true else { return false }
        defaults?.set(false, forKey: key)
        return true
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: FinFlowStore.groupID)
    }
}
