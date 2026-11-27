import Foundation
import os
import SwiftUI

/// Opening, closing and switching modules as signpost intervals, to measure them in Instruments
/// (spec RF-16). Nearly free while nothing records them.
enum Signposts {
    static let signposter = OSSignposter(subsystem: AppInfo.bundleIdentifier, category: "notch")

    /// `body` animated, as an interval that ends when the animation does ("open", "close").
    @MainActor
    static func animate(_ name: StaticString, _ animation: Animation?, _ body: () -> Void) {
        let state = signposter.beginInterval(name)
        withAnimation(animation, body) { signposter.endInterval(name, state) }
    }

    /// A module switch, until the next turn of the main run loop (the new module drawn).
    @MainActor
    static func moduleSwitch(to feature: FeatureID) {
        guard signposter.isEnabled else { return }
        let state = signposter.beginInterval("module switch", "\(feature.rawValue, privacy: .public)")
        DispatchQueue.main.async { signposter.endInterval("module switch", state) }
    }
}
