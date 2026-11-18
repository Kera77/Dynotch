import AppKit
import AVFoundation
import ScreenCaptureKit

/// Records the display under the pointer into the Screenshots folder (spec SH-5), with the Mac's
/// sound and the microphone when switched on. Dynotch itself is left out of the video.
@MainActor
final class ScreenRecorder: NSObject {
    private var stream: SCStream?
    private var output: AnyObject?
    private(set) var url: URL?
    private var finished: CheckedContinuation<Void, Never>?

    var isRecording: Bool { stream != nil }

    /// - Returns: false if it could not start.
    func start(on screen: NSScreen, systemAudio: Bool, microphone: Bool) async -> Bool {
        guard #available(macOS 15.0, *) else {
            DiagnosticsLog.append("screenshots", "recording needs macOS 15")
            return false
        }
        guard let (filter, display) = await ScreenCapture.displayFilter(for: screen) else { return false }
        let configuration = SCStreamConfiguration()
        configuration.width = Int(CGFloat(display.width) * screen.backingScaleFactor)
        configuration.height = Int(CGFloat(display.height) * screen.backingScaleFactor)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.showsCursor = true
        configuration.capturesAudio = systemAudio
        configuration.excludesCurrentProcessAudio = true
        configuration.captureMicrophone = microphone
        let target = ScreenshotFiles.newURL(prefix: "Screen Recording", ext: "mov")
        let recording = SCRecordingOutputConfiguration()
        recording.outputURL = target
        recording.outputFileType = .mov
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        let output = SCRecordingOutput(configuration: recording, delegate: self)
        do {
            try stream.addRecordingOutput(output)
            try await stream.startCapture()
        } catch {
            DiagnosticsLog.append("screenshots", "recording did not start: \(error.localizedDescription)")
            return false
        }
        self.stream = stream
        self.output = output
        url = target
        return true
    }

    /// Stops and waits until the file is written.
    func stop() async -> URL? {
        guard let stream else { return nil }
        self.stream = nil
        await withCheckedContinuation { continuation in
            finished = continuation
            Task {
                try? await stream.stopCapture()
                // The delegate says when the file is complete; don't wait forever.
                try? await Task.sleep(for: .seconds(3))
                self.resumeFinished()
            }
        }
        output = nil
        return url
    }

    fileprivate func resumeFinished() {
        finished?.resume()
        finished = nil
    }
}

@available(macOS 15.0, *)
extension ScreenRecorder: SCRecordingOutputDelegate {
    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.resumeFinished() }
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        DiagnosticsLog.append("screenshots", "recording failed: \(error.localizedDescription)")
        Task { @MainActor in self.resumeFinished() }
    }
}
