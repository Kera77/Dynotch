import AppKit
import ImageIO

/// How bright each display's wallpaper is, so the refined liquid glass is darkened more over a
/// light background and less over a dark one (spec D-14c).
@MainActor
final class WallpaperTone: ObservableObject {
    static let shared = WallpaperTone()

    /// Average brightness (0…1) by screen frame.
    @Published private(set) var brightness: [String: Double] = [:]
    private var cache: [URL: Double] = [:]
    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { WallpaperTone.shared.refresh() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { WallpaperTone.shared.refresh() }
        })
        refresh()
    }

    static func key(_ frame: CGRect) -> String { "\(frame.origin.x),\(frame.origin.y),\(frame.width)" }

    /// The glass tint's opacity for a display: 0.32 over a dark wallpaper, up to 0.55 over a light one.
    func tint(for screenFrame: CGRect) -> Double {
        let value = brightness[Self.key(screenFrame)] ?? 0.5
        return 0.32 + 0.23 * min(max((value - 0.2) / 0.6, 0), 1)
    }

    func refresh() {
        var next: [String: Double] = [:]
        for screen in NSScreen.screens {
            guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { continue }
            if let known = cache[url] {
                next[Self.key(screen.frame)] = known
            } else if let value = Self.averageBrightness(url) {
                cache[url] = value
                next[Self.key(screen.frame)] = value
            }
        }
        if next != brightness { brightness = next }
    }

    /// The image shrunk to one pixel: its luminance.
    nonisolated static func averageBrightness(_ url: URL) -> Double? {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 32] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])) / 255
    }
}
