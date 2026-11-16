import AppKit
import ApplicationServices

/// Closes the macOS banner of a notification the notch shows (spec E-8). macOS has no API to
/// suppress another app's banner, so the banner is found in Notification Center's accessibility
/// tree and its close action is performed. Needs Accessibility permission.
@MainActor
final class NativeBannerDismisser {
    private static let notificationCenterBundleID = "com.apple.notificationcenterui"
    /// Banners appear a moment after the record is written; try a few times.
    private static let attemptDelays: [Duration] = [.milliseconds(80), .milliseconds(300), .milliseconds(700), .seconds(1.5)]
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

    func dismiss(_ notification: AppNotification) {
        guard Self.isTrusted else {
            DiagnosticsLog.append("banner-dismiss", "#\(notification.id) skipped: no Accessibility permission")
            return
        }
        let keys = BannerMatcher.keys(for: notification)
        guard !keys.isEmpty else { return }
        Task { [weak self] in
            for (attempt, delay) in Self.attemptDelays.enumerated() {
                try? await Task.sleep(for: delay)
                guard let self else { return }
                let result = self.closeBanner(matching: keys)
                if result.closed || attempt == Self.attemptDelays.count - 1 {
                    // Counts and action names only, never the banner's text.
                    DiagnosticsLog.append(
                        "banner-dismiss",
                        "#\(notification.id) attempt \(attempt + 1): found=\(result.foundProcess) windows=\(result.windows) "
                            + "visited=\(result.visited) closed=\(result.closed) "
                            + "candidates=\(result.candidates) actions=\(result.actionNames.sorted())"
                    )
                }
                if !result.closed, attempt == 1 {
                    // While the banner is likely on screen: record the structure for troubleshooting.
                    DiagnosticsLog.write("banner-tree", self.structureDump(keys: keys))
                }
                if result.closed { return }
            }
        }
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
        var queue: [(element: AXUIElement, depth: Int)] = windows.map { ($0, 0) }
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

    /// Accessibility structure of Notification Center: roles, subroles, identifiers, action
    /// names and whether the notification's text is there. No text is written.
    private func structureDump(keys: [String]) -> String {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: Self.notificationCenterBundleID).first
        else { return "Notification Center not running" }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)
        var lines: [String] = []
        var count = 0
        func visit(_ element: AXUIElement, depth: Int) {
            guard count < 300 else { return }
            count += 1
            let role = Self.string(of: element, kAXRoleAttribute) ?? "?"
            let subrole = Self.string(of: element, kAXSubroleAttribute) ?? "-"
            let identifier = Self.string(of: element, "AXIdentifier") ?? "-"
            let actions = Self.actionNames(of: element).map(BannerMatcher.displayName(ofAction:))
            let children = Self.children(of: element, attribute: kAXChildrenAttribute)
            let ownText = [kAXDescriptionAttribute, kAXTitleAttribute, kAXValueAttribute]
                .compactMap { Self.string(of: element, $0) }.joined(separator: " ")
            let marker = BannerMatcher.matches(text: ownText, keys: keys) ? " [contains title]" : ""
            lines.append(String(repeating: "  ", count: depth)
                + "\(role) \(subrole) id=\(identifier) actions=\(actions) children=\(children.count) textLength=\(ownText.count)\(marker)")
            if depth < Self.maxDepth { children.forEach { visit($0, depth: depth + 1) } }
        }
        Self.children(of: root, attribute: kAXWindowsAttribute).forEach { visit($0, depth: 0) }
        return lines.isEmpty ? "no windows" : lines.joined(separator: "\n")
    }

    private static func children(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return [] }
        return (value as? [AXUIElement]) ?? []
    }

    private static func actionNames(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }

    private static func string(of element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    /// Texts of the banner and its descendants (a few levels).
    private static func text(of element: AXUIElement, depth: Int = 0) -> String {
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
