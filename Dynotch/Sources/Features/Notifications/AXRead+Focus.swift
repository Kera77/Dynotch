import AppKit
import ApplicationServices

/// The front app's window and focused field, for typing into it safely (spec E-11b, RF-15).
extension AXRead {
    nonisolated static func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = value(parent, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    /// The front app's focused field, if the front app is `bundleID`.
    @MainActor
    static func focusedField(of bundleID: String) -> AXUIElement? {
        frontApp(bundleID).flatMap { element($0, kAXFocusedUIElementAttribute) }
    }

    /// The front app's focused window, if the front app is `bundleID`.
    @MainActor
    static func focusedWindow(of bundleID: String) -> AXUIElement? {
        frontApp(bundleID).flatMap { element($0, kAXFocusedWindowAttribute) }
    }

    /// Whether the field takes typed text.
    nonisolated static func isTextInput(_ field: AXUIElement) -> Bool {
        let role = string(field, kAXRoleAttribute) ?? ""
        return [kAXTextAreaRole as String, kAXTextFieldRole as String, kAXComboBoxRole as String].contains(role)
    }

    nonisolated static func same(_ first: AXUIElement?, _ second: AXUIElement?) -> Bool {
        guard let first, let second else { return first == nil && second == nil }
        return CFEqual(first, second)
    }

    @MainActor
    private static func frontApp(_ bundleID: String) -> AXUIElement? {
        guard let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier == bundleID else { return nil }
        return AXUIElementCreateApplication(front.processIdentifier)
    }

    /// Checks `isReady` every `step` until it holds (true) or `limit` has passed (false), so a
    /// fast app is not kept waiting for the slowest case (spec RF-15).
    @MainActor
    static func wait(
        upTo limit: Duration, step: Duration = .milliseconds(100), until isReady: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if isReady() { return true }
            try? await Task.sleep(for: step)
        }
        return isReady()
    }
}
