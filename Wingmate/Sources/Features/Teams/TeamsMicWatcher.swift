import AVFoundation
import Foundation

/// While Teams is muted, listens to the microphone's level only (nothing is recorded or kept):
/// about a second of speech calls `onSpeech` (spec MT-8).
@MainActor
final class TeamsMicWatcher {
    var onSpeech: () -> Void = {}

    private var engine: AVAudioEngine?
    private var loudSince: Date?

    /// Speech level in dBFS, and how long it has to last.
    nonisolated static let threshold: Float = -38
    nonisolated static let duration: TimeInterval = 0.9

    func setWatching(_ watching: Bool) {
        if watching, engine == nil {
            start()
        } else if !watching, engine != nil {
            stop()
        }
    }

    private func start() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { @Sendable granted in
                guard granted else { return }
                Task { @MainActor in TeamsService.shared.refresh() }
            }
            return
        default: return
        }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { @Sendable buffer, _ in
            let level = Self.level(of: buffer)
            Task { @MainActor [weak self] in self?.heard(level) }
        }
        do {
            try engine.start()
            self.engine = engine
        } catch {
            input.removeTap(onBus: 0)
            TeamsLog.write("mic watch failed")
        }
    }

    private func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        loudSince = nil
    }

    private func heard(_ level: Float) {
        guard engine != nil else { return }
        guard level > Self.threshold else {
            loudSince = nil
            return
        }
        let since = loudSince ?? Date()
        loudSince = since
        if Date().timeIntervalSince(since) >= Self.duration {
            loudSince = nil
            onSpeech()
        }
    }

    /// The buffer's loudness (RMS) in dBFS.
    nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return -160 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count { sum += samples[index] * samples[index] }
        let rms = (sum / Float(count)).squareRoot()
        return rms > 0 ? 20 * log10(rms) : -160
    }
}
