import AppKit
import SwiftUI

/// The Spencer button beside the notch, like the iPad button: its menu restores a window layout
/// and remembers it for the connected displays (spec SL-1, SL-2).
struct SpencerMenu: View {
    var service: SpencerService
    @State private var anchor = MenuAnchor()

    static let symbol = "rectangle.3.group"

    var body: some View {
        Button {
            service.refresh()
            SpencerMenuBuilder(service: service).popUp(below: anchor.view)
        } label: {
            Image(systemName: Self.symbol)
                .font(.notch(size: 12, weight: .semibold))
                .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                .foregroundStyle(service.autoSwitch ? ClaudeUsageView.blue : Color.white.level(0.45))
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .background(MenuAnchorView(anchor: anchor))
        .help("Spencer window layouts")
        .accessibilityLabel("Spencer window layouts")
    }
}

/// Layouts, this display setup, Switch automatically, Update current layout, Open Spencer (spec SL-2).
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
        menu.addItem(.sectionHeader(title: "Layouts"))
        if service.layouts.isEmpty { disabled("No layouts in Spencer yet", in: menu) }
        for layout in service.layouts {
            item(layout, isOn: layout == service.assigned, in: menu) { [service] in service.choose(layout) }
        }
        if let setup = service.setup {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "This display setup"))
            disabled(setup.title, in: menu)
            if service.assigned != nil {
                item("Forget this display setup", isOn: false, in: menu) { [service] in service.forgetSetup() }
            } else {
                disabled("Pick a layout above to use it here", in: menu)
            }
        }
        menu.addItem(.separator())
        item("Switch automatically", isOn: service.autoSwitch, in: menu) { [service] in service.autoSwitch.toggle() }
        item("Update current layout", isOn: false, in: menu) { [service] in service.updateCurrent() }
        item("Open Spencer", isOn: false, in: menu) { [service] in service.openSpencer() }
        if let failure = service.failure {
            menu.addItem(.separator())
            disabled(failure, in: menu)
        }
        menu.popUp(positioning: nil, at: MenuAnchor.point(below: view, menuWidth: menu.size.width), in: nil)
        withExtendedLifetime(self) {}
    }

    private func disabled(_ title: String, in menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func item(_ title: String, isOn: Bool, in menu: NSMenu, action: @escaping () -> Void) {
        let item = NSMenuItem(title: title, action: #selector(choose(_:)), keyEquivalent: "")
        item.target = self
        item.tag = actions.count
        item.state = isOn ? .on : .off
        actions.append(action)
        menu.addItem(item)
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
