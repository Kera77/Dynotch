import AppKit
import ApplicationServices

/// Presses one of Spencer's own menu bar items through Accessibility: Restore Focused Window
/// has no command-line option (spec SL-11). Not on the main thread.
enum SpencerMenuItem {
    nonisolated static let bundleIdentifier = "com.pineapple.spencer"

    /// Whether the item was found and pressed. The menu is tried closed first, so usually
    /// nothing shows; otherwise it opens for a moment and closes with the press.
    nonisolated static func press(_ title: String) -> Bool {
        guard AXIsProcessTrusted(),
              let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.processIdentifier
        else { return false }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1)
        guard let bar = element(app, kAXExtrasMenuBarAttribute), let extra = children(of: bar).first else { return false }
        if pressItem(title, under: extra) { return true }
        AXUIElementPerformAction(extra, kAXPressAction as CFString)
        for _ in 0..<10 {
            usleep(80_000)
            if pressItem(title, under: extra) { return true }
        }
        if let menu = menu(of: extra) { AXUIElementPerformAction(menu, kAXCancelAction as CFString) }
        return false
    }

    nonisolated private static func pressItem(_ title: String, under extra: AXUIElement) -> Bool {
        guard let menu = menu(of: extra),
              let item = children(of: menu).first(where: { string($0, kAXTitleAttribute) == title })
        else { return false }
        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
    }

    nonisolated private static func menu(of extra: AXUIElement) -> AXUIElement? {
        children(of: extra).first { string($0, kAXRoleAttribute) == kAXMenuRole }
    }

    nonisolated private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        // swiftlint:disable:next force_cast
        return (value as! AXUIElement)
    }

    nonisolated private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    nonisolated private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
