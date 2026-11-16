import Combine
import Foundation

/// Where the settings open (spec C-2).
enum SettingsPresentation: String, CaseIterable, Sendable {
    /// Inside the opened notch panel.
    case notch
    /// In a separate window.
    case window
}

/// User preferences, persisted in UserDefaults (spec G-5).
@MainActor
final class AppSettings: ObservableObject {
    static let closeDelayRange: ClosedRange<Double> = 0...3
    static let defaultCloseDelay = 0.3
    static let calendarLeadRange: ClosedRange<Int> = 1...30
    static let defaultCalendarLeadMinutes = 10
    static let notificationDurationRange: ClosedRange<Double> = 2...30
    static let defaultNotificationDuration: Double = 6

    private enum Key {
        static let closeDelay = "closeDelay"
        static let featureOrder = "featureOrder"
        static let enabledFeatures = "enabledFeatures"
        static let lastFeature = "lastFeature"
        static let calendarAlertEnabled = "calendarAlertEnabled"
        static let calendarLeadMinutes = "calendarLeadMinutes"
        static let calendarLarge = "calendarLarge"
        static let notificationDuration = "notificationDuration"
        static let notificationApps = "notificationApps"
        static let settingsPresentation = "settingsPresentation"
    }

    private let defaults: UserDefaults

    /// Seconds the panel stays open after the pointer leaves it (spec N-4, N-5).
    @Published var closeDelay: Double {
        didSet {
            let clamped = Self.normalizedDelay(closeDelay)
            if clamped != closeDelay { closeDelay = clamped; return }
            defaults.set(closeDelay, forKey: Key.closeDelay)
        }
    }

    /// Order of features in the menu bar, including disabled ones (spec M-3).
    @Published var featureOrder: [FeatureID] {
        didSet { defaults.set(featureOrder.map(\.rawValue), forKey: Key.featureOrder) }
    }

    @Published private(set) var enabledFeatures: Set<FeatureID> {
        didSet { defaults.set(enabledFeatures.map(\.rawValue).sorted(), forKey: Key.enabledFeatures) }
    }

    /// Last active feature, restored when the panel opens (spec L-1, L-2).
    @Published var lastFeature: FeatureID? {
        didSet { defaults.set(lastFeature?.rawValue, forKey: Key.lastFeature) }
    }

    /// Show the upcoming-event indicator beside the closed notch (spec K-7).
    @Published var calendarAlertEnabled: Bool {
        didSet { defaults.set(calendarAlertEnabled, forKey: Key.calendarAlertEnabled) }
    }

    /// Minutes before an event the indicator appears (spec K-8).
    @Published var calendarLeadMinutes: Int {
        didSet {
            let clamped = min(max(calendarLeadMinutes, Self.calendarLeadRange.lowerBound), Self.calendarLeadRange.upperBound)
            if clamped != calendarLeadMinutes { calendarLeadMinutes = clamped; return }
            defaults.set(calendarLeadMinutes, forKey: Key.calendarLeadMinutes)
        }
    }

    /// Whether the calendar was last shown as the full month view (spec K-10).
    @Published var calendarLarge: Bool {
        didSet { defaults.set(calendarLarge, forKey: Key.calendarLarge) }
    }

    /// Seconds a notification peeks out of the closed notch (spec E-6).
    @Published var notificationDuration: Double {
        didSet {
            let range = Self.notificationDurationRange
            let clamped = min(max(notificationDuration.rounded(), range.lowerBound), range.upperBound)
            if clamped != notificationDuration { notificationDuration = clamped; return }
            defaults.set(notificationDuration, forKey: Key.notificationDuration)
        }
    }

    /// Per-app choices that differ from the default (bundle identifier → enabled).
    @Published private(set) var notificationApps: [String: Bool] {
        didSet { defaults.set(notificationApps, forKey: Key.notificationApps) }
    }

    @Published var settingsPresentation: SettingsPresentation {
        didSet { defaults.set(settingsPresentation.rawValue, forKey: Key.settingsPresentation) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedDelay = defaults.object(forKey: Key.closeDelay) as? Double
        closeDelay = Self.normalizedDelay(storedDelay ?? Self.defaultCloseDelay)

        let storedOrder = (defaults.stringArray(forKey: Key.featureOrder) ?? []).compactMap(FeatureID.init(rawValue:))
        let missing = FeatureID.allCases.filter { !storedOrder.contains($0) }
        featureOrder = Self.deduplicated(storedOrder) + missing

        if let storedEnabled = defaults.stringArray(forKey: Key.enabledFeatures) {
            // Features added in a newer version (not yet in the stored order) start enabled.
            let enabled = Set(storedEnabled.compactMap(FeatureID.init(rawValue:))).union(missing)
            enabledFeatures = enabled.isEmpty ? Set(FeatureID.allCases) : enabled
        } else {
            enabledFeatures = Set(FeatureID.allCases)
        }

        lastFeature = defaults.string(forKey: Key.lastFeature).flatMap(FeatureID.init(rawValue:))

        calendarAlertEnabled = defaults.object(forKey: Key.calendarAlertEnabled) as? Bool ?? true
        calendarLarge = defaults.bool(forKey: Key.calendarLarge)

        let storedDuration = defaults.object(forKey: Key.notificationDuration) as? Double ?? Self.defaultNotificationDuration
        let durationRange = Self.notificationDurationRange
        notificationDuration = min(max(storedDuration, durationRange.lowerBound), durationRange.upperBound)
        notificationApps = defaults.dictionary(forKey: Key.notificationApps) as? [String: Bool] ?? [:]
        settingsPresentation = defaults.string(forKey: Key.settingsPresentation)
            .flatMap(SettingsPresentation.init(rawValue:)) ?? .notch
        let storedLead = defaults.object(forKey: Key.calendarLeadMinutes) as? Int ?? Self.defaultCalendarLeadMinutes
        calendarLeadMinutes = min(max(storedLead, Self.calendarLeadRange.lowerBound), Self.calendarLeadRange.upperBound)
    }

    /// Enabled features in menu-bar order.
    var activeFeatures: [FeatureID] {
        featureOrder.filter(enabledFeatures.contains)
    }

    /// Feature to show when the panel opens: the last one if still enabled, else the first enabled.
    var initialFeature: FeatureID {
        if let lastFeature, enabledFeatures.contains(lastFeature) { return lastFeature }
        return activeFeatures.first ?? .home
    }

    func isEnabled(_ feature: FeatureID) -> Bool {
        enabledFeatures.contains(feature)
    }

    /// Enables or disables a feature. The last enabled feature can't be disabled.
    @discardableResult
    func setEnabled(_ feature: FeatureID, _ enabled: Bool) -> Bool {
        if enabled {
            enabledFeatures.insert(feature)
            return true
        }
        guard enabledFeatures.count > 1 || !enabledFeatures.contains(feature) else { return false }
        enabledFeatures.remove(feature)
        return true
    }

    func isNotificationAppEnabled(_ identifier: String, default defaultValue: Bool) -> Bool {
        notificationApps[identifier] ?? defaultValue
    }

    func setNotificationApp(_ identifier: String, enabled: Bool) {
        notificationApps[identifier] = enabled
    }

    /// Moves an enabled feature to a position among the enabled ones (menu bar drag, spec M-6).
    /// Disabled features keep their places in `featureOrder`.
    func moveActiveFeature(_ feature: FeatureID, toActiveIndex index: Int) {
        var active = activeFeatures
        guard let from = active.firstIndex(of: feature) else { return }
        active.remove(at: from)
        active.insert(feature, at: min(max(index, 0), active.count))
        guard active != activeFeatures else { return }
        var remaining = active.makeIterator()
        featureOrder = featureOrder.map { enabledFeatures.contains($0) ? (remaining.next() ?? $0) : $0 }
    }

    func moveFeatures(from source: IndexSet, to destination: Int) {
        var order = featureOrder
        let moving = source.sorted().map { order[$0] }
        for index in source.sorted(by: >) { order.remove(at: index) }
        let insertAt = destination - source.filter { $0 < destination }.count
        order.insert(contentsOf: moving, at: max(0, min(insertAt, order.count)))
        featureOrder = order
    }

    static func normalizedDelay(_ value: Double) -> Double {
        let clamped = min(max(value, closeDelayRange.lowerBound), closeDelayRange.upperBound)
        return (clamped * 10).rounded() / 10
    }

    private static func deduplicated(_ list: [FeatureID]) -> [FeatureID] {
        var seen = Set<FeatureID>()
        return list.filter { seen.insert($0).inserted }
    }
}
