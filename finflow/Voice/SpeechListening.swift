import Foundation

@MainActor
protocol SpeechListening: AnyObject {
    var transcript: String { get }
    func prepareAccess() async -> Bool
    func start() async throws
    func stop() async -> String
}

extension SpeechCapture: SpeechListening {}
