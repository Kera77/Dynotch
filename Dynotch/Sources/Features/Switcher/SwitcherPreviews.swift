import AppKit
import ScreenCaptureKit

/// Window previews for the Thumbnails view (spec AS-7). Only when switched on: they need Screen
/// Recording, and macOS shows its sharing indicator while capturing.
enum SwitcherPreviews {
    /// Whether Screen Recording was granted; never asks.
    static var isAllowed: Bool { CGPreflightScreenCaptureAccess() }

    /// Asks for Screen Recording (the system's prompt, once).
    static func requestAccess() {
        _ = CGRequestScreenCaptureAccess()
    }

    /// Small images of the windows, by window id; empty without permission.
    static func capture(_ items: [SwitcherItem]) async -> [CGWindowID: NSImage] {
        guard isAllowed, let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        else { return [:] }
        let wanted = Set(items.map(\.windowID))
        var result: [CGWindowID: NSImage] = [:]
        for window in content.windows where wanted.contains(window.windowID) {
            let configuration = SCStreamConfiguration()
            let scale = min(1, 480 / max(window.frame.width, 1))
            configuration.width = max(Int(window.frame.width * scale), 1)
            configuration.height = max(Int(window.frame.height * scale), 1)
            configuration.showsCursor = false
            let filter = SCContentFilter(desktopIndependentWindow: window)
            guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            else { continue }
            result[window.windowID] = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }
        return result
    }
}
