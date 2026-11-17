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
        static let hideNativeBanners = "hideNativeBanners"
        static let focusFollowsMouse = "focusFollowsMouse"
        static let claudeRing = "claudeRing"
        static let hiddenFromMenuBar = "hiddenFromMenuBar"
        static let haptics = "haptics"
        static let roundedNotch = "roundedNotch"
        static let hideInFullScreen = "hideInFullScreen"
        static let roundOnlyWhereShown = "roundOnlyWhereShown"
        static let hud = "hud"
        static let claudeSessionPinned = "claudeSessionPinned"
        static let claudeAlerts = "claudeAlerts"
        static let focusDelay = "focusDelay"
        static let calls = "calls"
        static let hoverPreview = "hoverPreview"
        static let previewDelay = "previewDelay"
        static let previewClick = "previewClick"
    }

    /// Also used by the other stores, so tests can give everything one private domain.
    let defaults: UserDefaults

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

    static let focusDelayRange: ClosedRange<Double> = 0...0.5

    /// Volume and brightness beside the notch instead of the macOS overlay (spec A-1).
    @Published var hudEnabled: Bool {
        didSet { defaults.set(hudEnabled, forKey: Key.hud) }
    }

    static let previewDelayRange: ClosedRange<Double> = 0...5

    /// Hovering the notch shows a small preview first (spec PV-1).
    @Published var hoverPreview: Bool {
        didSet { defaults.set(hoverPreview, forKey: Key.hoverPreview) }
    }

    /// Seconds of hovering until the preview opens fully; 0: never by itself (spec PV-2).
    @Published var previewDelay: Double {
        didSet {
            let range = Self.previewDelayRange
            let clamped = (min(max(previewDelay, range.lowerBound), range.upperBound) * 2).rounded() / 2
            if clamped != previewDelay { previewDelay = clamped; return }
            defaults.set(previewDelay, forKey: Key.previewDelay)
        }
    }

    /// A click on the preview opens the panel fully (spec PV-3).
    @Published var previewOpensOnClick: Bool {
        didSet { defaults.set(previewOpensOnClick, forKey: Key.previewClick) }
    }

    /// Incoming calls in the notch (spec P-1).
    @Published var callsEnabled: Bool {
        didSet { defaults.set(callsEnabled, forKey: Key.calls) }
    }

    /// Keep the session usage beside the notch even below 70 % (spec CL-6b).
    @Published var claudeSessionPinned: Bool {
        didSet { defaults.set(claudeSessionPinned, forKey: Key.claudeSessionPinned) }
    }

    /// Trackpad taps when the notch opens and on swipes (spec H-7).
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) }
    }

    /// The closed notch has round ends like the Dynamic Island (spec N-11).
    @Published var roundedNotch: Bool {
        didSet { defaults.set(roundedNotch, forKey: Key.roundedNotch) }
    }

    /// Only the sides of the notch with something beside them are round (spec N-13).
    @Published var roundOnlyWhereShown: Bool {
        didSet { defaults.set(roundOnlyWhereShown, forKey: Key.roundOnlyWhereShown) }
    }

    /// Over a full-screen app the closed notch is hidden (spec N-12).
    @Published var hideInFullScreen: Bool {
        didSet { defaults.set(hideInFullScreen, forKey: Key.hideInFullScreen) }
    }

    /// Features with a menu bar icon (spec M-7).
    static let menuBarFeatures: [FeatureID] = [.calculator, .notes, .reminders, .claudeUsage, .claudeChat]

    /// Features whose menu bar icon is turned off (they stay in the notch).
    @Published private(set) var hiddenFromMenuBar: Set<FeatureID> {
        didSet { defaults.set(hiddenFromMenuBar.map(\.rawValue).sorted(), forKey: Key.hiddenFromMenuBar) }
    }

    func showsInMenuBar(_ feature: FeatureID) -> Bool {
        Self.menuBarFeatures.contains(feature) && !hiddenFromMenuBar.contains(feature)
    }

    func setShowsInMenuBar(_ feature: FeatureID, _ shows: Bool) {
        if shows {
            hiddenFromMenuBar.remove(feature)
        } else {
            hiddenFromMenuBar.insert(feature)
        }
    }

    /// Usage indicator beside the notch (spec CL-6).
    @Published var claudeRingVisible: Bool {
        didSet { defaults.set(claudeRingVisible, forKey: Key.claudeRing) }
    }

    /// Notch notifications from 70 % usage (spec CL-5).
    @Published var claudeUsageAlerts: Bool {
        didSet { defaults.set(claudeUsageAlerts, forKey: Key.claudeAlerts) }
    }

    /// The app under the pointer gets the focus, its window is never raised (spec F-1).
    @Published var focusFollowsMouse: Bool {
        didSet { defaults.set(focusFollowsMouse, forKey: Key.focusFollowsMouse) }
    }

    /// How long the pointer rests before the focus moves (spec F-3).
    @Published var focusDelay: Double {
        didSet {
            let clamped = (min(max(focusDelay, Self.focusDelayRange.lowerBound), Self.focusDelayRange.upperBound) * 20).rounded() / 20
            if clamped != focusDelay { focusDelay = clamped; return }
            defaults.set(focusDelay, forKey: Key.focusDelay)
        }
    }

    /// Close the macOS banner of notifications the notch shows (spec E-8).
    @Published var hideNativeBanners: Bool {
        didSet { defaults.set(hideNativeBanners, forKey: Key.hideNativeBanners) }
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
        hideNativeBanners = defaults.object(forKey: Key.hideNativeBanners) as? Bool ?? true
        focusFollowsMouse = defaults.object(forKey: Key.focusFollowsMouse) as? Bool ?? true
        claudeRingVisible = defaults.object(forKey: Key.claudeRing) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        roundedNotch = defaults.object(forKey: Key.roundedNotch) as? Bool ?? true
        hideInFullScreen = defaults.object(forKey: Key.hideInFullScreen) as? Bool ?? true
        roundOnlyWhereShown = defaults.bool(forKey: Key.roundOnlyWhereShown)
        hudEnabled = defaults.object(forKey: Key.hud) as? Bool ?? true
        callsEnabled = defaults.object(forKey: Key.calls) as? Bool ?? true
        hoverPreview = defaults.bool(forKey: Key.hoverPreview)
        let storedPreviewDelay = defaults.object(forKey: Key.previewDelay) as? Double ?? 1.5
        previewDelay = min(max(storedPreviewDelay, Self.previewDelayRange.lowerBound), Self.previewDelayRange.upperBound)
        previewOpensOnClick = defaults.object(forKey: Key.previewClick) as? Bool ?? true
        claudeSessionPinned = defaults.bool(forKey: Key.claudeSessionPinned)
        hiddenFromMenuBar = Set((defaults.stringArray(forKey: Key.hiddenFromMenuBar) ?? []).compactMap(FeatureID.init(rawValue:)))
        claudeUsageAlerts = defaults.object(forKey: Key.claudeAlerts) as? Bool ?? true
        let storedFocusDelay = defaults.object(forKey: Key.focusDelay) as? Double ?? 0.1
        focusDelay = min(max(storedFocusDelay, Self.focusDelayRange.lowerBound), Self.focusDelayRange.upperBound)
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
