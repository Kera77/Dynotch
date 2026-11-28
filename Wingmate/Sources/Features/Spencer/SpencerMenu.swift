import AppKit
import SwiftUI

/// The Spencer button beside the notch, like the iPad button: its menu restores a window layout
/// and remembers it for the connected displays (spec SL-1, SL-2).
struct SpencerMenu: View {
    var service: SpencerService
    @State private var anchor = MenuAnchor()

    /// For the settings list and the notice; the button shows Spencer's own icon (spec SL-7).
    static let symbol = "bell"
    /// Spencer's menu bar icon (a bell), read from the app itself.
    static let icon: NSImage? = {
        let image = Bundle(path: SpencerService.appPath)?.image(forResource: "bar_menu_icon")
        image?.isTemplate = true
        return image
    }()

    var body: some View {
        Button {
            service.refresh()
            SpencerMenuBuilder(service: service).popUp(below: anchor.view)
        } label: {
            icon
                .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                .foregroundStyle(Color.white.level(0.45))
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .background(MenuAnchorView(anchor: anchor))
        .accessibilityLabel("Spencer window layouts")
    }

    @ViewBuilder private var icon: some View {
        if let image = Self.icon {
            Image(nsImage: image).renderingMode(.template).resizable().interpolation(.high).frame(width: 15, height: 15)
        } else {
            Image(systemName: Self.symbol).font(.notch(size: 12, weight: .semibold))
        }
    }
}

/// Active workspace (Spencer's own items and icons), layouts (only those made for the displays
/// here can be chosen, SL-13), this display setup, Switch automatically, Open Spencer (spec SL-2, SL-7, SL-11).
@MainActor
private final class SpencerMenuBuilder: NSObject {
    private let service: SpencerService
    private var actions: [() -> Void] = []

    init(service: SpencerService) {
        self.service = service
    }

    func popUp(below view: NSView?) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        addActiveWorkspace(to: menu)
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Layouts"))
        if service.layouts.isEmpty { disabled("No layouts in Spencer yet", in: menu) }
        let available = service.availableLayouts
        for layout in service.layouts {
            let item = item(layout, isOn: layout == service.assigned, in: menu) { [service] in service.choose(layout) }
            item.isEnabled = available.contains(layout)
        }
        if let setup = service.setup {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "This display setup"))
            disabled(setup.title, in: menu)
        }
        menu.addItem(.separator())
        item("Switch automatically", isOn: service.autoSwitch, in: menu) { [service] in service.autoSwitch.toggle() }
        item("Open Spencer", isOn: false, in: menu) { [service] in service.openSpencer() }
        if let failure = service.failure {
            menu.addItem(.separator())
            disabled(failure, in: menu)
        }
        menu.popUp(positioning: nil, at: MenuAnchor.point(below: view, menuWidth: menu.size.width), in: nil)
        withExtendedLifetime(self) {}
    }

    /// As at the top of Spencer's own menu, with its icons (spec SL-11).
    private func addActiveWorkspace(to menu: NSMenu) {
        menu.addItem(.sectionHeader(title: "Active workspace"))
        item("Restore Workspace", symbol: "arrow.counterclockwise", in: menu) { [service] in service.restoreActive() }
        let update = NSMenuItem(title: "Update Workspace", action: nil, keyEquivalent: "")
        update.image = Self.image("arrow.triangle.2.circlepath")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        item("All Spaces", isOn: false, in: submenu) { [service] in service.updateActive(currentSpaceOnly: false) }
        item("Current Space Only", isOn: false, in: submenu) { [service] in service.updateActive(currentSpaceOnly: true) }
        update.submenu = submenu
        menu.addItem(update)
    }

    private func item(_ title: String, symbol: String, in menu: NSMenu, action: @escaping () -> Void) {
        item(title, isOn: false, in: menu, action: action).image = Self.image(symbol)
    }

    private static func image(_ symbol: String) -> NSImage? {
        NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    }

    private func disabled(_ title: String, in menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    @discardableResult
    private func item(_ title: String, isOn: Bool, in menu: NSMenu, action: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(choose(_:)), keyEquivalent: "")
        item.target = self
        item.tag = actions.count
        item.state = isOn ? .on : .off
        actions.append(action)
        menu.addItem(item)
        return item
    }

    @objc private func choose(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag) else { return }
        actions[sender.tag]()
    }
}

/// The Cancel pill of a countdown notice: its rim runs out anticlockwise until the switch (spec SL-4).
struct CountdownCancelPill: View {
    let interval: DateInterval
    let cancel: () -> Void

    var body: some View {
        Button(action: cancel) {
            Text("Cancel")
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 20)
                .background(Capsule(style: .continuous).fill(Color.white.level(0.16)))
                .overlay {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        Capsule(style: .continuous)
                            .trim(from: 0, to: Self.remaining(of: interval, at: context.date))
                            .stroke(Theme.blue, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    }
                    .padding(0.75)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.notch)
        .help("Cancel the switch")
        .accessibilityLabel("Cancel the switch")
    }

    /// 1 at the start, 0 at the end. The drawn end runs back along the path, which goes
    /// clockwise on screen, so the rim empties anticlockwise.
    nonisolated static func remaining(of interval: DateInterval, at date: Date) -> CGFloat {
        guard interval.duration > 0 else { return 0 }
        return CGFloat(min(max(1 - date.timeIntervalSince(interval.start) / interval.duration, 0), 1))
    }
}
