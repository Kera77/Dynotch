import Foundation
import Observation

/// How finely the trackpad's edge sliders step (spec ES-3).
enum EdgeSliderSteps: String, CaseIterable, Identifiable, Sendable {
    /// 16 steps with a haptic tap each, as macOS's own keys.
    case macOS
    /// One percent at a time, for an exact level; no haptics.
    case percent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .macOS: "macOS steps (16, with haptics)"
        case .percent: "1% steps (precise)"
        }
    }

    var count: Int { self == .macOS ? 16 : 100 }
}

/// The trackpad's edges and what they set (spec ES-1).
enum EdgeZone: String, CaseIterable, Sendable {
    case left, right, top
}

/// Settings of the swipe drop-downs and the trackpad edge sliders (spec DS-1, ES-1…ES-3).
@MainActor
@Observable
final class GestureSettings {
    static let shared = GestureSettings()

    private enum Key {
        static let dropdownsOnSwipe = "dropdownsOnSwipe"
        static let edgeSliders = "edgeSliders"
        static let edgeVolume = "edgeSliderVolume"
        static let edgeBrightness = "edgeSliderBrightness"
        static let edgeKeyboard = "edgeSliderKeyboard"
        static let edgeSteps = "edgeSliderSteps"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// The drop-downs beside the closed notch open only with a swipe down (spec DS-1).
    var dropdownsOnSwipe: Bool {
        didSet { defaults.set(dropdownsOnSwipe, forKey: Key.dropdownsOnSwipe) }
    }

    /// Sliding along the trackpad's edges sets the levels (spec ES-1).
    var edgeSliders: Bool {
        didSet { defaults.set(edgeSliders, forKey: Key.edgeSliders) }
    }

    /// Left edge: the volume.
    var edgeVolume: Bool {
        didSet { defaults.set(edgeVolume, forKey: Key.edgeVolume) }
    }

    /// Right edge: the display's brightness.
    var edgeBrightness: Bool {
        didSet { defaults.set(edgeBrightness, forKey: Key.edgeBrightness) }
    }

    /// Top edge: the keyboard's backlight.
    var edgeKeyboard: Bool {
        didSet { defaults.set(edgeKeyboard, forKey: Key.edgeKeyboard) }
    }

    var edgeSteps: EdgeSliderSteps {
        didSet { defaults.set(edgeSteps.rawValue, forKey: Key.edgeSteps) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        dropdownsOnSwipe = defaults.bool(forKey: Key.dropdownsOnSwipe)
        edgeSliders = defaults.bool(forKey: Key.edgeSliders)
        edgeVolume = defaults.object(forKey: Key.edgeVolume) as? Bool ?? true
        edgeBrightness = defaults.object(forKey: Key.edgeBrightness) as? Bool ?? true
        edgeKeyboard = defaults.object(forKey: Key.edgeKeyboard) as? Bool ?? true
        edgeSteps = defaults.string(forKey: Key.edgeSteps).flatMap(EdgeSliderSteps.init(rawValue:)) ?? .macOS
    }

    func isOn(_ zone: EdgeZone) -> Bool {
        switch zone {
        case .left: edgeVolume
        case .right: edgeBrightness
        case .top: edgeKeyboard
        }
    }
}
