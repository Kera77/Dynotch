import AppKit
import SwiftUI

/// Claude's burst, drawn as rays so it can take any colour (spec CL-6, B-3).
struct ClaudeGlyph: Shape {
    private static let rays = 10

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for ray in 0..<Self.rays {
            let angle = Double(ray) / Double(Self.rays) * 2 * .pi - .pi / 2
            let length = radius * (ray.isMultiple(of: 2) ? 1 : 0.84)
            path.move(to: CGPoint(x: center.x + cos(angle) * radius * 0.2, y: center.y + sin(angle) * radius * 0.2))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length))
        }
        return path
    }
}

/// The burst in one colour at the given size.
struct ClaudeGlyphView: View {
    var size: CGFloat = 16
    var color: Color = .white

    var body: some View {
        ClaudeGlyph()
            .stroke(color, style: StrokeStyle(lineWidth: max(size * 0.11, 1.4), lineCap: .round))
            .padding(size * 0.06)
            .frame(width: size, height: size)
    }
}

@MainActor
enum BadgeIconCache {
    private static var appIcons: [String: NSImage] = [:]
    private static var customIcons: [String: NSImage] = [:]

    static func appIcon(bundleID: String) -> NSImage? {
        if let icon = appIcons[bundleID] { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        appIcons[bundleID] = icon
        return icon
    }

    static func customIcon(named name: String) -> NSImage? {
        if let icon = customIcons[name] { return icon }
        guard let icon = NSImage(contentsOf: BadgeService.iconFolder.appendingPathComponent(name)) else { return nil }
        customIcons[name] = icon
        return icon
    }
}

/// An app's badge icon: its own icon, a glyph, or the user's image (spec B-3).
struct BadgeIconView: View {
    let icon: BadgeIcon
    let bundleID: String
    var size: CGFloat = BadgeItem.iconSize
    /// Colour of the glyphs.
    var tint: Color = .white

    var body: some View {
        switch icon {
        case .symbol(BadgePreset.claudeSymbol):
            ClaudeGlyphView(size: size, color: tint)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.8, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        case .custom(let name):
            image(BadgeIconCache.customIcon(named: name))
        case .app:
            image(BadgeIconCache.appIcon(bundleID: bundleID))
        }
    }

    @ViewBuilder
    private func image(_ image: NSImage?) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: size * 0.8))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
    }
}
