import AppKit
import ApplicationServices

/// Closes the macOS banner of a notification the notch shows (spec E-8). macOS has no API to
/// suppress another app's banner, so the banner is found in Notification Center's accessibility
/// tree and its close action is performed. Needs Accessibility permission.
@MainActor
final class NativeBannerDismisser {
    nonisolated static let notificationCenterBundleID = "com.apple.notificationcenterui"
    private static let maxDepth = 14
    private static let maxElements = 600

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that leads to the Accessibility settings.
    static func requestTrust() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// A notification whose banner should be closed when it shows up.
    private struct Pending {
        let id: Int64
        let keys: [String]
        let expires: Date
        var snapshotTaken = false
    }

    /// How long a banner is waited for after the notification was recorded.
    private static let waitTime: TimeInterval = 8
    private static let pollInterval: Duration = .milliseconds(200)

    private var pending: [Pending] = []
    /// Notifications whose banner Wingmate closed itself: their record goes away without having been read.
    private(set) var closedIDs: Set<Int64> = []
    private var pollTask: Task<Void, Never>?
    private var observer: AXObserver?
    private var observedPID: pid_t = 0

    func dismiss(_ notification: AppNotification) {
        guard Self.isTrusted else {
            DiagnosticsLog.append("banner-dismiss", "#\(notification.id) skipped: no Accessibility permission")
            return
        }
        let keys = BannerMatcher.keys(for: notification)
        guard !keys.isEmpty else { return }
        pending.append(Pending(id: notification.id, keys: keys, expires: Date().addingTimeInterval(Self.waitTime)))
        observeNotificationCenter()
        sweep()
        startPolling()
    }

    /// Banners show up at varying times: watch for new Notification Center windows, and poll as
    /// a fallback while banners are awaited.
    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while let self, !self.pending.isEmpty {
                try? await Task.sleep(for: Self.pollInterval)
                self.sweep()
            }
            self?.pollTask = nil
        }
    }

    /// Tries to close the banners of all awaited notifications.
    fileprivate func sweep() {
        let now = Date()
        for item in pending where item.expires <= now {
            DiagnosticsLog.append("banner-dismiss", "#\(item.id) not found within \(Int(Self.waitTime)) s; \(environmentSummary())")
        }
        pending.removeAll { $0.expires <= now }
        guard !pending.isEmpty else { return }

        var remaining: [Pending] = []
        for var item in pending {
            // About a second in, the banner is surely on screen: note who draws what (no text).
            if !item.snapshotTaken, Self.waitTime - item.expires.timeIntervalSince(now) >= 1 {
                item.snapshotTaken = true
                DiagnosticsLog.append("banner-dismiss", "#\(item.id) at 1 s: \(environmentSummary()) top windows=\(Self.topWindows())")
            }
            let result = closeBanner(matching: item.keys)
            if result.closed {
                closedIDs.insert(item.id)
                // Counts and action names only, never the banner's text.
                DiagnosticsLog.append(
                    "banner-dismiss",
                    "#\(item.id) closed after \(String(format: "%.1f", Self.waitTime - item.expires.timeIntervalSince(now))) s, "
                        + "windows=\(result.windows) candidates=\(result.candidates)"
                )
            } else {
                remaining.append(item)
            }
        }
        pending = remaining
    }

    /// Subscribes to new windows of Notification Center (where banners appear).
    private func observeNotificationCenter() {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: Self.notificationCenterBundleID).first
        else { return }
        let pid = app.processIdentifier
        guard observer == nil || observedPID != pid else { return }
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }

        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let dismisser = Unmanaged<NativeBannerDismisser>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { dismisser.sweep() }
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let root = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kAXWindowCreatedNotification, kAXCreatedNotification] {
            AXObserverAddNotification(created, root, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        observedPID = pid
    }

    // MARK: - Accessibility

    private struct Result {
        var foundProcess = false
        var windows = 0
        var visited = 0
        var closed = false
        var candidates = 0
        var actionNames: Set<String> = []
    }

    private func closeBanner(matching keys: [String]) -> Result {
        var result = Result()
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: Self.notificationCenterBundleID).first
        else { return result }
        result.foundProcess = true
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)

        var visited = 0
        let windows = Self.children(of: root, attribute: kAXWindowsAttribute)
        result.windows = windows.count
        // Banners are not always listed as windows: also walk the app's direct children.
        let roots = windows + Self.children(of: root, attribute: kAXChildrenAttribute)
        var queue: [(element: AXUIElement, depth: Int)] = roots.map { ($0, 0) }
        defer { result.visited = visited }
        while !queue.isEmpty, visited < Self.maxElements {
            let (element, depth) = queue.removeFirst()
            visited += 1
            let actions = Self.actionNames(of: element)
            if let close = actions.first(where: BannerMatcher.isCloseAction) {
                result.candidates += 1
                result.actionNames.formUnion(actions.map(BannerMatcher.displayName(ofAction:)))
                if BannerMatcher.matches(text: Self.text(of: element), keys: keys),
                   AXUIElementPerformAction(element, close as CFString) == .success {
                    result.closed = true
                    return result
                }
            }
            if depth < Self.maxDepth {
                queue += Self.children(of: element, attribute: kAXChildrenAttribute).map { ($0, depth + 1) }
            }
        }
        return result
    }

    /// What Notification Center exposes right now, for the log: windows, direct children and
    /// its on-screen windows according to the window server. No text.
    private func environmentSummary() -> String {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: Self.notificationCenterBundleID).first
        else { return "Notification Center not running" }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)
        let windows = Self.children(of: root, attribute: kAXWindowsAttribute)
        let children = Self.children(of: root, attribute: kAXChildrenAttribute)
        let roles = children.compactMap { Self.string(of: $0, kAXRoleAttribute) }
        let onScreen = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? [])
            .filter { ($0[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier }
            .map { "layer \($0[kCGWindowLayer as String] as? Int ?? -1)" }
        return "ax windows=\(windows.count) children=\(roles) screen windows=\(onScreen)"
    }

    /// On-screen windows above the normal level: owner process, layer and size. No titles.
    static func topWindows() -> [String] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return info.compactMap { window -> String? in
            guard let layer = window[kCGWindowLayer as String] as? Int, layer > 3, layer < 1000,
                  let owner = window[kCGWindowOwnerName as String] as? String,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width > 150, rect.width < 600, rect.height > 40, rect.height < 400
            else { return nil }
            return "\(owner)@\(layer) \(Int(rect.width))x\(Int(rect.height))"
        }
    }

    /// The children, each with a short timeout: a busy process must not hold the caller for the
    /// system's default six seconds per question (spec DV-9b).
    nonisolated static func children(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return [] }
        let children = (value as? [AXUIElement]) ?? []
        for child in children { AXUIElementSetMessagingTimeout(child, 0.3) }
        return children
    }

    nonisolated static func actionNames(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }

    nonisolated static func string(of element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    /// Texts of the banner and its descendants (a few levels).
    nonisolated static func text(of element: AXUIElement, depth: Int = 0) -> String {
        var parts = [kAXDescriptionAttribute, kAXTitleAttribute, kAXValueAttribute]
            .compactMap { string(of: element, $0) }
        if depth < 4 {
            parts += children(of: element, attribute: kAXChildrenAttribute).map { text(of: $0, depth: depth + 1) }
        }
        return parts.joined(separator: " ")
    }
}

/// Pure matching logic for banners.
enum BannerMatcher {
    /// Names of the banner's close action in English and Hungarian.
    static let closeWords = ["close", "bezárás", "clear", "törlés"]

    /// Action names come either plain ("AXPress") or as "Name:Close\nTarget:…".
    static func displayName(ofAction action: String) -> String {
        guard action.hasPrefix("Name:") else { return action }
        let name = action.dropFirst("Name:".count)
        return String(name.split(separator: "\n", maxSplits: 1).first ?? "")
    }

    static func isCloseAction(_ action: String) -> Bool {
        let name = displayName(ofAction: action).lowercased()
        return closeWords.contains(name)
    }

    /// Texts that identify the notification's banner: the title, otherwise the start of the body.
    static func keys(for notification: AppNotification) -> [String] {
        let title = notification.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.count >= 2 { return [title] }
        let body = notification.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return body.count >= 2 ? [String(body.prefix(30))] : []
    }

    static func matches(text: String, keys: [String]) -> Bool {
        let normalized = text.precomposedStringWithCanonicalMapping.lowercased()
        return keys.allSatisfy { normalized.contains($0.precomposedStringWithCanonicalMapping.lowercased()) }
    }
}
