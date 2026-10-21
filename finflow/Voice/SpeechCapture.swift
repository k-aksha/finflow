import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechCapture {
    private(set) var transcript = ""
    private var accumulated = AttributedString()
    private var volatileTail = AttributedString()
    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private let bridge = AudioBridge()

    func prepareAccess() async -> Bool {
        let microphone = await Self.requestMicrophone()
        guard microphone else { return false }
        let speech = await Self.requestSpeech()
        return speech == .authorized
    }

    func start() async throws {
        transcript = ""
        accumulated = AttributedString()
        volatileTail = AttributedString()
        let locale = await preferredLocale()
        let presets: [SpeechTranscriber.Preset] = [
            .timeIndexedProgressiveTranscription,
            .progressiveTranscription
        ]
        var lastError: Error?
        for preset in presets {
            do {
                try await begin(locale: locale, preset: preset)
                return
            } catch {
                await abortStart()
                lastError = error
            }
        }
        throw Self.readable(lastError)
    }

    private func begin(locale: Locale, preset: SpeechTranscriber.Preset) async throws {
        let transcriber = SpeechTranscriber(locale: locale, preset: preset)
        self.transcriber = transcriber
        let status = await AssetInventory.status(forModules: [transcriber])
        if status == .unsupported {
            throw SpeechCaptureError.speechUnavailable
        }

        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation
        bridge.continuation = continuation
        bridge.converter = try await AnalyzerInputConverter.converter(compatibleWith: [transcriber])

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    await MainActor.run {
                        self?.incorporate(result)
                    }
                }
            } catch {
                return
            }
        }

        try await configureSession()
        let audioEngine = AVAudioEngine()
        let input = audioEngine.inputNode
        let hardwareFormat = input.outputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            throw SpeechCaptureError.speechUnavailable
        }
        let analysisFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: hardwareFormat
        ) ?? hardwareFormat
        let bridge = self.bridge
        try input.installAudioTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { buffer, time in
            bridge.consume(AVAudioPCMBuffer(copying: buffer), at: time)
        }
        audioEngine.prepare()
        try audioEngine.start()
        engine = audioEngine

        try await analyzer.prepareToAnalyze(in: analysisFormat)
        let started = analyzer
        analysisTask = Task {
            try? await started.start(inputSequence: stream)
        }
    }

    private static func readable(_ error: Error?) -> Error {
        guard let error else { return SpeechCaptureError.speechUnavailable }
        if error.localizedDescription.localizedCaseInsensitiveContains("unsupported configuration") {
            return SpeechCaptureError.speechUnavailable
        }
        return error
    }

    private func abortStart() async {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        inputContinuation?.finish()
        inputContinuation = nil
        bridge.continuation = nil
        resultsTask?.cancel()
        analysisTask?.cancel()
        resultsTask = nil
        analysisTask = nil
        analyzer = nil
        transcriber = nil
        await deactivateSession()
    }

    func stop() async -> String {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        inputContinuation?.finish()
        inputContinuation = nil
        bridge.continuation = nil

        await finish(analysisTask, within: .seconds(1))
        if let analyzer {
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        await finish(resultsTask, within: .seconds(2))
        analysisTask = nil
        resultsTask = nil
        analyzer = nil
        transcriber = nil
        await deactivateSession()
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Each recognition result covers only its own slice of audio. Replacing the whole note dropped every earlier expense before save.
    private func incorporate(_ result: SpeechTranscriber.Result) {
        let timed = result.text.runs.contains { $0.audioTimeRange != nil }
        if timed {
            if let overlap = accumulated.rangeOfAudioTimeRangeAttributes(intersecting: result.range) {
                accumulated.replaceSubrange(overlap, with: result.text)
            } else {
                appendSeparatePhrase(result.text)
            }
            volatileTail = AttributedString()
        } else if result.isFinal {
            appendSeparatePhrase(result.text)
            volatileTail = AttributedString()
        } else {
            volatileTail = result.text
        }
        publishTranscript()
    }

    private func publishTranscript() {
        var combined = accumulated
        if !volatileTail.characters.isEmpty {
            if let last = combined.characters.last, let first = volatileTail.characters.first,
               !last.isWhitespace, !first.isWhitespace {
                combined.append(AttributedString(" "))
            }
            combined.append(volatileTail)
        }
        transcript = String(combined.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendSeparatePhrase(_ phrase: AttributedString) {
        guard !phrase.characters.isEmpty else { return }
        if let last = accumulated.characters.last, let first = phrase.characters.first,
           !last.isWhitespace, !first.isWhitespace {
            accumulated.append(AttributedString(" "))
        }
        accumulated.append(phrase)
    }

    private func finish(_ task: Task<Void, Never>?, within duration: Duration) async {
        guard let task else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await task.value }
            group.addTask { try? await Task.sleep(for: duration) }
            await group.next()
            group.cancelAll()
        }
    }

    private func preferredLocale() async -> Locale {
        if let indian = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_IN")) {
            return indian
        }
        if let current = await SpeechTranscriber.supportedLocale(equivalentTo: .current) {
            return current
        }
        return Locale(identifier: "en_US")
    }

    private func configureSession() async throws {
        #if os(iOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.activate(options: []) { activated, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if activated {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AudioSessionError.notActivated)
                }
            }
        }
        #endif
    }

    private func deactivateSession() async {
        #if os(iOS) || os(visionOS)
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation) { _, _ in
                continuation.resume()
            }
        }
        #endif
    }

    private static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func requestSpeech() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

private enum AudioSessionError: Error {
    case notActivated
}

private enum SpeechCaptureError: LocalizedError {
    case speechUnavailable

    var errorDescription: String? {
        "On-device speech isn’t available in the simulator. Type the amount below, or run FinFlow on your iPhone."
    }
}

nonisolated final class AudioBridge: @unchecked Sendable {
    var continuation: AsyncStream<AnalyzerInput>.Continuation?
    var converter: AnalyzerInputConverter?

    func consume(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard let converter, let continuation else { return }
        guard let inputs = try? converter.convert(buffer, at: time) else { return }
        for input in inputs {
            continuation.yield(input)
        }
    }
}
