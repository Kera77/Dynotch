import SwiftUI

/// Pins the open notch, so it stays open while the user types (spec E-11c).
private struct PinNotchKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

/// Lets the open notch take the keyboard, so a reply field focused by itself can be typed
/// into without a click (spec E-27).
private struct TakeKeyboardKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var takeKeyboard: @MainActor @Sendable () -> Void {
        get { self[TakeKeyboardKey.self] }
        set { self[TakeKeyboardKey.self] = newValue }
    }

    var pinNotch: @MainActor @Sendable () -> Void {
        get { self[PinNotchKey.self] }
        set { self[PinNotchKey.self] = newValue }
    }
}
