import AppKit
import ApplicationServices

/// Links the keyboard and mouse to an iPad (Universal Control) the only way an app not signed by
/// Apple can: through the "+" menu of the Displays settings, with Accessibility (spec TB-6). It
/// happens in the background: System Settings opens without coming forward and its window is
/// moved off the screen while Dynotch chooses (spec TB-7). Only roles and counts are logged.
enum UniversalControlLink {
    /// What choosing did: nil `failure` when done; `linked` is the iPad's state afterwards.
    struct Outcome: Sendable {
        var failure: String?
        var linked: Bool?
    }

    private static let settingsID = "com.apple.systempreferences"
    private static let displaysURL = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")
    /// Far outside every screen, where the Displays window waits while Dynotch chooses.
    private static let offScreen = CGPoint(x: 40_000, y: 40_000)

    /// Chooses the iPad in the "+" menu's keyboard-and-mouse section, which links it, or unlinks it
    /// when it was linked.
    @MainActor
    static func link(named name: String) async -> Outcome {
        guard AXIsProcessTrusted() else { return Outcome(failure: "Dynotch needs Accessibility access for this.") }
        let wasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: settingsID).isEmpty
        guard let url = displaysURL else { return Outcome(failure: "Displays settings could not be opened.") }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        _ = try? await NSWorkspace.shared.open(url, configuration: configuration)
        let outcome = await Task.detached { choose(name, restore: wasRunning, front: front) }.value
        DiagnosticsLog.append("tablet", "link keyboard: \(outcome.linked.map { $0 ? "linked" : "unlinked" } ?? "not found")")
        if !wasRunning {
            try? await Task.sleep(for: .seconds(1))
            NSRunningApplication.runningApplications(withBundleIdentifier: settingsID).forEach { $0.terminate() }
        }
        if let front { NSRunningApplication(processIdentifier: front)?.activate() }
        return outcome
    }

    // MARK: - Accessibility, off the main thread

    nonisolated private static func choose(_ name: String, restore: Bool, front: pid_t?) -> Outcome {
        guard let window = waitForWindow() else {
            DiagnosticsLog.append("tablet", "link keyboard: no Displays window")
            return Outcome(failure: "Displays settings did not open.")
        }
        // Out of sight at once, and the app the user was in comes back to the front.
        let original = point(window, kAXPositionAttribute)
        setPoint(window, kAXPositionAttribute, offScreen)
        if let front { NSRunningApplication(processIdentifier: front)?.activate() }
        defer {
            if restore, let original { setPoint(window, kAXPositionAttribute, original) }
        }
        // The Displays pane loads its controls a moment after the window shows.
        for _ in 0..<10 {
            let buttons = popUpButtons(in: window)
            if !buttons.isEmpty {
                DiagnosticsLog.append("tablet", "link keyboard: \(buttons.count) pop-up buttons")
                for button in buttons.prefix(8) {
                    if let linked = tryButton(button, name: name) { return Outcome(linked: linked) }
                }
                return Outcome(failure: "\(name) was not found in Displays settings; choose it under +.")
            }
            usleep(300_000)
        }
        return Outcome(failure: "\(name) was not found in Displays settings; choose it under +.")
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

    /// Chooses the iPad in the button's menu, in its last section that names it, which is the
    /// keyboard-and-mouse one (the first is "Mirror or extend to"); closes the menu otherwise.
    /// The menu's items are tried first without opening it, so nothing shows on the screen.
    /// Returns whether the iPad is linked afterwards (a ticked item unlinks), nil when not found.
    nonisolated private static func tryButton(_ button: AXUIElement, name: String) -> Bool? {
        if let linked = chooseItem(in: button, name: name) { return linked }
        AXUIElementPerformAction(button, kAXPressAction as CFString)
        usleep(400_000)
        if let linked = chooseItem(in: button, name: name) { return linked }
        if let menu = menu(of: button) { AXUIElementPerformAction(menu, kAXCancelAction as CFString) }
        usleep(200_000)
        return nil
    }

    nonisolated private static func menu(of button: AXUIElement) -> AXUIElement? {
        children(of: button, attribute: kAXChildrenAttribute).first { string($0, kAXRoleAttribute) == kAXMenuRole }
    }

    nonisolated private static func chooseItem(in button: AXUIElement, name: String) -> Bool? {
        guard let menu = menu(of: button) else { return nil }
        let items = children(of: menu, attribute: kAXChildrenAttribute)
        guard let index = linkItemIndex(titles: items.map { string($0, kAXTitleAttribute) ?? "" },
                                        enabled: items.map(isEnabled), name: name) else { return nil }
        let wasLinked = !(string(items[index], kAXMenuItemMarkCharAttribute) ?? "").isEmpty
        guard AXUIElementPerformAction(items[index], kAXPressAction as CFString) == .success else { return nil }
        return !wasLinked
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

    nonisolated private static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        // swiftlint:disable:next force_cast
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    nonisolated private static func setPoint(_ element: AXUIElement, _ attribute: String, _ point: CGPoint) {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    nonisolated private static func children(of element: AXUIElement, attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return [] }
        return (value as? [AXUIElement]) ?? []
    }
}
