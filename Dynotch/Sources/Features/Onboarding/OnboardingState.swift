import Foundation

/// The steps of the first-launch tour, in order (spec OB-14…OB-22).
enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case openClose
    case moving
    case modules
    case beside
    case power
    case look
    case permissions
    case ready

    /// Steps the user practises on the real notch (spec OB-15, OB-16).
    var isPractice: Bool { self == .openClose || self == .moving }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
    var isLast: Bool { next == nil }
}

/// Where the tour stands, kept in UserDefaults (spec OB-1, OB-4, OB-23, OB-28).
struct OnboardingProgress {
    static let completedKey = "onboarding.completed"
    static let stepKey = "onboarding.step"
    static let seenTipsKey = "onboarding.seenTips"

    let defaults: UserDefaults

    var isCompleted: Bool { defaults.bool(forKey: Self.completedKey) }

    /// The step a tour left half way starts again from (spec OB-4).
    var savedStep: OnboardingStep {
        OnboardingStep(rawValue: defaults.integer(forKey: Self.stepKey)) ?? .welcome
    }

    func save(_ step: OnboardingStep) {
        defaults.set(step.rawValue, forKey: Self.stepKey)
    }

    /// Done or skipped: it does not come back by itself (spec OB-3).
    func complete() {
        defaults.set(true, forKey: Self.completedKey)
        defaults.removeObject(forKey: Self.stepKey)
    }

    /// Replay tour: the tour and the first-use tips start over (spec OB-5, OB-28).
    func reset() {
        defaults.removeObject(forKey: Self.completedKey)
        defaults.removeObject(forKey: Self.stepKey)
        defaults.removeObject(forKey: Self.seenTipsKey)
    }

    var seenTips: Set<String> {
        Set(defaults.stringArray(forKey: Self.seenTipsKey) ?? [])
    }

    func markTipSeen(_ tip: String) {
        defaults.set((seenTips.union([tip])).sorted(), forKey: Self.seenTipsKey)
    }

    /// The tip to show when a module opens, marked as seen: its own the first time, then once
    /// the resize tip on the second module opened (spec OB-26, OB-27).
    func takeTip(for feature: FeatureID) -> FirstUseTip? {
        guard isCompleted else { return nil }
        let seen = seenTips
        if !seen.contains(feature.rawValue) {
            markTipSeen(feature.rawValue)
            return FirstUseTip(id: feature.rawValue, text: OnboardingTips.text(for: feature))
        }
        let modulesSeen = seen.subtracting([OnboardingTips.resizeID]).count
        guard modulesSeen >= 2, !seen.contains(OnboardingTips.resizeID) else { return nil }
        markTipSeen(OnboardingTips.resizeID)
        return FirstUseTip(id: OnboardingTips.resizeID, text: OnboardingTips.resizeText)
    }
}

/// One line shown at the bottom of a module the first time it opens (spec OB-26).
struct FirstUseTip: Equatable, Sendable {
    let id: String
    let text: String
}
