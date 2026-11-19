import AppKit
import Combine

/// An empty place or a thin line among the menu bar icons (spec MB-1…MB-6).
struct MenuBarSpacer: Codable, Identifiable, Equatable, Sendable {
    enum Style: String, Codable, CaseIterable, Sendable {
        case empty = "Empty"
        case line = "Line"
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

    // MARK: - Status items

    private func sync() {
        let wanted = Set(spacers.map(\.id))
        for (id, item) in items where !wanted.contains(id) {
            NSStatusBar.system.removeStatusItem(item)
            items[id] = nil
        }
        for spacer in spacers {
            let item = items[spacer.id] ?? makeItem(for: spacer)
            items[spacer.id] = item
            item.length = spacer.width.points
            item.button?.image = spacer.style == .line ? Self.lineImage : nil
            item.button?.imagePosition = .imageOnly
            item.menu = menu(for: spacer)
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

    /// A thin vertical line, tinted like the other menu bar icons.
    private static let lineImage: NSImage = {
        let image = NSImage(size: NSSize(width: 2, height: 16), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 0.5, y: 1, width: 1, height: rect.height - 2), xRadius: 0.5, yRadius: 0.5).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()

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
