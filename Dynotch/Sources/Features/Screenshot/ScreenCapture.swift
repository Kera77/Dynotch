import AppKit
import ScreenCaptureKit

/// Takes the pictures with ScreenCaptureKit, leaving Dynotch's own windows out (spec SH-3).
@MainActor
enum ScreenCapture {
    static var isAllowed: Bool { CGPreflightScreenCaptureAccess() }

    static func requestAccess() {
        _ = CGRequestScreenCaptureAccess()
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// The display under a point (AppKit coordinates), or the main one.
    static func screen(at point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    /// A part of a display: `rect` in AppKit global coordinates, within `screen`.
    static func capture(_ rect: CGRect, on screen: NSScreen) async -> CGImage? {
        guard let (filter, _) = await displayFilter(for: screen) else { return nil }
        let frame = screen.frame
        let scale = screen.backingScaleFactor
        // The whole display in its own pixels, then the part cut out on whole pixels: asking
        // ScreenCaptureKit for the part resamples it and blurs the text (spec SH-3d).
        let configuration = SCStreamConfiguration()
        configuration.width = max(Int((frame.width * scale).rounded()), 1)
        configuration.height = max(Int((frame.height * scale).rounded()), 1)
        configuration.showsCursor = false
        configuration.captureResolution = .best
        configuration.scalesToFit = false
        guard let full = await image(filter, configuration) else { return nil }
        let local = CGRect(x: rect.minX - frame.minX, y: frame.maxY - rect.maxY, width: rect.width, height: rect.height)
        return crop(full, to: local, scale: scale)
    }

    /// `rect` (display points from the top left) cut out of a whole-display image on whole pixels.
    nonisolated static func crop(_ image: CGImage, to rect: CGRect, scale: CGFloat) -> CGImage? {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let pixels = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
        let snapped = CGRect(
            x: pixels.minX.rounded(), y: pixels.minY.rounded(),
            width: max(pixels.width.rounded(), 1), height: max(pixels.height.rounded(), 1)
        ).intersection(bounds)
        guard !snapped.isNull, snapped.width >= 1, snapped.height >= 1 else { return nil }
        if snapped == bounds { return image }
        // Copied pixel for pixel, so the part does not keep the whole display's buffer alive.
        guard let part = image.cropping(to: snapped),
              let context = CGContext(
                  data: nil, width: part.width, height: part.height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else { return image.cropping(to: snapped) }
        context.interpolationQuality = .none
        context.draw(part, in: CGRect(x: 0, y: 0, width: part.width, height: part.height))
        return context.makeImage()
    }

    static func captureScreen(_ screen: NSScreen) async -> CGImage? {
        await capture(screen.frame, on: screen)
    }

    /// One window, without the desktop behind it.
    static func captureWindow(_ windowID: CGWindowID) async -> CGImage? {
        guard let content = await shareable(),
              let window = content.windows.first(where: { $0.windowID == windowID })
        else { return nil }
        let scale = NSScreen.screens.first { $0.frame.intersects(window.frame) }?.backingScaleFactor ?? 2
        let configuration = SCStreamConfiguration()
        configuration.width = max(Int(window.frame.width * scale), 1)
        configuration.height = max(Int(window.frame.height * scale), 1)
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.captureResolution = .best
        return await image(SCContentFilter(desktopIndependentWindow: window), configuration)
    }

    /// The whole display minus Dynotch, and the display itself.
    static func displayFilter(for screen: NSScreen) async -> (SCContentFilter, SCDisplay)? {
        guard let content = await shareable(), let id = displayID(of: screen),
              let display = content.displays.first(where: { $0.displayID == id })
        else { return nil }
        let own = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        return (SCContentFilter(display: display, excludingApplications: own, exceptingWindows: []), display)
    }

    private static func shareable() async -> SCShareableContent? {
        do {
            return try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            DiagnosticsLog.append("screenshots", "no shareable content: \(error.localizedDescription)")
            return nil
        }
    }

    private static func image(_ filter: SCContentFilter, _ configuration: SCStreamConfiguration) async -> CGImage? {
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            DiagnosticsLog.append("screenshots", "capture failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// The topmost normal window under a point (AppKit coordinates), not Dynotch's (spec SH-2).
    static func window(at point: CGPoint) -> (id: CGWindowID, frame: CGRect)? {
        guard let primary = NSScreen.screens.first,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        let own = ProcessInfo.processInfo.processIdentifier
        for info in list {
            guard info[kCGWindowLayer as String] as? Int == 0, info[kCGWindowOwnerPID as String] as? pid_t != own,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let id = info[kCGWindowNumber as String] as? CGWindowID
            else { continue }
            // Window bounds are from the top left of the main display.
            let width = bounds["Width"] ?? 0, height = bounds["Height"] ?? 0
            let frame = CGRect(x: bounds["X"] ?? 0, y: primary.frame.maxY - (bounds["Y"] ?? 0) - height, width: width, height: height)
            if frame.contains(point), width > 40, height > 40 { return (id, frame) }
        }
        return nil
    }
}
