import AppKit
import ApplicationServices

/// One app in the Dock.
struct DockEntry: Equatable, Sendable {
    /// Path of the app bundle, if the Dock names it.
    let path: String?
    let title: String
    /// The badge on its icon; empty without one.
    let label: String
}

/// Reads the badges on the Dock's app icons through Accessibility (spec B-2). The Dock shows
/// every running app, so this covers each app that can have unread notifications.
enum DockBadgeReader {
    static func read() -> [DockEntry] {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return []
        }
        let application = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 1)
        var entries: [DockEntry] = []
        for list in elements(of: application) {
            for item in elements(of: list) where string(item, kAXSubroleAttribute) == "AXApplicationDockItem" {
                entries.append(DockEntry(
                    path: (value(item, kAXURLAttribute) as? URL)?.path,
                    title: string(item, kAXTitleAttribute) ?? "",
                    label: string(item, "AXStatusLabel") ?? ""
                ))
            }
        }
        return entries
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var result: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    private static func elements(of element: AXUIElement) -> [AXUIElement] {
        value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
}
