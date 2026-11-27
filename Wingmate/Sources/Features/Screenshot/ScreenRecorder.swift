import AppKit
import AVFoundation
import ScreenCaptureKit

/// Records the display under the pointer, or only an area of it, into the Screenshots folder
/// (spec SH-5, SH-13), with the Mac's sound and the microphone when switched on. Wingmate itself
/// is left out of the video.
@MainActor
final class ScreenRecorder: NSObject {
    private var stream: SCStream?
    private var output: AnyObject?
    private(set) var url: URL?
    private var finished: CheckedContinuation<Void, Never>?

    var isRecording: Bool { stream != nil }

    /// - Returns: false if it could not start.
    /// - Parameter area: in global screen points (AppKit); nil: the whole display.
    func start(on screen: NSScreen, area: CGRect? = nil, systemAudio: Bool, microphone: Bool) async -> Bool {
        guard #available(macOS 15.0, *) else {
            DiagnosticsLog.append("screenshots", "recording needs macOS 15")
            return false
        }
        guard let (filter, display) = await ScreenCapture.displayFilter(for: screen) else { return false }
        let configuration = SCStreamConfiguration()
        let scale = screen.backingScaleFactor
        if let area, let source = Self.sourceRect(area, screen: screen.frame, scale: scale) {
            // Only the area, in the display's own pixels, nothing scaled (spec SH-13, SH-3d).
            configuration.sourceRect = source
            configuration.width = Int((source.width * scale).rounded())
            configuration.height = Int((source.height * scale).rounded())
        } else {
            configuration.width = Int(CGFloat(display.width) * scale)
            configuration.height = Int(CGFloat(display.height) * scale)
        }
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

    /// The area in the display's top-left points, on whole pixels, with an even pixel size
    /// (video encoders want one); nil when too small.
    nonisolated static func sourceRect(_ area: CGRect, screen: CGRect, scale: CGFloat) -> CGRect? {
        let local = area.intersection(screen).offsetBy(dx: -screen.minX, dy: -screen.minY)
        guard !local.isNull else { return nil }
        let top = screen.height - local.maxY
        let minX = (local.minX * scale).rounded(.down), minY = (top * scale).rounded(.down)
        var width = (local.maxX * scale).rounded(.up) - minX
        var height = ((top + local.height) * scale).rounded(.up) - minY
        width -= width.truncatingRemainder(dividingBy: 2)
        height -= height.truncatingRemainder(dividingBy: 2)
        guard width >= 16, height >= 16 else { return nil }
        return CGRect(x: minX / scale, y: minY / scale, width: width / scale, height: height / scale)
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
