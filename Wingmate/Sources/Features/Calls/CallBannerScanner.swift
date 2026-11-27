import AppKit
import ApplicationServices

/// Finds the macOS incoming-call banner through Accessibility and presses its buttons
/// (spec P-1, P-2). macOS has no API for calls relayed from the iPhone.
enum CallBannerScanner {
    private static let maxElements = 400
    private static let maxDepth = 12
    /// Processes whose small top-level windows are never call banners.
    private static let ignoredOwners: Set<String> = ["Dock", "Window Server", "WindowServer", "Spotlight", "Wingmate", "Wingmate"]

    /// Processes that show call banners; they are looked at for as long as they have a window on
    /// screen. Notification Center draws its banners in one screen-sized transparent window.
    /// Not the Phone or FaceTime app: walking their windows every second kept them busy, so they
    /// are looked at only when a new window of theirs appears (spec P-6).
    static let bannerHosts: Set<String> = ["Notification Center", "NotificationCenter"]

    /// A window above the normal level: where banners live.
    struct TopWindow: Hashable, Sendable {
        let id: CGWindowID
        let pid: pid_t
        let owner: String
        /// "layer 23 2560x1440", for the log.
        let shape: String

        var isBannerHost: Bool { CallBannerScanner.bannerHosts.contains(owner) }
    }

    static func topWindows(in windows: [ListedWindow]) -> [TopWindow] {
        let own = ProcessInfo.processInfo.processIdentifier
        return windows.compactMap { window -> TopWindow? in
            guard window.layer > 0, window.layer < 1000, window.pid != own, !ignoredOwners.contains(window.owner),
                  window.frame.width >= 100, window.frame.height >= 30
            else { return nil }
            let shape = "layer \(window.layer) \(Int(window.frame.width))x\(Int(window.frame.height))"
            return TopWindow(id: window.id, pid: window.pid, owner: window.owner, shape: shape)
        }
    }

    private struct Banner {
        var accept: (element: AXUIElement, action: String)?
        var decline: (element: AXUIElement, action: String)?
        var texts: [String] = []
        var labels: [String] = []
        /// Roles with the shape of their texts ("W…(13)"), for the log.
        var outline: [String] = []
    }

    /// The call a process shows, if it has both an answer and a decline button.
    static func call(in pid: pid_t) -> IncomingCall? {
        let banner = banner(in: pid)
        guard banner.accept != nil, banner.decline != nil else { return nil }
        let description = CallMatcher.describe(texts: banner.texts)
        return IncomingCall(pid: pid, caller: description.caller, detail: description.detail)
    }

    struct ScanResult: Sendable {
        let call: IncomingCall?
        /// Button labels and action names seen while no call was found, for the log.
        let labels: [String]
    }

    /// The first call among the processes; the one already known to show it is looked at first.
    static func scan(_ pids: [pid_t], preferring preferred: pid_t?) -> ScanResult {
        let order = pids.sorted { ($0 == preferred ? 0 : 1) < ($1 == preferred ? 0 : 1) }
        var labels: [String] = []
        for pid in order {
            let banner = banner(in: pid)
            if let accept = banner.accept, banner.decline != nil {
                let own = bannerTexts(around: accept.element)
                let description = CallMatcher.describe(texts: own.texts.isEmpty ? banner.texts : own.texts)
                let call = IncomingCall(pid: pid, caller: description.caller, detail: description.detail)
                return ScanResult(call: call, labels: own.outline)
            }
            labels += banner.labels
        }
        return ScanResult(call: nil, labels: labels)
    }

    /// Button labels and action names a process shows, for the log; no other text.
    static func labels(in pid: pid_t) -> [String] {
        banner(in: pid).labels
    }

    @discardableResult
    static func perform(_ action: CallAction, in pid: pid_t) -> Bool {
        let banner = banner(in: pid)
        guard let target = action == .accept ? banner.accept : banner.decline else { return false }
        return AXUIElementPerformAction(target.element, target.action as CFString) == .success
    }

    private static func banner(in pid: pid_t) -> Banner {
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, 0.25)
        var banner = Banner()
        var queue: [(element: AXUIElement, depth: Int)] =
            (children(of: root, kAXWindowsAttribute) + children(of: root, kAXChildrenAttribute)).map { ($0, 0) }
        var visited = 0
        while !queue.isEmpty, visited < maxElements {
            let (element, depth) = queue.removeFirst()
            visited += 1
            inspect(element, into: &banner)
            if depth < maxDepth {
                queue += children(of: element, kAXChildrenAttribute).map { ($0, depth + 1) }
            }
        }
        return banner
    }

    /// The texts of the banner the answer button belongs to: the closest ancestor that also holds
    /// the decline button. Texts of other banners and the window's own name stay out.
    private static func bannerTexts(around accept: AXUIElement) -> (texts: [String], outline: [String]) {
        var element = accept
        for _ in 0..<8 {
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent) == .success,
                  let parent, CFGetTypeID(parent) == AXUIElementGetTypeID()
            else { break }
            // swiftlint:disable:next force_cast
            element = parent as! AXUIElement
            if (string(of: element, kAXRoleAttribute) ?? "") == kAXApplicationRole { break }
            var subtree = Banner()
            var queue: [(element: AXUIElement, depth: Int)] = [(element, 0)]
            var visited = 0
            while !queue.isEmpty, visited < 120 {
                let (current, depth) = queue.removeFirst()
                visited += 1
                inspect(current, into: &subtree)
                if depth < 8 { queue += children(of: current, kAXChildrenAttribute).map { ($0, depth + 1) } }
            }
            if subtree.decline != nil { return (subtree.texts, subtree.outline) }
        }
        return ([], [])
    }

    private static func masked(_ text: String) -> String {
        "\(text.prefix(1))…(\(text.count))"
    }

    private static func inspect(_ element: AXUIElement, into banner: inout Banner) {
        let role = string(of: element, kAXRoleAttribute) ?? ""
        let texts = [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].compactMap { string(of: element, $0) }
        if role == kAXButtonRole {
            banner.labels += texts
            if let kind = texts.lazy.compactMap(CallMatcher.action(forLabel:)).first {
                assign(kind, element: element, action: kAXPressAction, to: &banner)
            }
        } else if role == kAXStaticTextRole {
            // What the banner writes comes before the names of its groups.
            banner.texts = texts + banner.texts
        } else {
            banner.texts += texts
        }
        if !texts.isEmpty { banner.outline.append("\(role): \(texts.map(masked).joined(separator: ", "))") }
        // Banners also offer their buttons as named actions ("Name:Accept\n…").
        for action in actionNames(of: element) where action.hasPrefix("Name:") {
            let name = BannerMatcher.displayName(ofAction: action)
            banner.labels.append("action:" + name)
            if let kind = CallMatcher.action(forLabel: name) {
                assign(kind, element: element, action: action, to: &banner)
            }
        }
    }

    private static func assign(_ kind: CallAction, element: AXUIElement, action: String, to banner: inout Banner) {
        switch kind {
        case .accept where banner.accept == nil: banner.accept = (element, action)
        case .decline where banner.decline == nil: banner.decline = (element, action)
        default: break
        }
    }

    private static func children(of element: AXUIElement, _ attribute: String) -> [AXUIElement] {
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
}
