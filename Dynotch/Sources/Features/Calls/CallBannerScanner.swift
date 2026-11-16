import AppKit
import ApplicationServices

/// Finds the macOS incoming-call banner through Accessibility and presses its buttons
/// (spec P-1, P-2). macOS has no API for calls relayed from the iPhone.
enum CallBannerScanner {
    private static let maxElements = 400
    private static let maxDepth = 12
    /// Processes whose small top-level windows are never call banners.
    private static let ignoredOwners: Set<String> = ["Dock", "Window Server", "WindowServer", "Spotlight", "Dynotch"]

    /// A small window above the normal level: where banners live.
    struct TopWindow: Hashable, Sendable {
        let id: CGWindowID
        let pid: pid_t
        let owner: String
    }

    static func topWindows() -> [TopWindow] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let own = ProcessInfo.processInfo.processIdentifier
        return info.compactMap { window -> TopWindow? in
            guard let layer = window[kCGWindowLayer as String] as? Int, layer > 0, layer < 1000,
                  let id = window[kCGWindowNumber as String] as? CGWindowID,
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t, pid != own,
                  let owner = window[kCGWindowOwnerName as String] as? String, !ignoredOwners.contains(owner),
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width >= 200, rect.width <= 800, rect.height >= 40, rect.height <= 400
            else { return nil }
            return TopWindow(id: id, pid: pid, owner: owner)
        }
    }

    private struct Banner {
        var accept: (element: AXUIElement, action: String)?
        var decline: (element: AXUIElement, action: String)?
        var texts: [String] = []
        var labels: [String] = []
    }

    /// The call a process shows, if it has both an answer and a decline button.
    static func call(in pid: pid_t) -> IncomingCall? {
        let banner = banner(in: pid)
        guard banner.accept != nil, banner.decline != nil else { return nil }
        let description = CallMatcher.describe(texts: banner.texts)
        return IncomingCall(pid: pid, caller: description.caller, detail: description.detail)
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

    private static func inspect(_ element: AXUIElement, into banner: inout Banner) {
        let role = string(of: element, kAXRoleAttribute) ?? ""
        let texts = [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].compactMap { string(of: element, $0) }
        if role == kAXButtonRole {
            banner.labels += texts
            if let kind = texts.lazy.compactMap(CallMatcher.action(forLabel:)).first {
                assign(kind, element: element, action: kAXPressAction, to: &banner)
            }
        } else {
            banner.texts += texts
        }
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
