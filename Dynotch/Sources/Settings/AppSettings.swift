import Combine
import Foundation

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
        static let unlistedFeatures = "unlistedFeatures", showsNowPlaying = "musicShowsNowPlaying"
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
        static let glassAccent = "glassAccent"
        static let glassAccentStrength = "glassAccentStrength"
        static let hideInFullScreen = "hideInFullScreen"
        static let roundOnlyWhereShown = "roundOnlyWhereShown"
        static let design = "design"
        static let panelOpacity = "panelOpacity"
        static let resizableModules = "resizableModules"
        static let externalStyle = "externalStyle"
        static let moduleStrip = "moduleStrip"
        static let moduleStripDelay = "moduleStripDelay"
        static let moduleStripBand = "moduleStripBand"
        static let moduleStripHover = "moduleStripHover"
        static let moduleStripHoverDelay = "moduleStripHoverDelay"
        static let smartRulesOff = "smartRulesOff"
        static let keepsPhoneInDock = "keepsPhoneInDock"
        static let hud = "hud"
        static let claudeSessionPinned = "claudeSessionPinned"
        static let claudeAlerts = "claudeAlerts"
        static let focusDelay = "focusDelay"
        static let calls = "calls"
        static let hoverPreview = "hoverPreview"
        static let noticePlacement = "noticePlacement"
        static let mailSource = "mailSource"
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

    /// On, but not among the modules: opened from elsewhere, e.g. Music from its cover (spec MU-8).
    @Published var unlistedFeatures: Set<FeatureID> = [] {
        didSet { defaults.set(unlistedFeatures.map(\.rawValue).sorted(), forKey: Key.unlistedFeatures) }
    }

    /// What Spotify plays shows beside the closed notch (spec MU-8).
    @Published var showsNowPlaying = true {
        didSet { defaults.set(showsNowPlaying, forKey: Key.showsNowPlaying) }
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

    /// Hovering the notch shows a small preview first (spec PV-1).
    @Published var hoverPreview: Bool {
        didSet { defaults.set(hoverPreview, forKey: Key.hoverPreview) }
    }

    /// Where the small notices stand; nil follows the Wings mode (spec PV-66).
    @Published var noticePlacementChoice: NoticePlacement? {
        didSet { defaults.set(noticePlacementChoice?.rawValue, forKey: Key.noticePlacement) }
    }

    /// Where Gmail's unread messages come from (spec GM-12).
    @Published var mailSource: MailSource {
        didSet { defaults.set(mailSource.rawValue, forKey: Key.mailSource) }
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

    /// A touch of the accent colour in the glass's dark tint (spec D-17).
    @Published var glassAccent: Bool {
        didSet { defaults.set(glassAccent, forKey: Key.glassAccent) }
    }

    /// How strong the accent in the glass is, 0.5 being the default strength (spec D-17f).
    @Published var glassAccentStrength = 0.5 {
        didSet { defaults.set(glassAccentStrength, forKey: Key.glassAccentStrength) }
    }

    static let glassAccentStrengthRange = 0.1...1.0

    /// The closed notch has round ends like the Dynamic Island (spec N-11).
    @Published var roundedNotch: Bool {
        didSet { defaults.set(roundedNotch, forKey: Key.roundedNotch) }
    }

    /// The look of the open notch and the menu bar panels (spec D-1).
    @Published var design: NotchDesign {
        didSet { defaults.set(design.rawValue, forKey: Key.design) }
    }

    /// How opaque the open panel's background is; the closed notch stays black (spec D-13).
    @Published var panelOpacity: Double {
        didSet { defaults.set(panelOpacity, forKey: Key.panelOpacity) }
    }

    static let panelOpacityRange: ClosedRange<Double> = 0.4...1

    /// Modules can be resized from their bottom right corner (spec RS-4).
    @Published var resizableModules: Bool {
        didSet { defaults.set(resizableModules, forKey: Key.resizableModules) }
    }

    /// Resting the pointer at the notch's bottom edge shows the modules under it (spec MS-1).
    @Published var moduleStrip: Bool {
        didSet { defaults.set(moduleStrip, forKey: Key.moduleStrip) }
    }

    /// How long the pointer rests at the bottom edge before the modules show (spec MS-2).
    @Published var moduleStripDelay: Double {
        didSet { defaults.set(moduleStripDelay, forKey: Key.moduleStripDelay) }
    }

    /// The share of the notch's height, from the bottom, that shows the modules (spec MS-2).
    @Published var moduleStripBand: Double {
        didSet { defaults.set(moduleStripBand, forKey: Key.moduleStripBand) }
    }

    /// A module of the strip also opens when the pointer rests on its icon (spec MS-7).
    @Published var moduleStripHover = false { didSet { defaults.set(moduleStripHover, forKey: Key.moduleStripHover) } }
    @Published var moduleStripHoverDelay = 0.5 {
        didSet { defaults.set(moduleStripHoverDelay, forKey: Key.moduleStripHoverDelay) }
    }
    static let moduleStripHoverDelayRange: ClosedRange<Double> = 0.2...1.5
    static let moduleStripDelayRange: ClosedRange<Double> = 0.1...1
    static let moduleStripBandRange: ClosedRange<Double> = 0.25...0.5

    /// Rules of the smart opening that are turned off (spec SO-1).
    @Published private(set) var smartRulesOff: Set<SmartRule> {
        didSet { defaults.set(smartRulesOff.map(\.rawValue).sorted(), forKey: Key.smartRulesOff) }
    }

    /// The look on displays without a physical notch (spec D-7).
    @Published var externalStyle: ExternalNotchStyle {
        didSet { defaults.set(externalStyle.rawValue, forKey: Key.externalStyle) }
    }

    /// The Phone or FaceTime app stays hidden while a call rings and lasts (spec P-5).
    @Published var keepsPhoneInDock: Bool {
        didSet { defaults.set(keepsPhoneInDock, forKey: Key.keepsPhoneInDock) }
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

        let durations = Self.notificationDurationRange
        notificationDuration = Self.stored(defaults, Key.notificationDuration, default: Self.defaultNotificationDuration, in: durations)
        notificationApps = defaults.dictionary(forKey: Key.notificationApps) as? [String: Bool] ?? [:]
        hideNativeBanners = defaults.object(forKey: Key.hideNativeBanners) as? Bool ?? true
        focusFollowsMouse = defaults.object(forKey: Key.focusFollowsMouse) as? Bool ?? true
        claudeRingVisible = defaults.object(forKey: Key.claudeRing) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        roundedNotch = defaults.object(forKey: Key.roundedNotch) as? Bool ?? true
        glassAccent = defaults.object(forKey: Key.glassAccent) as? Bool ?? true
        hideInFullScreen = defaults.object(forKey: Key.hideInFullScreen) as? Bool ?? true
        roundOnlyWhereShown = defaults.bool(forKey: Key.roundOnlyWhereShown)
        design = defaults.string(forKey: Key.design).flatMap(NotchDesign.init(rawValue:)) ?? .black
        resizableModules = defaults.object(forKey: Key.resizableModules) as? Bool ?? true
        panelOpacity = Self.stored(defaults, Key.panelOpacity, default: 1, in: Self.panelOpacityRange)
        moduleStrip = defaults.object(forKey: Key.moduleStrip) as? Bool ?? true
        moduleStripDelay = Self.stored(defaults, Key.moduleStripDelay, default: 0.3, in: Self.moduleStripDelayRange)
        // The lower half by default (v0.42); a band below a quarter from 0.41 was too thin.
        let storedBand = (defaults.object(forKey: Key.moduleStripBand) as? Double).flatMap { $0 < 0.25 ? nil : $0 } ?? 0.5
        moduleStripBand = min(max(storedBand, Self.moduleStripBandRange.lowerBound), Self.moduleStripBandRange.upperBound)
        smartRulesOff = Set((defaults.stringArray(forKey: Key.smartRulesOff) ?? []).compactMap(SmartRule.init(rawValue:)))
        externalStyle = defaults.string(forKey: Key.externalStyle).flatMap(ExternalNotchStyle.init(rawValue:)) ?? .notch
        keepsPhoneInDock = defaults.object(forKey: Key.keepsPhoneInDock) as? Bool ?? true
        hudEnabled = defaults.object(forKey: Key.hud) as? Bool ?? true
        callsEnabled = defaults.object(forKey: Key.calls) as? Bool ?? true
        hoverPreview = defaults.bool(forKey: Key.hoverPreview)
        noticePlacementChoice = defaults.string(forKey: Key.noticePlacement).flatMap(NoticePlacement.init(rawValue:))
        mailSource = defaults.string(forKey: Key.mailSource).flatMap(MailSource.init(rawValue:)) ?? .notifications
        claudeSessionPinned = defaults.bool(forKey: Key.claudeSessionPinned)
        hiddenFromMenuBar = Set((defaults.stringArray(forKey: Key.hiddenFromMenuBar) ?? []).compactMap(FeatureID.init(rawValue:)))
        claudeUsageAlerts = defaults.object(forKey: Key.claudeAlerts) as? Bool ?? true
        focusDelay = Self.stored(defaults, Key.focusDelay, default: 0.1, in: Self.focusDelayRange)
        settingsPresentation = defaults.string(forKey: Key.settingsPresentation)
            .flatMap(SettingsPresentation.init(rawValue:)) ?? .notch
        let storedLead = defaults.object(forKey: Key.calendarLeadMinutes) as? Int ?? Self.defaultCalendarLeadMinutes
        calendarLeadMinutes = min(max(storedLead, Self.calendarLeadRange.lowerBound), Self.calendarLeadRange.upperBound)
        loadModuleOptions()
    }
}

// MARK: - Features and notification sources

extension AppSettings {
    func isSmartRuleOn(_ rule: SmartRule) -> Bool {
        !smartRulesOff.contains(rule)
    }

    func setSmartRule(_ rule: SmartRule, enabled: Bool) {
        if enabled { smartRulesOff.remove(rule) } else { smartRulesOff.insert(rule) }
    }

    /// A merged module runs while its host is on (spec MG-4).
    func isEnabled(_ feature: FeatureID) -> Bool {
        enabledFeatures.contains(isMerged(feature) ? hostFeature(of: feature) : feature)
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
}

// MARK: - Menu bar icons

extension AppSettings {
    func showsInMenuBar(_ feature: FeatureID) -> Bool {
        Self.menuBarFeatures.contains(feature) && !hiddenFromMenuBar.contains(feature)
    }

    func setShowsInMenuBar(_ feature: FeatureID, _ shows: Bool) {
        if shows { hiddenFromMenuBar.remove(feature) } else { hiddenFromMenuBar.insert(feature) }
    }
}
