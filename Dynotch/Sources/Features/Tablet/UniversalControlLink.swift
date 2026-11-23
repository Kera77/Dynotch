import AppKit
import ApplicationServices

/// Links the keyboard and mouse to an iPad (Universal Control) the only way an app not signed by
/// Apple can: through the "+" menu of the Displays settings, with Accessibility (spec TB-6).
/// Only roles and positions are logged, never titles.
enum UniversalControlLink {
    private static let settingsID = "com.apple.systempreferences"
    private static let displaysURL = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")

    /// Chooses the iPad in the "+" menu's keyboard-and-mouse section; nil when done, otherwise why not.
    @MainActor
    static func link(named name: String) async -> String? {
        guard AXIsProcessTrusted() else { return "Dynotch needs Accessibility access for this." }
        let wasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: settingsID).isEmpty
        guard let url = displaysURL else { return "Displays settings could not be opened." }
        NSWorkspace.shared.open(url)
        let found = await Task.detached { choose(name) }.value
        DiagnosticsLog.append("tablet", "link keyboard: \(found ? "chosen" : "not found")")
        guard found else { return "\(name) was not found in Displays settings; choose it under +." }
        if !wasRunning {
            try? await Task.sleep(for: .seconds(1))
            NSRunningApplication.runningApplications(withBundleIdentifier: settingsID).forEach { $0.terminate() }
        }
        return nil
    }

    // MARK: - Accessibility, off the main thread

    nonisolated private static func choose(_ name: String) -> Bool {
        guard let window = waitForWindow() else {
            DiagnosticsLog.append("tablet", "link keyboard: no Displays window")
            return false
        }
        // The Displays pane loads its controls a moment after the window shows.
        for _ in 0..<10 {
            let buttons = popUpButtons(in: window)
            if !buttons.isEmpty {
                DiagnosticsLog.append("tablet", "link keyboard: \(buttons.count) pop-up buttons")
                return buttons.prefix(8).contains { tryButton($0, name: name) }
            }
            usleep(300_000)
        }
        return false
    }

    nonisolated private static func waitForWindow() -> AXUIElement? {
        for _ in 0..<25 {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: settingsID).first {
                let element = AXUIElementCreateApplication(app.processIdentifier)
                if let window = (children(of: element, attribute: kAXWindowsAttribute)).first { return window }
            }
            usleep(200_000)
        }
        return nil
    }

    /// The window's "+" (Add) pop-up, or all its pop-up and menu buttons when none says so.
    nonisolated private static func popUpButtons(in window: AXUIElement) -> [AXUIElement] {
        var found: [AXUIElement] = []
        var queue = [window]
        var visited = 0
        while !queue.isEmpty, visited < 4000 {
            let element = queue.removeFirst()
            visited += 1
            let role = string(element, kAXRoleAttribute)
            if role == kAXPopUpButtonRole || role == kAXMenuButtonRole { found.append(element) }
            queue += children(of: element, attribute: kAXChildrenAttribute)
        }
        // With a "+" there, only it: another pop-up (e.g. "Mirror for") may name the iPad too.
        let add = found.filter(isAddButton)
        return add.isEmpty ? found : add
    }

    nonisolated private static func isAddButton(_ element: AXUIElement) -> Bool {
        let words = [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXIdentifierAttribute]
            .compactMap { string(element, $0)?.lowercased() }
        return words.contains { $0 == "+" || $0.contains("add") || $0.contains("hozzáad") }
    }

    /// Opens the button's menu and chooses the iPad in its last section that names it, which is
    /// the keyboard-and-mouse one (the first is "Mirror or extend to"); closes the menu otherwise.
    nonisolated private static func tryButton(_ button: AXUIElement, name: String) -> Bool {
        AXUIElementPerformAction(button, kAXPressAction as CFString)
        usleep(400_000)
        guard let menu = children(of: button, attribute: kAXChildrenAttribute).first(where: {
            string($0, kAXRoleAttribute) == kAXMenuRole
        }) else { return false }
        let items = children(of: menu, attribute: kAXChildrenAttribute)
        if let index = linkItemIndex(titles: items.map { string($0, kAXTitleAttribute) ?? "" },
                                     enabled: items.map(isEnabled), name: name) {
            AXUIElementPerformAction(items[index], kAXPressAction as CFString)
            return true
        }
        AXUIElementPerformAction(menu, kAXCancelAction as CFString)
        usleep(200_000)
        return false
    }

    /// The item to choose: the iPad's name in a section after the first one. Sections start at a
    /// disabled title or an empty separator.
    nonisolated static func linkItemIndex(titles: [String], enabled: [Bool], name: String) -> Int? {
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        var section = 0
        var match: Int?
        for (index, title) in titles.enumerated() {
            let trimmed = title.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || !enabled[index] {
                section += 1
                continue
            }
            if trimmed.lowercased() == wanted, section > 1 { match = index }
        }
        return match
    }

    nonisolated private static func isEnabled(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &value)
        return (value as? Bool) ?? true
    }

    nonisolated private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    nonisolated private static func children(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return [] }
        return (value as? [AXUIElement]) ?? []
    }
}
