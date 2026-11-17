import SwiftUI

/// Pins the open notch, so it stays open while the user types (spec E-11c).
private struct PinNotchKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var pinNotch: @MainActor @Sendable () -> Void {
        get { self[PinNotchKey.self] }
        set { self[PinNotchKey.self] = newValue }
    }
}
