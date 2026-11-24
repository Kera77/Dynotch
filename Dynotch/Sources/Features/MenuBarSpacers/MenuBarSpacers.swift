import AppKit
import Combine

/// An empty place, a line or dots among the menu bar icons (spec MB-1…MB-6, MB-13).
struct MenuBarSpacer: Codable, Identifiable, Equatable, Sendable {
    enum Style: String, Codable, CaseIterable, Sendable {
        case empty = "Empty"
        case line = "Line"
        case dot = "Dot"
        case dots = "Dots"
        case doubleLine = "Double line"
    }

    enum Width: String, Codable, CaseIterable, Sendable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"

        var points: CGFloat {
            switch self {
            case .small: 8
            case .medium: 16
            case .large: 32
            }
        }
    }

    var id = UUID()
    var style: Style = .empty
    var width: Width = .medium
    /// Hidden while no menu bar icon stands left of it (spec MB-14).
    var hidesWhenAlone = false

    init() {}

    // Spaces saved before MB-14 have no `hidesWhenAlone`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        style = (try? container.decode(Style.self, forKey: .style)) ?? .empty
        width = (try? container.decode(Width.self, forKey: .width)) ?? .medium
        hidesWhenAlone = (try? container.decode(Bool.self, forKey: .hidesWhenAlone)) ?? false
    }
}

/// Keeps one status item per spacer. Their places are the system's: ⌘-drag moves them, and the
/// system remembers where (spec MB-3).
@MainActor
final class MenuBarSpacerService: NSObject, ObservableObject {
    static let shared = MenuBarSpacerService()

    private static let key = "menuBarSpacers"
    @Published private(set) var spacers: [MenuBarSpacer] {
        didSet {
            if let data = try? JSONEncoder().encode(spacers) { defaults.set(data, forKey: Self.key) }
            if isStarted { sync() }
        }
    }

    private let defaults: UserDefaults
    private var items: [UUID: NSStatusItem] = [:]
    private var isStarted = false
    /// Spaces hidden now because nothing stands left of them (spec MB-14).
    private var alone: Set<UUID> = []
    private var aloneTimer: Timer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        spacers = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([MenuBarSpacer].self, from: $0) } ?? []
        super.init()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        sync()
    }

    @discardableResult
    func add() -> MenuBarSpacer {
        let spacer = MenuBarSpacer()
        spacers.append(spacer)
        return spacer
    }

    func remove(_ id: UUID) {
        spacers.removeAll { $0.id == id }
    }

    func setStyle(_ style: MenuBarSpacer.Style, of id: UUID) {
        guard let index = spacers.firstIndex(where: { $0.id == id }) else { return }
        spacers[index].style = style
    }

    func setWidth(_ width: MenuBarSpacer.Width, of id: UUID) {
        guard let index = spacers.firstIndex(where: { $0.id == id }) else { return }
        spacers[index].width = width
    }

    func setHidesWhenAlone(_ hides: Bool, of id: UUID) {
        guard let index = spacers.firstIndex(where: { $0.id == id }) else { return }
        spacers[index].hidesWhenAlone = hides
    }

    // MARK: - Status items

    private func sync() {
        let wanted = Set(spacers.map(\.id))
        for (id, item) in items where !wanted.contains(id) {
            NSStatusBar.system.removeStatusItem(item)
            items[id] = nil
        }
        alone = alone.filter { id in spacers.contains { $0.id == id && $0.hidesWhenAlone } }
        for spacer in spacers {
            let item = items[spacer.id] ?? makeItem(for: spacer)
            items[spacer.id] = item
            item.length = alone.contains(spacer.id) ? 0 : spacer.width.points
            item.button?.image = Self.image(for: spacer.style)
            item.button?.imagePosition = .imageOnly
            item.menu = menu(for: spacer)
        }
        updateAloneTimer()
    }

    // MARK: Hidden while alone (spec MB-14)

    private func updateAloneTimer() {
        let wanted = spacers.contains(where: \.hidesWhenAlone)
        if wanted, aloneTimer == nil {
            aloneTimer = RepeatingTimer.start(every: 2) { [weak self] in self?.checkAlone() }
            checkAlone()
        } else if !wanted {
            aloneTimer?.invalidate()
            aloneTimer = nil
        }
    }

    /// Hides the spaces that have no other menu bar icon left of them, shows them again when one comes.
    private func checkAlone() {
        let own = items.values.compactMap { $0.button?.window?.frame }
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let others = windows.compactMap { window -> CGRect? in
            guard window[kCGWindowLayer as String] as? Int == MenuBarSpace.statusLayer,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect.width > 0
            else { return nil }
            // Back to AppKit coordinates, to compare with the spaces' own windows.
            let flipped = CGRect(x: rect.minX, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
            return own.contains { abs($0.minX - flipped.minX) < 1 && abs($0.width - flipped.width) < 1 } ? nil : flipped
        }
        var next: Set<UUID> = []
        for spacer in spacers where spacer.hidesWhenAlone {
            guard let window = items[spacer.id]?.button?.window else { continue }
            let screenMinX = window.screen?.frame.minX ?? -.greatestFiniteMagnitude
            if !Self.hasIcon(leftOf: window.frame, among: others, screenMinX: screenMinX) { next.insert(spacer.id) }
        }
        guard next != alone else { return }
        alone = next
        sync()
    }

    /// Whether a menu bar icon stands left of a space in the same menu bar. The space's right edge
    /// stays put while it is hidden, so that is what is measured from.
    nonisolated static func hasIcon(leftOf space: CGRect, among icons: [CGRect], screenMinX: CGFloat) -> Bool {
        icons.contains { icon in
            abs(icon.midY - space.midY) < 12 && icon.maxX <= space.minX + 1 && icon.minX >= screenMinX
        }
    }

    private func makeItem(for spacer: MenuBarSpacer) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: spacer.width.points)
        // The place the user ⌘-drags it to is kept under this name (spec MB-3).
        item.autosaveName = "DynotchSpacer-\(spacer.id.uuidString)"
        item.button?.title = ""
        item.button?.setAccessibilityLabel("Menu bar space")
        return item
    }

    private static func image(for style: MenuBarSpacer.Style) -> NSImage? {
        switch style {
        case .empty: nil
        case .line: lineImage
        case .dot: dotImage
        case .dots: dotsImage
        case .doubleLine: doubleLineImage
        }
    }

    /// A drawing tinted like the other menu bar icons.
    private static func template(width: CGFloat, _ draw: @escaping @Sendable (NSRect) -> Void) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: 16), flipped: false) { rect in
            NSColor.black.setFill()
            draw(rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// A thin vertical line.
    private static let lineImage = template(width: 2) { rect in
        NSBezierPath(roundedRect: NSRect(x: 0.5, y: 1, width: 1, height: rect.height - 2), xRadius: 0.5, yRadius: 0.5).fill()
    }

    /// A small dot in the middle (spec MB-13).
    private static let dotImage = template(width: 4) { rect in
        NSBezierPath(ovalIn: NSRect(x: 0.5, y: rect.midY - 1.5, width: 3, height: 3)).fill()
    }

    /// Three dots, one under the other (spec MB-13).
    private static let dotsImage = template(width: 4) { rect in
        for offset in [-5.0, 0, 5] {
            NSBezierPath(ovalIn: NSRect(x: 1, y: rect.midY + offset - 1, width: 2, height: 2)).fill()
        }
    }

    /// Two thin lines side by side (spec MB-13).
    private static let doubleLineImage = template(width: 5) { rect in
        for left in [0.5, 3.5] {
            NSBezierPath(roundedRect: NSRect(x: left, y: 2, width: 1, height: rect.height - 4), xRadius: 0.5, yRadius: 0.5).fill()
        }
    }

    /// A click on a space (either button): its style, width, another space, or removing it (spec MB-4).
    private func menu(for spacer: MenuBarSpacer) -> NSMenu {
        let menu = NSMenu()
        let styleItem = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        let styles = NSMenu()
        for style in MenuBarSpacer.Style.allCases {
            let entry = item(style.rawValue, #selector(chooseStyle(_:)), value: [spacer.id.uuidString, style.rawValue])
            entry.state = spacer.style == style ? .on : .off
            styles.addItem(entry)
        }
        styleItem.submenu = styles
        menu.addItem(styleItem)
        let widthItem = NSMenuItem(title: "Width", action: nil, keyEquivalent: "")
        let widths = NSMenu()
        for width in MenuBarSpacer.Width.allCases {
            let entry = item(width.rawValue, #selector(chooseWidth(_:)), value: [spacer.id.uuidString, width.rawValue])
            entry.state = spacer.width == width ? .on : .off
            widths.addItem(entry)
        }
        widthItem.submenu = widths
        menu.addItem(widthItem)
        let alone = item("Hide When Nothing Is Left of It", #selector(toggleAlone(_:)), value: [spacer.id.uuidString])
        alone.state = spacer.hidesWhenAlone ? .on : .off
        menu.addItem(alone)
        menu.addItem(.separator())
        menu.addItem(item("Add Space", #selector(addSpace(_:)), value: []))
        menu.addItem(item("Remove Space", #selector(removeSpace(_:)), value: [spacer.id.uuidString]))
        menu.addItem(.separator())
        let hint = NSMenuItem(title: "⌘-drag to move it", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        return menu
    }

    private func item(_ title: String, _ action: Selector, value: [String]) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        entry.representedObject = value
        return entry
    }

    @objc private func chooseStyle(_ sender: NSMenuItem) {
        guard let (id, raw) = Self.pair(sender), let style = MenuBarSpacer.Style(rawValue: raw) else { return }
        setStyle(style, of: id)
    }

    @objc private func chooseWidth(_ sender: NSMenuItem) {
        guard let (id, raw) = Self.pair(sender), let width = MenuBarSpacer.Width(rawValue: raw) else { return }
        setWidth(width, of: id)
    }

    @objc private func toggleAlone(_ sender: NSMenuItem) {
        guard let raw = (sender.representedObject as? [String])?.first, let id = UUID(uuidString: raw),
              let spacer = spacers.first(where: { $0.id == id })
        else { return }
        setHidesWhenAlone(!spacer.hidesWhenAlone, of: id)
    }

    @objc private func addSpace(_ sender: NSMenuItem) {
        add()
    }

    @objc private func removeSpace(_ sender: NSMenuItem) {
        guard let raw = (sender.representedObject as? [String])?.first, let id = UUID(uuidString: raw) else { return }
        remove(id)
    }

    private static func pair(_ sender: NSMenuItem) -> (UUID, String)? {
        guard let values = sender.representedObject as? [String], values.count == 2,
              let id = UUID(uuidString: values[0])
        else { return nil }
        return (id, values[1])
    }
}
