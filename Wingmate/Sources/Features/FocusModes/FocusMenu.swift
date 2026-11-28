import AppKit
import SwiftUI

/// The Focus button in the panel's top row (spec FC-1): every Focus in a menu; choosing one
/// pops up its lengths right away, as in macOS's Control Center (spec FC-2).
struct FocusMenu: View {
    var service: FocusModeService
    var openSettings: () -> Void = {}
    @State private var anchor = MenuAnchor()

    var body: some View {
        let active = service.active
        Button {
            service.refresh()
            FocusMenuBuilder(service: service, openSettings: openSettings).popUp(below: anchor.view)
        } label: {
            Image(systemName: active?.mode.symbol ?? "moon.fill")
                .font(.notch(size: 12, weight: .semibold))
                .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                .foregroundStyle(active.map { $0.mode.color } ?? Color.white.level(0.45))
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .background(MenuAnchorView(anchor: anchor))
        .help(active.map { "Focus: \($0.mode.name)" } ?? "Focus")
        .accessibilityLabel(active.map { "Focus: \($0.mode.name)" } ?? "Focus")
    }
}

/// The Focus list, then the chosen Focus's lengths (spec FC-1…FC-3).
@MainActor
final class FocusMenuBuilder: NSObject {
    private let service: FocusModeService
    private let openSettings: () -> Void
    private var actions: [() -> Void] = []

    init(service: FocusModeService, openSettings: @escaping () -> Void) {
        self.service = service
        self.openSettings = openSettings
    }

    func popUp(below view: NSView?) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(.sectionHeader(title: "Focus"))
        if service.modes.isEmpty {
            disabled("No Focus found (needs Full Disk Access)", in: menu)
        }
        for mode in service.modes {
            let isOn = service.active?.mode.id == mode.id
            let canTurnOn = service.canTurnOn(mode)
            item(mode.name, symbol: mode.symbol, isOn: isOn, enabled: true, dimmed: !canTurnOn, in: menu) { [weak self] in
                guard let self else { return }
                if canTurnOn {
                    // The lengths drop down right after the click (spec FC-2).
                    DispatchQueue.main.async { FocusMenuBuilder(service: self.service, openSettings: self.openSettings)
                        .popUpLengths(for: mode, below: view) }
                } else {
                    self.openSettings()
                }
            }
        }
        if let active = service.active {
            menu.addItem(.separator())
            let left = FocusModeService.remainingText(until: active.until).map { " (\($0))" } ?? ""
            let title = "Turn off \(active.mode.name)\(left)"
            item(title, symbol: nil, isOn: false, enabled: service.canTurnOff, dimmed: false, in: menu) { [service] in
                service.turnOff()
            }
        }
        menu.addItem(.separator())
        item("Focus Shortcuts…", symbol: nil, isOn: false, enabled: true, dimmed: false, in: menu) { [openSettings] in openSettings() }
        show(menu, below: view)
    }

    func popUpLengths(for mode: FocusMode, below view: NSView?) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(.sectionHeader(title: mode.name))
        for length in FocusLength.allCases {
            item(length.title, symbol: nil, isOn: false, enabled: true, dimmed: false, in: menu) { [service] in
                service.turnOn(mode, for: length)
            }
        }
        show(menu, below: view)
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

    // swiftlint:disable:next function_parameter_count
    private func item(
        _ title: String, symbol: String?, isOn: Bool, enabled: Bool, dimmed: Bool, in menu: NSMenu, action: @escaping () -> Void
    ) {
        let item = NSMenuItem(title: dimmed ? "\(title) – set a Shortcut…" : title, action: #selector(choose(_:)), keyEquivalent: "")
        item.target = self
        item.tag = actions.count
        item.state = isOn ? .on : .off
        item.isEnabled = enabled
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        actions.append(action)
        menu.addItem(item)
    }

    @objc private func choose(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag) else { return }
        actions[sender.tag]()
    }
}
