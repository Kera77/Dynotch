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
                let builder = FocusMenuBuilder(service: service)
                builder.popUp(below: anchor.view)
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
        .accessibilityLabel(active.map { "Focus: \($0.mode.name)" } ?? "Focus")
    }
}

/// The Focus list; clicking a Focus drops its lengths down under it in the same list, as in
/// macOS's Control Center (spec FC-1, FC-5), animated down and back up (spec FC-10). Closed
/// without a length, the opened Focus turns on until it is turned off (spec FC-5).
@MainActor
final class FocusMenuBuilder: NSObject, NSMenuDelegate {
    private let service: FocusModeService
    private weak var menu: NSMenu?
    /// The Focus whose lengths are dropped down, and their rows.
    private var expanded: FocusMode?
    private var lengths: (item: NSMenuItem, view: FocusLengthsView)?
    private var rows: [String: FocusRowView] = [:]
    private var chose = false
    private var width: CGFloat = 220

    init(service: FocusModeService) {
        self.service = service
    }

    func popUp(below view: NSView?) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        self.menu = menu
        let active = service.active
        menu.addItem(.sectionHeader(title: active == nil ? "Focus" : "Focus · On"))
        if service.modes.isEmpty {
            disabled("No Focus found (needs Accessibility)", in: menu)
        }
        let now = Date()
        let lengthTitles = FocusLength.allCases.map { $0.title(now: now) } + ["Until tomorrow morning", "Turn Off"]
        let commandTitles = ["Focus Settings…"] + (active.map { ["Turn off \($0.mode.name) (until 23:59)"] } ?? [])
        width = FocusRowView.width(for: service.modes.map(\.name) + lengthTitles + commandTitles)
        for mode in service.modes {
            let item = NSMenuItem()
            let isOn = active?.mode.id == mode.id
            // Drawn by Wingmate, so every Focus shows its own icon (spec FC-6).
            let row = FocusRowView(
                title: mode.name, kind: .focus(icon: Self.icon(for: mode, isOn: isOn), isOn: isOn), width: width
            ) { [weak self, weak item] in
                guard let self, let item else { return }
                self.toggleLengths(of: mode, under: item)
            }
            rows[mode.id] = row
            item.view = row
            menu.addItem(item)
        }
        if let active {
            menu.addItem(.separator())
            let left = FocusModeService.remainingText(until: active.until).map { " (\($0))" } ?? ""
            item("Turn off \(active.mode.name)\(left)", in: menu) { [service] in service.turnOff() }
        }
        menu.addItem(.separator())
        item("Focus Settings…", in: menu) { Self.openFocusSettings() }
        // The highlight also follows a quick pointer the rows' tracking misses (spec FC-11).
        let follower = HoverFollower(window: { [weak self] in self?.rows.values.first?.window })
        menu.popUp(positioning: nil, at: MenuAnchor.point(below: view, menuWidth: menu.size.width), in: nil)
        follower.stop()
        // The chosen row's action is sent as the list closes; only then is it clear that none was.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            guard !chose, let mode = expanded, service.active?.mode.id != mode.id else { return }
            DiagnosticsLog.append("focus", "list closed without a length: until turned off")
            service.turnOn(mode, for: .untilOff)
        }
    }

    /// Drops the Focus's lengths down under its row; the same row again folds them (spec FC-5).
    private func toggleLengths(of mode: FocusMode, under item: NSMenuItem) {
        guard let menu else { return }
        if let open = lengths {
            // The old lengths fold up while the new ones drop down (spec FC-10).
            open.view.fold { [weak menu] in menu?.removeItem(open.item) }
            lengths = nil
        }
        let reopen = expanded?.id != mode.id
        if let expanded { rows[expanded.id]?.isExpanded = false }
        expanded = reopen ? mode : nil
        guard reopen else { return }
        rows[mode.id]?.isExpanded = true
        let now = Date()
        var titles = FocusLength.offered(duringEvent: Self.isDuringEvent(now: now)).map { length in
            (length.title(now: now), { [service] in service.turnOn(mode, for: length) })
        }
        if service.active?.mode.id == mode.id {
            titles.append(("Turn Off", { [service] in service.turnOff() }))
        }
        let view = FocusLengthsView(
            rows: titles.map { title, action in makeRow(title, kind: .length, action: action) }, width: width
        )
        let lengthsItem = NSMenuItem()
        lengthsItem.view = view
        menu.insertItem(lengthsItem, at: menu.index(of: item) + 1)
        lengths = (lengthsItem, view)
        view.unfold()
    }

    /// Arrow keys move the menu's own highlight; the drawn highlight follows it (spec FC-10).
    /// The pointer is followed by the rows' own tracking, which is quicker than the menu.
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        guard NSApp.currentEvent?.type == .keyDown else { return }
        FocusRowView.hover(item?.view as? FocusRowView)
    }

    /// The Focus's own symbol in a round badge, as in Control Center: the Focus that is on in its
    /// colour with a white symbol, the others grey (spec FC-6, FC-12). Drawn by hand, so the menu
    /// cannot turn it into a template.
    static func icon(for mode: FocusMode, isOn: Bool) -> NSImage? {
        let glyphColor: NSColor = isOn ? .white : .secondaryLabelColor
        let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [glyphColor]))
        guard let glyph = (NSImage(systemSymbolName: mode.symbol, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil))?
            .withSymbolConfiguration(configuration)
        else { return nil }
        let color = NSColor(mode.color)
        let side = FocusRowView.badgeSide
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            (isOn ? color : NSColor.labelColor.withAlphaComponent(0.12)).setFill()
            NSBezierPath(ovalIn: rect).fill()
            let size = glyph.size
            glyph.draw(in: NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
            return true
        }
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

    private func disabled(_ title: String, in menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func item(_ title: String, in menu: NSMenu, action: @escaping () -> Void) {
        menu.addItem(makeItem(title, kind: .command, action: action))
    }

    /// A row drawn by Wingmate, so it highlights like the Focus rows (spec FC-9); choosing it
    /// closes the list.
    private func makeItem(_ title: String, kind: FocusRowView.Kind, action: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = makeRow(title, kind: kind, action: action)
        return item
    }

    private func makeRow(_ title: String, kind: FocusRowView.Kind, action: @escaping () -> Void) -> FocusRowView {
        FocusRowView(title: title, kind: kind, width: width) { [weak self] in
            self?.chose = true
            action()
        }
    }
}

/// While the Focus list is open, puts the highlight on the row under the pointer each frame, so a
/// quick move never leaves a row unhighlighted or two behind (spec FC-11). Runs in the menu's
/// tracking mode; a still pointer changes nothing, so the arrow keys keep their highlight.
@MainActor
private final class HoverFollower {
    private var timer: Timer?
    private var last: NSPoint?

    init(window: @escaping @MainActor () -> NSWindow?) {
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let pointer = NSEvent.mouseLocation
                guard pointer != self.last else { return }
                self.last = pointer
                FocusRowView.syncHover(in: window())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
