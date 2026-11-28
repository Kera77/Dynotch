import AppKit
import ApplicationServices

/// Switches a Focus the way the owner does it: through Control Center's Focus module, by
/// Accessibility (spec FC-3). macOS has no API for other apps, but its own panel takes AX presses:
/// open Control Center, expand Focus, press the Focus, press the length, close with Escape.
/// Control Center shows for about a second while it happens.
@MainActor
enum ControlCenterFocus {
    /// What Control Center showed: its Focus list and the header ("On Until 13:52").
    struct Reading: Equatable, Sendable {
        var names: [String]
        var header: String?
    }

    private static var busy = false

    /// The Focuses as Control Center lists them, in its order.
    static func readNames(known: Set<String>) async -> [String]? {
        await session { panel in Self.names(in: panel.rowTitles(), known: known) }
    }

    /// Turns `name` on (if it is off), then picks the length whose label `length` accepts.
    /// - Returns: Control Center's header after the switch ("On Until 13:52"), nil on failure.
    static func turnOn(_ name: String, known: Set<String>, length: ((String) -> Bool)?) async -> Reading? {
        await session { panel in
            guard let box = await panel.checkbox(name) else { return nil }
            if panel.value(of: box) != 1, await !panel.toggle(name) { return nil }
            if let length, let item = await panel.firstCheckbox(where: length) {
                panel.press(item)
                try? await Task.sleep(for: .milliseconds(300))
            }
            return Reading(names: Self.names(in: panel.rowTitles(), known: known), header: panel.header())
        }
    }

    /// Turns `name` off, if it is on.
    static func turnOff(_ name: String) async -> Bool {
        await session { panel in
            guard let box = await panel.checkbox(name) else { return false }
            if panel.value(of: box) == 0 { return true }
            return await panel.toggle(name)
        } ?? false
    }

    /// The Focus rows: the lengths under the active Focus are left out.
    nonisolated static func names(in titles: [String], known: Set<String>) -> [String] {
        titles.filter { !FocusLength.isLengthLabel($0) || known.contains($0) }
    }

    // MARK: - The panel

    private static func session<T>(_ body: (Panel) async -> T?) async -> T? {
        guard !busy else { return nil }
        guard AXIsProcessTrusted() else {
            DiagnosticsLog.append("focus", "no Accessibility: cannot switch")
            return nil
        }
        busy = true
        defer { busy = false }
        guard let panel = await Panel.open() else {
            DiagnosticsLog.append("focus", "Control Center did not open")
            return nil
        }
        let result = await body(panel)
        await panel.close()
        if result == nil { DiagnosticsLog.append("focus", "Control Center switch failed") }
        return result
    }

    @MainActor
    private final class Panel {
        let app: NSRunningApplication
        let element: AXUIElement
        let window: AXUIElement
        private let openedByUs: Bool

        private init(app: NSRunningApplication, element: AXUIElement, window: AXUIElement, openedByUs: Bool) {
            self.app = app
            self.element = element
            self.window = window
            self.openedByUs = openedByUs
        }

        static func open() async -> Panel? {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else {
                return nil
            }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            var window = firstWindow(of: element)
            let openedByUs = window == nil
            if window == nil {
                guard let item = menuBarItem() else { return nil }
                AXUIElementPerformAction(item, kAXPressAction as CFString)
                window = await poll(for: .seconds(2)) { firstWindow(of: element) }
            }
            guard let window else { return nil }
            let panel = Panel(app: app, element: element, window: window, openedByUs: openedByUs)
            // Expand the Focus module, unless it is open already.
            if panel.find({ AXRead.string($0, kAXIdentifierAttribute) == "focus-modes-header" }) == nil {
                let module = await poll(for: .seconds(1)) {
                    panel.find { AXRead.string($0, kAXIdentifierAttribute) == "module-FocusModes" }
                }
                guard let module else {
                    await panel.close()
                    return nil
                }
                panel.press(module)
            }
            return panel
        }

        /// The Control Center item: in the menu bar's agent (macOS 26+) or Control Center itself.
        private static func menuBarItem() -> AXUIElement? {
            for bundleID in ["com.apple.MenuBarAgent", "com.apple.controlcenter"] {
                for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                    let element = AXUIElementCreateApplication(app.processIdentifier)
                    guard let bar = AXRead.element(element, "AXExtrasMenuBar") else { continue }
                    if let item = search(bar, depth: 4, where: {
                        AXRead.string($0, kAXIdentifierAttribute) == "com.apple.menuextra.controlcenter"
                    }) {
                        return item
                    }
                }
            }
            return nil
        }

        private static func firstWindow(of element: AXUIElement) -> AXUIElement? {
            (AXRead.value(element, kAXWindowsAttribute) as? [AXUIElement])?.first
        }

        func close() async {
            guard openedByUs else { return }
            for down in [true, false] {
                CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: down)?.postToPid(app.processIdentifier)
            }
            _ = await Self.poll(for: .seconds(1)) { Self.firstWindow(of: element) == nil ? true : nil }
        }

        // MARK: Reading

        /// The rows of the expanded module, top to bottom (Focuses and the active one's lengths).
        func rowTitles() -> [String] {
            rows().filter { AXRead.string($0, kAXRoleAttribute) == kAXCheckBoxRole as String }
                .compactMap { AXRead.string($0, kAXDescriptionAttribute) }
        }

        /// "On", "On Until 13:52"; nil when no Focus is on.
        func header() -> String? {
            rows().filter { AXRead.string($0, kAXIdentifierAttribute) == "focus-modes-header" }
                .compactMap { AXRead.string($0, kAXValueAttribute) }
                .first { $0 != "Focus" }
        }

        private func rows() -> [AXUIElement] {
            guard let header = find({ AXRead.string($0, kAXIdentifierAttribute) == "focus-modes-header" }),
                  let parent = AXRead.element(header, kAXParentAttribute)
            else { return [] }
            return AXRead.value(parent, kAXChildrenAttribute) as? [AXUIElement] ?? []
        }

        func value(of element: AXUIElement) -> Int? {
            AXRead.value(element, kAXValueAttribute) as? Int
        }

        func checkbox(_ name: String) async -> AXUIElement? {
            await firstCheckbox { $0 == name }
        }

        func firstCheckbox(where accepts: @escaping (String) -> Bool) async -> AXUIElement? {
            await Self.poll(for: .milliseconds(1500)) { [self] in
                rows().first {
                    AXRead.string($0, kAXRoleAttribute) == kAXCheckBoxRole as String
                        && AXRead.string($0, kAXDescriptionAttribute).map(accepts) == true
                }
            }
        }

        // MARK: Acting

        func press(_ element: AXUIElement) {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
        }

        /// Presses the Focus until its state changes: right after the module expands a press
        /// can be lost.
        func toggle(_ name: String) async -> Bool {
            guard let box = await checkbox(name) else { return false }
            let before = value(of: box)
            for _ in 0..<6 {
                guard let current = await checkbox(name) else { return false }
                press(current)
                let changed = await Self.poll(for: .milliseconds(400)) { [self] in
                    rows().first { AXRead.string($0, kAXDescriptionAttribute) == name }
                        .flatMap { value(of: $0) != before ? true : nil }
                }
                if changed == true { return true }
            }
            return false
        }

        func find(_ matches: (AXUIElement) -> Bool) -> AXUIElement? {
            Self.search(window, depth: 6, where: matches)
        }

        private static func search(_ element: AXUIElement, depth: Int, where matches: (AXUIElement) -> Bool) -> AXUIElement? {
            if matches(element) { return element }
            guard depth > 0 else { return nil }
            for child in AXRead.value(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
                if let found = search(child, depth: depth - 1, where: matches) { return found }
            }
            return nil
        }

        private static func poll<T>(for limit: Duration, _ check: () -> T?) async -> T? {
            let deadline = ContinuousClock.now + limit
            while ContinuousClock.now < deadline {
                if let value = check() { return value }
                try? await Task.sleep(for: .milliseconds(50))
            }
            return check()
        }
    }
}
