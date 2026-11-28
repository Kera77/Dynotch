import AppKit
import EventKit
import SwiftUI

/// The Focus button in the panel's top row (spec FC-1): the Focuses of Control Center with their
/// icons; choosing one drops down its lengths, as in macOS's Control Center (spec FC-2).
struct FocusMenu: View {
    var service: FocusModeService
    @State private var anchor = MenuAnchor()

    var body: some View {
        let active = service.active
        Button {
            Task {
                // The first time (and after the Focuses change) the list comes from Control Center.
                await service.loadMacListIfNeeded()
                FocusMenuBuilder(service: service).popUp(below: anchor.view)
            }
        } label: {
            Image(systemName: active?.mode.symbol ?? "moon.fill")
                .font(.notch(size: 12, weight: .semibold))
                .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                .foregroundStyle(active.map { $0.mode.color } ?? Color.white.level(0.45))
                .opacity(service.isSwitching ? 0.5 : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .disabled(service.isSwitching)
        .background(MenuAnchorView(anchor: anchor))
        .help(active.map { "Focus: \($0.mode.name)" } ?? "Focus")
        .accessibilityLabel(active.map { "Focus: \($0.mode.name)" } ?? "Focus")
    }
}

/// The Focus list, then the chosen Focus's lengths (spec FC-1, FC-2).
@MainActor
final class FocusMenuBuilder: NSObject {
    private let service: FocusModeService
    private var actions: [() -> Void] = []

    init(service: FocusModeService) {
        self.service = service
    }

    func popUp(below view: NSView?) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let active = service.active
        menu.addItem(.sectionHeader(title: active == nil ? "Focus" : "Focus · On"))
        if service.modes.isEmpty {
            disabled("No Focus found (needs Accessibility)", in: menu)
        }
        for mode in service.modes {
            item(mode.name, image: Self.icon(for: mode), isOn: active?.mode.id == mode.id, in: menu) { [weak self] in
                guard let self else { return }
                // The lengths drop down right after the click (spec FC-2).
                DispatchQueue.main.async { FocusMenuBuilder(service: self.service).popUpLengths(for: mode, below: view) }
            }
        }
        if let active {
            menu.addItem(.separator())
            let left = FocusModeService.remainingText(until: active.until).map { " (\($0))" } ?? ""
            item("Turn off \(active.mode.name)\(left)", image: nil, isOn: false, in: menu) { [service] in service.turnOff() }
        }
        menu.addItem(.separator())
        item("Focus Settings…", image: nil, isOn: false, in: menu) { Self.openFocusSettings() }
        show(menu, below: view)
    }

    func popUpLengths(for mode: FocusMode, below view: NSView?) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(.sectionHeader(title: mode.name))
        let now = Date()
        for length in FocusLength.offered(duringEvent: Self.isDuringEvent(now: now)) {
            item(length.title(now: now), image: nil, isOn: false, in: menu) { [service] in
                service.turnOn(mode, for: length)
            }
        }
        if service.active?.mode.id == mode.id {
            menu.addItem(.separator())
            item("Turn Off", image: nil, isOn: false, in: menu) { [service] in service.turnOff() }
        }
        show(menu, below: view)
    }

    /// The Focus's own symbol in its colour, as in Control Center.
    private static func icon(for mode: FocusMode) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [NSColor(mode.color)])
        return NSImage(systemSymbolName: mode.symbol, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
    }

    /// A timed calendar event is on now: Control Center then offers "Until the end of this event".
    private static func isDuringEvent(now: Date) -> Bool {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return false }
        let store = EKEventStore()
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-12 * 3600), end: now.addingTimeInterval(60), calendars: nil
        )
        return store.events(matching: predicate).contains { !$0.isAllDay && $0.startDate <= now && now < $0.endDate }
    }

    private static func openFocusSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func show(_ menu: NSMenu, below view: NSView?) {
        menu.popUp(positioning: nil, at: MenuAnchor.point(below: view, menuWidth: menu.size.width), in: nil)
        withExtendedLifetime(self) {}
    }

    private func disabled(_ title: String, in menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func item(_ title: String, image: NSImage?, isOn: Bool, in menu: NSMenu, action: @escaping () -> Void) {
        let item = NSMenuItem(title: title, action: #selector(choose(_:)), keyEquivalent: "")
        item.target = self
        item.tag = actions.count
        item.state = isOn ? .on : .off
        item.image = image
        actions.append(action)
        menu.addItem(item)
    }

    @objc private func choose(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag) else { return }
        actions[sender.tag]()
    }
}
