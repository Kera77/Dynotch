import AppKit
import SwiftUI

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
    /// Images in black and white, as beside the notch (spec B-12); the settings keep colour.
    var monochrome = true

    var body: some View {
        switch icon {
        case .symbol(let name):
            symbol(name)
        case .custom(let name):
            image(BadgeIconCache.customIcon(named: name))
        case .app:
            if let network = BeeperNetworkBadge.network(fromBadgeID: bundleID) {
                // A highlighted Beeper network: its app's or website's icon, else its symbol (spec BP-14).
                if let icon = BeeperStyle.appIcon(network) { image(icon) } else { symbol(BeeperStyle.network(network).symbol) }
            } else {
                image(BadgeIconCache.appIcon(bundleID: bundleID))
            }
        }
    }

    @ViewBuilder
    private func symbol(_ name: String) -> some View {
        if let glyph = BrandGlyph(rawValue: name) {
            BrandGlyphView(glyph: glyph, size: size, color: tint)
        } else {
            Image(systemName: name)
                .font(.notch(size: size * 0.8, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func image(_ image: NSImage?) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .saturation(monochrome ? 0 : 1)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app.fill")
                .font(.notch(size: size * 0.8))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
    }
}
