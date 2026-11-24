import AppKit
import IOKit.ps

/// What the Mac's state means for the background looks (spec RF-9, RF-10).
struct PowerConditions: Equatable {
    var screensAsleep = false
    var sessionInactive = false
    var locked = false
    var lowPowerMode = false
    var onBattery = false

    /// Nobody can see the notch: every repeating look stops.
    var isPaused: Bool { screensAsleep || sessionInactive || locked }

    /// Background intervals grow three times in Low Power Mode or on battery.
    var slowFactor: Double { lowPowerMode || onBattery ? 3 : 1 }
}

/// Follows sleep, lock, Low Power Mode and the power source, and pauses or slows every `Poller`
/// and the window list (spec RF-9, RF-10). Settings changes make the pollers check their gates
/// again (spec RF-8).
@MainActor
final class PowerMonitor {
    static let shared = PowerMonitor()

    private(set) var conditions = PowerConditions()
    /// Told of every change, with the state before it: the HUD announcements and the morning
    /// forecast (spec HA-2, WX-7).
    var listeners: [@MainActor (_ old: PowerConditions, _ new: PowerConditions) -> Void] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var powerSource: CFRunLoopSource?
    private var gateCheckQueued = false

    func start() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.screensAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.screensAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.sessionInactive = true }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.sessionInactive = false }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.locked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.locked = false }
        observe(.default, Notification.Name.NSProcessInfoPowerStateDidChange) { _ in }
        // A setting stored: the pollers check their gates again, once per run-loop turn.
        let defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { PowerMonitor.shared.queueGateCheck() }
        }
        observers.append((.default, defaultsObserver))
        watchPowerSource()
        update { _ in }
    }

    private func observe(
        _ center: NotificationCenter, _ name: Notification.Name, _ change: @escaping @MainActor (inout PowerConditions) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PowerMonitor.shared.update(change) }
        }
        observers.append((center, token))
    }

    private func watchPowerSource() {
        let callback: IOPowerSourceCallbackType = { _ in
            MainActor.assumeIsolated { PowerMonitor.shared.update { _ in } }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, nil)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        powerSource = source
    }

    private func update(_ change: (inout PowerConditions) -> Void) {
        var next = conditions
        change(&next)
        next.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        next.onBattery = Self.isOnBattery()
        let previous = conditions
        conditions = next
        if next.isPaused != previous.isPaused {
            DiagnosticsLog.append("power", next.isPaused ? "background looks paused" : "background looks resumed")
        }
        if next.slowFactor != previous.slowFactor {
            DiagnosticsLog.append(
                "power", "background looks x\(Int(next.slowFactor)) (low power: \(next.lowPowerMode), battery: \(next.onBattery))"
            )
        }
        Poller.setSlowFactor(next.slowFactor)
        Poller.setPaused(next.isPaused)
        if next != previous { listeners.forEach { $0(previous, next) } }
    }

    private func queueGateCheck() {
        guard !gateCheckQueued else { return }
        gateCheckQueued = true
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                PowerMonitor.shared.gateCheckQueued = false
                Poller.reevaluateAll()
            }
        }
    }

    nonisolated static func isOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
        else { return false }
        return (type as String) == kIOPSBatteryPowerValue
    }
}
