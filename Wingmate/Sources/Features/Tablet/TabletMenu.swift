import AppKit
import SwiftUI

/// Tablet button in the panel's top row, beside "focus follows mouse": its menu connects an iPad as a display,
/// like the "+" menu of macOS's Displays settings (spec TB-1). A plain notch button that pops up
/// an AppKit menu, so it looks and hovers like the buttons beside it (spec TB-8).
struct TabletMenu: View {
    var service: TabletDisplayService
    /// The button's view, so the menu opens right below it (spec TB-9).
    @State private var anchor = MenuAnchor()

    var body: some View {
        Button {
            service.refresh()
            TabletMenuBuilder(service: service).popUp(below: anchor.view)
        } label: {
            Image(systemName: "ipad.landscape")
                .font(.notch(size: 12, weight: .semibold))
                .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                .foregroundStyle(service.connected != nil ? ClaudeUsageView.blue : Color.white.level(0.45))
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .background(MenuAnchorView(anchor: anchor))
        .help("iPad as a display")
        .accessibilityLabel("iPad as a display")
        .onAppear { service.refresh() }
    }
}

/// The tablet button's menu: mirror or extend to an iPad, link the keyboard and mouse, the
/// Displays settings (spec TB-2, TB-6, TB-8).
@MainActor
private final class TabletMenuBuilder: NSObject {
    private let service: TabletDisplayService
    private var actions: [() -> Void] = []

    init(service: TabletDisplayService) {
        self.service = service
    }

    func popUp(below view: NSView?) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let busy = service.pending != nil
        header("Mirror or extend to", in: menu)
        if service.tablets.isEmpty { disabled("No iPad nearby", in: menu) }
        for tablet in service.tablets {
            item(tablet.name, isOn: tablet.isConnected, enabled: !busy, in: menu) { [service] in
                tablet.isConnected ? service.disconnect(tablet) : service.connect(tablet)
            }
        }
        if !service.tablets.isEmpty {
            // Universal Control, through the Displays settings' "+" menu (spec TB-6, TB-7).
            menu.addItem(.separator())
            header("Link keyboard and mouse to", in: menu)
            for tablet in service.tablets {
                item(tablet.name, isOn: service.linkedKeyboards.contains(tablet.id), enabled: !busy, in: menu) { [service] in
                    service.linkKeyboard(to: tablet)
                }
            }
        }
        if let failure = service.failure {
            menu.addItem(.separator())
            disabled(failure, in: menu)
        }
        menu.addItem(.separator())
        item("Display Settings…", isOn: false, enabled: true, in: menu) { [service] in service.openDisplaySettings() }
        // Kept alive while the menu is open: the items point at it.
        menu.popUp(positioning: nil, at: MenuAnchor.point(below: view, menuWidth: menu.size.width), in: nil)
        withExtendedLifetime(self) {}
    }

    private func header(_ title: String, in menu: NSMenu) {
        menu.addItem(.sectionHeader(title: title))
    }

    private func disabled(_ title: String, in menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func item(_ title: String, isOn: Bool, enabled: Bool, in menu: NSMenu, action: @escaping () -> Void) {
        let item = NSMenuItem(title: title, action: #selector(choose(_:)), keyEquivalent: "")
        item.target = self
        item.tag = actions.count
        item.state = isOn ? .on : .off
        item.isEnabled = enabled
        actions.append(action)
        menu.addItem(item)
    }

    @objc private func choose(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag) else { return }
        actions[sender.tag]()
    }
}

/// Holds the view a menu opens below (spec TB-9).
@MainActor
final class MenuAnchor {
    weak var view: NSView?

    /// The screen point for the menu's top left corner: centred below the view, a few points
    /// lower; the pointer when the view is unknown.
    static func point(below view: NSView?, menuWidth: CGFloat) -> CGPoint {
        guard let view, let window = view.window else { return NSEvent.mouseLocation }
        let frame = window.convertToScreen(view.convert(view.bounds, to: nil))
        let visibleTop = (window.screen ?? NSScreen.main)?.visibleFrame.maxY ?? .infinity
        return centred(below: frame, menuWidth: menuWidth, visibleTop: visibleTop)
    }

    /// Never above the menu bar's bottom edge: a menu reaching into it gets a scroll arrow that
    /// slides it down on hover (spec TB-11).
    nonisolated static func centred(below frame: CGRect, menuWidth: CGFloat, visibleTop: CGFloat = .infinity) -> CGPoint {
        CGPoint(x: frame.midX - menuWidth / 2, y: min(frame.minY - 4, visibleTop))
    }
}

/// An invisible view behind a button that tells its `MenuAnchor` where the button is.
struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
    }
}

/// The menus Wingmate has open (the tablet menu, list pickers…): when the notch closes under
/// them they close too, instead of staying on screen until the next click (spec TB-5).
@MainActor
enum OpenMenus {
    private static var menus: [NSMenu] = []
    private static var observers: [NSObjectProtocol] = []

    static func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { note in
                // Delivered on the main queue, where the menu lives.
                nonisolated(unsafe) let menu = note.object as? NSMenu
                MainActor.assumeIsolated { if let menu { menus.append(menu) } }
            },
            center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { note in
                nonisolated(unsafe) let menu = note.object as? NSMenu
                MainActor.assumeIsolated { menus.removeAll { $0 === menu } }
            }
        ]
    }

    /// One of Wingmate's menus is open: the notch stays while it is (spec N-22).
    static var isOpen: Bool { !menus.isEmpty }

    static func closeAll() {
        let open = menus
        menus = []
        open.forEach { $0.cancelTracking() }
    }
}
