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
    /// 0.1…0.8: the menu bar's titles and icons show through the tint (spec MB-9).
    var opacity: Double = 0.5

    static let opacityRange = 0.1...0.8

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

/// Tints the menu bar on every display (spec MB-9, MB-10). With the menu bar's own background
/// on (the default), nothing behind the menu bar shows, so the tint lies over it, see-through,
/// so its titles and icons show and clicks go through; the notch's place stays black.
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

    /// The menu bar's frame on a display, nil when it hides by itself. `drawn` is the height of
    /// the menu bar's own window, when the window server lists it (a point less than the room
    /// left above the visible frame on displays with a notch).
    nonisolated static func menuBarFrame(screen: CGRect, visible: CGRect, drawn: CGFloat? = nil) -> CGRect? {
        let room = screen.maxY - visible.maxY
        guard room > 10, room < 80 else { return nil }
        let height = drawn.map { min($0, room) } ?? room
        return CGRect(x: screen.minX, y: screen.maxY - height, width: screen.width, height: height)
    }

    /// Heights of the menu bar windows by their left edge.
    nonisolated private static func drawnMenuBars() -> [CGFloat: CGFloat] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        var heights: [CGFloat: CGFloat] = [:]
        for window in info where (window[kCGWindowName as String] as? String) == "Menubar" {
            guard let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { continue }
            heights[rect.minX] = rect.height
        }
        return heights
    }

    /// The notch's place, left to right in the strip's own coordinates (spec MB-9: it stays black).
    nonisolated static func notchGap(screenWidth: CGFloat, left: CGRect?, right: CGRect?, screenMinX: CGFloat) -> ClosedRange<CGFloat>? {
        guard let left, let right, right.minX > left.maxX else { return nil }
        let start = left.maxX - screenMinX
        let end = right.minX - screenMinX
        guard start >= 0, end <= screenWidth else { return nil }
        return start...end
    }

    private func update() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        guard style.kind != .off else { return }
        let drawn = Self.drawnMenuBars()
        for screen in NSScreen.screens {
            guard let frame = Self.menuBarFrame(screen: screen.frame, visible: screen.visibleFrame, drawn: drawn[screen.frame.minX])
            else { continue }
            let gap = Self.notchGap(
                screenWidth: frame.width, left: screen.auxiliaryTopLeftArea, right: screen.auxiliaryTopRightArea,
                screenMinX: screen.frame.minX
            )
            windows.append(makeWindow(frame: frame, gap: gap))
        }
    }

    private func makeWindow(frame: CGRect, gap: ClosedRange<CGFloat>?) -> NSWindow {
        let window = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        // Over the menu bar (its own background hides anything behind it), under its menus and
        // under the notch's panel.
        window.level = .statusBar
        // Every Space, but not a full-screen app's (spec MB-10).
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MenuBarTintView(service: self, gap: gap))
        window.sharingType = .readOnly
        window.alphaValue = isHiddenForMissionControl ? 0 : 1
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
        return window
    }
}

/// The strip's colour, following light and dark mode (spec MB-8).
struct MenuBarTintView: View {
    @ObservedObject var service: MenuBarTintService
    /// The notch's place, left clear (spec MB-9).
    var gap: ClosedRange<CGFloat>?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        tint.mask {
            GeometryReader { proxy in
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    if let gap {
                        path.addRect(CGRect(x: gap.lowerBound, y: 0, width: gap.upperBound - gap.lowerBound, height: proxy.size.height))
                    }
                }
                .fill(style: FillStyle(eoFill: true))
            }
        }
    }

    private var tint: some View {
        let style = service.style
        let pair = style.pair(dark: colorScheme == .dark)
        let end: Color = TintColor.color(style.kind == .gradient ? pair.end : pair.start)
        let vertical = style.direction == .vertical
        return LinearGradient(
            colors: [TintColor.color(pair.start), end],
            startPoint: vertical ? .top : .leading, endPoint: vertical ? .bottom : .trailing
        )
        .opacity(min(max(style.opacity, MenuBarTintStyle.opacityRange.lowerBound), MenuBarTintStyle.opacityRange.upperBound))
        .animation(.easeInOut(duration: 0.3), value: colorScheme)
        .animation(.easeInOut(duration: 0.3), value: style)
        .ignoresSafeArea()
    }
}
