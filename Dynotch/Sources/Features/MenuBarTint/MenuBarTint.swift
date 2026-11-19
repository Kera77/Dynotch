import AppKit
import SwiftUI

/// How the menu bar is coloured (spec MB-7, MB-8).
struct MenuBarTintStyle: Codable, Equatable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        case off = "Off"
        case solid = "Solid"
        case gradient = "Gradient"
    }

    enum Direction: String, Codable, CaseIterable, Sendable {
        case horizontal = "Left to right"
        case vertical = "Top to bottom"
    }

    /// Two colours, as hex ("#RRGGBB"); a solid tint uses the first.
    struct Pair: Codable, Equatable, Sendable {
        var start: String
        var end: String
    }

    var kind: Kind = .off
    var direction: Direction = .horizontal
    var light = Pair(start: "#7F5AF0", end: "#2CB1BC")
    var dark = Pair(start: "#3A1C71", end: "#1B6CA8")
    var sameInBoth = true
    /// 0…1.
    var opacity: Double = 0.7

    func pair(dark isDark: Bool) -> Pair { isDark && !sameInBoth ? dark : light }

    /// Ready-made gradients for the settings.
    static let presets: [(name: String, pair: Pair)] = [
        ("Dusk", Pair(start: "#7F5AF0", end: "#2CB1BC")),
        ("Sunset", Pair(start: "#FF6A3D", end: "#C33764")),
        ("Ocean", Pair(start: "#1B6CA8", end: "#20BF9F")),
        ("Forest", Pair(start: "#134E5E", end: "#71B280")),
        ("Graphite", Pair(start: "#232526", end: "#414345"))
    ]
}

/// Hex colours for the tint (pure, tested).
enum TintColor {
    struct RGB: Equatable {
        let red: Double
        let green: Double
        let blue: Double
    }

    static func rgb(_ hex: String) -> RGB? {
        let digits = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return RGB(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }

    static func hex(red: Double, green: Double, blue: Double) -> String {
        let byte = { (value: Double) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    static func color(_ hex: String) -> Color {
        guard let rgb = rgb(hex) else { return .clear }
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    static func hex(of color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "#000000" }
        return hex(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
    }
}

/// Puts a coloured strip behind the menu bar on every display (spec MB-9, MB-10): below the
/// menu bar's own window, above the desktop and the windows; clicks go through.
@MainActor
final class MenuBarTintService: ObservableObject {
    static let shared = MenuBarTintService()
    private static let key = "menuBarTint"

    @Published var style: MenuBarTintStyle {
        didSet {
            if let data = try? JSONEncoder().encode(style) { defaults.set(data, forKey: Self.key) }
            update()
        }
    }

    private let defaults: UserDefaults
    private var windows: [NSWindow] = []
    private var observers: [NSObjectProtocol] = []
    private var isHiddenForMissionControl = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        style = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(MenuBarTintStyle.self, from: $0) }
            ?? MenuBarTintStyle()
    }

    func start() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MenuBarTintService.shared.update() }
        })
        // The menu bar's height changes when it is set to hide by itself.
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceMenuBarHidingChangedNotification"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { MenuBarTintService.shared.update() }
        })
        update()
    }

    /// Mission Control: the strip goes with the notch (spec MB-10).
    func setHiddenForMissionControl(_ hidden: Bool) {
        isHiddenForMissionControl = hidden
        windows.forEach { $0.alphaValue = hidden ? 0 : 1 }
    }

    /// The menu bar's frame on a display, nil when it hides by itself.
    nonisolated static func menuBarFrame(screen: CGRect, visible: CGRect) -> CGRect? {
        let height = screen.maxY - visible.maxY
        guard height > 10, height < 80 else { return nil }
        return CGRect(x: screen.minX, y: screen.maxY - height, width: screen.width, height: height)
    }

    private func update() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        guard style.kind != .off else { return }
        for screen in NSScreen.screens {
            guard let frame = Self.menuBarFrame(screen: screen.frame, visible: screen.visibleFrame) else { continue }
            windows.append(makeWindow(frame: frame))
        }
    }

    private func makeWindow(frame: CGRect) -> NSWindow {
        let window = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        // Just under the menu bar's own window: its titles and icons stay on top.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
        // Every Space, but not a full-screen app's (spec MB-10).
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MenuBarTintView(service: self))
        window.alphaValue = isHiddenForMissionControl ? 0 : 1
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
        return window
    }
}

/// The strip's colour, following light and dark mode (spec MB-8).
struct MenuBarTintView: View {
    @ObservedObject var service: MenuBarTintService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = service.style
        let pair = style.pair(dark: colorScheme == .dark)
        let end: Color = TintColor.color(style.kind == .gradient ? pair.end : pair.start)
        let vertical = style.direction == .vertical
        LinearGradient(
            colors: [TintColor.color(pair.start), end],
            startPoint: vertical ? .top : .leading, endPoint: vertical ? .bottom : .trailing
        )
        .opacity(style.opacity)
        .animation(.easeInOut(duration: 0.3), value: colorScheme)
        .animation(.easeInOut(duration: 0.3), value: style)
        .ignoresSafeArea()
    }
}
