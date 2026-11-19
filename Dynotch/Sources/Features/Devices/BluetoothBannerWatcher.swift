import AppKit
import ApplicationServices
import IOBluetooth

/// Closes macOS's own Bluetooth banners ("AirPods connected", "Move to iPhone"…) so the notch
/// shows them instead (spec DV-9, DV-10). Like E-8, a banner is found in Notification Center's
/// accessibility tree by the device's name and closed; its button comes back as the notch's
/// blue button. Needs Accessibility permission.
@MainActor
final class BluetoothBannerWatcher {
    struct Caught {
        let deviceName: String
        /// The banner's own button ("Move to iPhone"), if it had one.
        let callToAction: String?
    }

    private static let waitTime: TimeInterval = 10
    private static let maxDepth = 14
    private static let maxElements = 600

    var onCatch: ((Caught) -> Void)?
    /// Whether banners may be closed now (Devices and banner hiding on).
    var isEnabled: () -> Bool = { true }
    /// Device names whose banner is awaited after their connection (until the date).
    private var expected: [String: Date] = [:]
    private var deviceNames: [String] = []
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var pollTask: Task<Void, Never>?

    /// Watches Notification Center's new windows from now on.
    func start() {
        refreshNames()
        observeNotificationCenter()
    }

    /// A device just came or went: its banner is looked for during the next seconds.
    func expect(_ name: String) {
        guard NativeBannerDismisser.isTrusted else { return }
        expected[name] = Date().addingTimeInterval(Self.waitTime)
        refreshNames()
        observeNotificationCenter()
        sweep()
        Task { [weak self] in
            for wait in [1.5, 2.5] {
                try? await Task.sleep(for: .seconds(wait))
                guard let self, self.expected[name] != nil else { return }
                self.logWhereBannersAre()
            }
        }
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while let self, !self.expected.isEmpty {
                try? await Task.sleep(for: .milliseconds(250))
                self.sweep()
            }
            self?.pollTask = nil
        }
    }

    private func refreshNames() {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        deviceNames = paired.compactMap(\.name).filter { $0.count >= 3 }.sorted { $0.count > $1.count }
    }

    private func observeNotificationCenter() {
        guard NativeBannerDismisser.isTrusted,
              let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: NativeBannerDismisser.notificationCenterBundleID
              ).first
        else { return }
        let pid = app.processIdentifier
        guard observer == nil || observedPID != pid else { return }
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let watcher = Unmanaged<BluetoothBannerWatcher>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.sweep() }
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let root = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(created, root, kAXWindowCreatedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        observedPID = pid
    }

    /// System processes that draw Bluetooth banners and notices on recent macOS versions.
    private static let bannerProcesses = [
        NativeBannerDismisser.notificationCenterBundleID, "com.apple.controlcenter", "com.apple.AirPlayUIAgent",
        "com.apple.UserNotificationCenter", "com.apple.systemuiserver"
    ]

    /// The processes to search: the known ones, and whoever owns a banner-sized window on top.
    private static func candidateProcesses() -> [pid_t] {
        var pids = bannerProcesses.compactMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0).first?.processIdentifier
        }
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        for window in info {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer > 3, layer < 1000,
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t, pid != getpid(), !pids.contains(pid)
            else { continue }
            pids.append(pid)
        }
        return pids
    }

    /// Closes every banner that names a Bluetooth device and was awaited or offers a button.
    private func sweep() {
        let now = Date()
        expected = expected.filter { $0.value > now }
        guard isEnabled(), !deviceNames.isEmpty else { return }
        for pid in Self.candidateProcesses() where sweep(pid) { return }
    }

    private func sweep(_ pid: pid_t) -> Bool {
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, 0.3)
        let roots = NativeBannerDismisser.children(of: root, attribute: kAXWindowsAttribute)
            + NativeBannerDismisser.children(of: root, attribute: kAXChildrenAttribute)
        var queue: [(element: AXUIElement, depth: Int)] = roots.map { ($0, 0) }
        var visited = 0
        while !queue.isEmpty, visited < Self.maxElements {
            let (element, depth) = queue.removeFirst()
            visited += 1
            let actions = NativeBannerDismisser.actionNames(of: element)
            if let close = actions.first(where: BannerMatcher.isCloseAction) {
                let closes = { AXUIElementPerformAction(element, close as CFString) == .success }
                if catchBanner(element, actions: actions, pid: pid, close: closes) { return true }
            } else if NativeBannerDismisser.string(of: element, kAXRoleAttribute) == kAXWindowRole as String,
                      let button = Self.closeButton(of: element) {
                let presses = { AXUIElementPerformAction(button, kAXPressAction as CFString) == .success }
                if catchBanner(element, actions: actions, pid: pid, close: presses) { return true }
            }
            if depth < Self.maxDepth {
                queue += NativeBannerDismisser.children(of: element, attribute: kAXChildrenAttribute).map { ($0, depth + 1) }
            }
        }
        return false
    }

    private static func closeButton(of window: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement) // swiftlint:disable:this force_cast
    }

    /// Notes, without any text, where macOS shows the banner: for troubleshooting (spec DV-9).
    private func logWhereBannersAre() {
        let owners = Self.candidateProcesses().compactMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }
        DiagnosticsLog.append(
            "devices",
            "bluetooth banner search: trusted=\(NativeBannerDismisser.isTrusted) devices=\(deviceNames.count) "
                + "processes=\(owners) top windows=\(NativeBannerDismisser.topWindows())"
        )
    }

    private func catchBanner(_ element: AXUIElement, actions: [String], pid: pid_t, close: () -> Bool) -> Bool {
        let text = NativeBannerDismisser.text(of: element)
        guard let name = BluetoothBanner.deviceName(in: text, names: deviceNames) else { return false }
        let buttons = actions.map(BannerMatcher.displayName(ofAction:)) + Self.buttonTitles(in: element)
        let callToAction = BluetoothBanner.callToAction(from: buttons)
        guard expected[name] != nil || callToAction != nil, close() else { return false }
        expected[name] = nil
        // No banner text in the log, only that one was caught and by whom.
        let owner = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "?"
        DiagnosticsLog.append("devices", "bluetooth banner closed in \(owner), button=\(callToAction != nil)")
        onCatch?(Caught(deviceName: name, callToAction: callToAction))
        return true
    }

    /// Titles of the banner's buttons (a few levels down).
    private static func buttonTitles(in element: AXUIElement, depth: Int = 0) -> [String] {
        var titles: [String] = []
        if NativeBannerDismisser.string(of: element, kAXRoleAttribute) == kAXButtonRole as String {
            titles += [kAXTitleAttribute, kAXDescriptionAttribute].compactMap { NativeBannerDismisser.string(of: element, $0) }
        }
        guard depth < 5 else { return titles }
        for child in NativeBannerDismisser.children(of: element, attribute: kAXChildrenAttribute) {
            titles += buttonTitles(in: child, depth: depth + 1)
        }
        return titles
    }
}

/// Pure matching logic for Bluetooth banners (spec DV-9, DV-10).
enum BluetoothBanner {
    /// Actions every banner has: not the banner's own button.
    private static let ignored = [
        "axpress", "axshowmenu", "axscrolltovisible", "axraise", "show details", "show", "options", "részletek",
        "megjelenítés", "beállítások", "close", "bezárás", "clear", "törlés"
    ]

    /// The longest paired device name the banner mentions.
    static func deviceName(in text: String, names: [String]) -> String? {
        let normalized = normalize(text)
        return names.sorted { $0.count > $1.count }.first { normalized.contains(normalize($0)) }
    }

    /// The banner's own button, such as "Move to iPhone" or "Connect".
    static func callToAction(from titles: [String]) -> String? {
        titles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0.count <= 30 && !ignored.contains($0.lowercased()) }
    }

    private static func normalize(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping.lowercased().replacingOccurrences(of: "’", with: "'")
    }
}
