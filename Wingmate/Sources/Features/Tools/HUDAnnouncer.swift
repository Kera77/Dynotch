import AppKit
import IOKit.ps

/// Short system announcements in the HUD (spec HA-1…HA-4): the charger, the Focus, Caps Lock,
/// Low Power Mode and the quick toggles' shortcuts.
@MainActor
final class HUDAnnouncer {
    private let hud: HUDService
    private let settings = ToolsSettings.shared
    /// Quiet after the launch and a wake (spec HA-4).
    private var quietUntil = Date().addingTimeInterval(HUDAnnouncer.quietTime)
    private var lastFocus: String??
    private var capsLock = NSEvent.modifierFlags.contains(.capsLock)
    private var monitors: [Any] = []
    private var focusPoller: Poller?

    nonisolated static let quietTime: TimeInterval = 30

    init(hud: HUDService) {
        self.hud = hud
    }

    func start() {
        PowerMonitor.shared.listeners.append { [weak self] old, new in self?.powerChanged(from: old, to: new) }
        let flags: (NSEvent) -> Void = { event in
            MainActor.assumeIsolated { HUDAnnouncerHolder.shared?.flagsChanged(event.modifierFlags) }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            flags(event)
            return event
        }) { monitors.append(local) }
        // The Focus files change without a notification for other apps (spec E-20d).
        focusPoller = Poller.start(
            every: 3, isActive: { [settings] in settings.announces(.focus) }, action: { [weak self] in self?.checkFocus() }
        )
        HUDAnnouncerHolder.shared = self
    }

    /// A toggle changed by its shortcut (spec HA-2).
    func toggled(_ toggle: QuickToggle, isOn: Bool) {
        show(.toggleShortcut, symbol: toggle.symbol(isOn: isOn), text: toggle.announcement(isOn: isOn), quietToo: true)
    }

    private func powerChanged(from old: PowerConditions, to new: PowerConditions) {
        if old.isPaused, !new.isPaused { quietUntil = Date().addingTimeInterval(Self.quietTime) }
        if old.onBattery != new.onBattery {
            let level = Self.batteryLevel().map { " · \($0)%" } ?? ""
            show(
                .charger, symbol: new.onBattery ? "battery.75percent" : "bolt.fill",
                text: (new.onBattery ? "On battery" : "Charging") + level
            )
        }
        if old.lowPowerMode != new.lowPowerMode {
            show(.lowPower, symbol: "battery.25percent", text: new.lowPowerMode ? "Low Power Mode on" : "Low Power Mode off")
        }
    }

    fileprivate func flagsChanged(_ flags: NSEvent.ModifierFlags) {
        let isOn = flags.contains(.capsLock)
        guard isOn != capsLock else { return }
        capsLock = isOn
        show(.capsLock, symbol: isOn ? "capslock.fill" : "capslock", text: isOn ? "Caps Lock on" : "Caps Lock off", quietToo: true)
    }

    private func checkFocus() {
        Task {
            let current = await Task.detached { MacFocus.current() }.value
            defer { lastFocus = .some(current) }
            // The first look only learns the state.
            guard let previous = lastFocus, previous != current else { return }
            if let current {
                show(.focus, symbol: "moon.fill", text: current == "Focus" ? "Focus on" : "\(current) on")
            } else {
                show(.focus, symbol: "moon", text: "\(previous ?? "Focus") off")
            }
        }
    }

    private func show(_ kind: AnnouncementKind, symbol: String, text: String, quietToo: Bool = false) {
        guard settings.announces(kind) else { return }
        let now = Date()
        guard quietToo || now >= quietUntil else { return }
        hud.announce(symbol: symbol, text: text)
    }

    nonisolated static func batteryLevel() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            return Int((Double(current) / Double(max) * 100).rounded())
        }
        return nil
    }
}

/// The event monitors' closures reach the announcer through here.
@MainActor
private enum HUDAnnouncerHolder {
    static weak var shared: HUDAnnouncer?
}
