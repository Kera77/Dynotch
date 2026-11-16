import AppKit

/// Trackpad feedback (spec H-7). Felt only while a finger is on a Force Touch trackpad.
@MainActor
enum Haptics {
    enum Kind {
        /// The notch opened.
        case open
        /// Switched to another feature.
        case featureSwitch
        /// Stepped to another day.
        case dayStep

        var pattern: NSHapticFeedbackManager.FeedbackPattern {
            switch self {
            case .open: .generic
            case .featureSwitch: .levelChange
            case .dayStep: .alignment
            }
        }
    }

    static func perform(_ kind: Kind, settings: AppSettings) {
        guard settings.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(kind.pattern, performanceTime: .now)
    }
}
