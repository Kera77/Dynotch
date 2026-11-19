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

    /// Closes every banner that names a Bluetooth device and was awaited or offers a button.
    private func sweep() {
        let now = Date()
        expected = expected.filter { $0.value > now }
        guard isEnabled(), !deviceNames.isEmpty,
              let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: NativeBannerDismisser.notificationCenterBundleID
              ).first
        else { return }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)
        let roots = NativeBannerDismisser.children(of: root, attribute: kAXWindowsAttribute)
            + NativeBannerDismisser.children(of: root, attribute: kAXChildrenAttribute)
        var queue: [(element: AXUIElement, depth: Int)] = roots.map { ($0, 0) }
        var visited = 0
        while !queue.isEmpty, visited < Self.maxElements {
            let (element, depth) = queue.removeFirst()
            visited += 1
            let actions = NativeBannerDismisser.actionNames(of: element)
            if let close = actions.first(where: BannerMatcher.isCloseAction),
               catchBanner(element, actions: actions, close: close) {
                continue
            }
            if depth < Self.maxDepth {
                queue += NativeBannerDismisser.children(of: element, attribute: kAXChildrenAttribute).map { ($0, depth + 1) }
            }
        }
    }

    private func catchBanner(_ element: AXUIElement, actions: [String], close: String) -> Bool {
        let text = NativeBannerDismisser.text(of: element)
        guard let name = BluetoothBanner.deviceName(in: text, names: deviceNames) else { return false }
        let buttons = actions.map(BannerMatcher.displayName(ofAction:)) + Self.buttonTitles(in: element)
        let callToAction = BluetoothBanner.callToAction(from: buttons)
        guard expected[name] != nil || callToAction != nil,
              AXUIElementPerformAction(element, close as CFString) == .success
        else { return false }
        expected[name] = nil
        // No banner text in the log, only that one was caught.
        DiagnosticsLog.append("devices", "bluetooth banner closed, button=\(callToAction != nil)")
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
