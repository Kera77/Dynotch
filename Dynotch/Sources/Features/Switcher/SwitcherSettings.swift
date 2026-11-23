import Foundation

/// How the window switcher looks (spec AS-5).
enum SwitcherStyle: String, CaseIterable, Sendable {
    case thumbnails
    case icons
    case titles

    var title: String {
        switch self {
        case .thumbnails: "Thumbnails"
        case .icons: "App Icons"
        case .titles: "Titles"
        }
    }
}

enum SwitcherSize: String, CaseIterable, Sendable {
    case small
    case medium
    case large

    var title: String { rawValue.capitalized }

    /// Scale of tiles and icons.
    var scale: CGFloat {
        switch self {
        case .small: 0.8
        case .medium: 1
        case .large: 1.25
        }
    }
}

/// Which windows take part (spec AS-3).
enum SwitcherScope: String, CaseIterable, Sendable {
    case currentSpace
    case allSpaces

    var title: String { self == .currentSpace ? "Current Space" : "All apps" }
}

/// The window switcher's settings (spec AS-1…AS-12), kept in the defaults.
@MainActor
final class SwitcherSettings: ObservableObject {
    @Published var isOn: Bool { didSet { save(isOn, Key.isOn) } }
    @Published var style: SwitcherStyle { didSet { save(style.rawValue, Key.style) } }
    @Published var size: SwitcherSize { didSet { save(size.rawValue, Key.size) } }
    @Published var scope: SwitcherScope { didSet { save(scope.rawValue, Key.scope) } }
    @Published var groupsByApp: Bool { didSet { save(groupsByApp, Key.groups) } }
    @Published var showsMinimized: Bool { didSet { save(showsMinimized, Key.minimized) } }
    @Published var showsHidden: Bool { didSet { save(showsHidden, Key.hidden) } }
    @Published var currentDisplayOnly: Bool { didSet { save(currentDisplayOnly, Key.display) } }
    /// Hold: stays open after the keys are released, until a click or Return (spec AS-9).
    @Published var holdsAfterRelease: Bool { didSet { save(holdsAfterRelease, Key.hold) } }
    /// Window previews need Screen Recording; off by default (spec AS-7).
    @Published var showsPreviews: Bool { didSet { save(showsPreviews, Key.previews) } }
    /// No shortcut by default (spec AS-8).
    @Published var shortcut: KeyShortcut? {
        didSet { defaults.set(shortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.shortcut) }
    }
    /// 3 or 4 fingers; 0: no swipe (spec AS-11).
    @Published var swipeFingers: Int { didSet { save(swipeFingers, Key.fingers) } }
    /// The module switcher on a swipe up (spec QS-1), on by default.
    @Published var moduleSwitcherOn: Bool { didSet { save(moduleSwitcherOn, Key.modules) } }
    /// 3 or 4 fingers for the swipe up (spec QS-1).
    @Published var moduleFingers: Int { didSet { save(moduleFingers, Key.moduleFingers) } }
    /// Trackpad width (0…1) the fingers move to step one window (spec AS-11b).
    @Published var swipeStep: Double { didSet { save(swipeStep, Key.step) } }
    /// Seconds the fingers stay down before the switcher drops down; a quicker swipe only switches (spec AS-16).
    @Published var showDelay: Double { didSet { save(showDelay, Key.showDelay) } }
    /// A quick swipe always goes to the previous app (spec AS-16).
    @Published var quickSwipeToPreviousApp: Bool { didSet { save(quickSwipeToPreviousApp, Key.quickPrevious) } }
    @Published private(set) var excluded: [String] { didSet { save(excluded, Key.excluded) } }
    /// Only windows mostly covered by others, with either scope (spec AS-14).
    @Published var onlyCovered: Bool { didSet { save(onlyCovered, Key.covered) } }
    /// How much of a window must be covered, 0.25…0.9.
    @Published var coverThreshold: Double { didSet { save(coverThreshold, Key.coverThreshold) } }

    static let swipeStepRange: ClosedRange<Double> = 0.05...0.25
    static let showDelayRange: ClosedRange<Double> = 0...1
    static let coverRange: ClosedRange<Double> = 0.25...0.9

    private enum Key {
        static let isOn = "switcherOn", style = "switcherStyle", size = "switcherSize", scope = "switcherScope"
        static let groups = "switcherGroupsByApp", minimized = "switcherMinimized", hidden = "switcherHidden"
        static let display = "switcherCurrentDisplay", hold = "switcherHold", previews = "switcherPreviews"
        static let shortcut = "switcherShortcut", fingers = "switcherFingers", step = "switcherStep"
        static let showDelay = "switcherShowDelay", quickPrevious = "switcherQuickPrevious"
        static let modules = "moduleSwitcherOn", moduleFingers = "moduleSwitcherFingers"
        static let excluded = "switcherExcluded", covered = "switcherOnlyCovered", coverThreshold = "switcherCoverThreshold"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isOn = defaults.object(forKey: Key.isOn) as? Bool ?? false
        style = defaults.string(forKey: Key.style).flatMap(SwitcherStyle.init(rawValue:)) ?? .icons
        size = defaults.string(forKey: Key.size).flatMap(SwitcherSize.init(rawValue:)) ?? .medium
        scope = defaults.string(forKey: Key.scope).flatMap(SwitcherScope.init(rawValue:)) ?? .currentSpace
        groupsByApp = defaults.object(forKey: Key.groups) as? Bool ?? false
        showsMinimized = defaults.object(forKey: Key.minimized) as? Bool ?? false
        showsHidden = defaults.object(forKey: Key.hidden) as? Bool ?? false
        currentDisplayOnly = defaults.object(forKey: Key.display) as? Bool ?? false
        holdsAfterRelease = defaults.object(forKey: Key.hold) as? Bool ?? false
        showsPreviews = defaults.object(forKey: Key.previews) as? Bool ?? false
        shortcut = defaults.data(forKey: Key.shortcut).flatMap { try? JSONDecoder().decode(KeyShortcut.self, from: $0) }
        swipeFingers = defaults.object(forKey: Key.fingers) as? Int ?? 3
        moduleSwitcherOn = defaults.object(forKey: Key.modules) as? Bool ?? true
        moduleFingers = defaults.object(forKey: Key.moduleFingers) as? Int ?? 3
        swipeStep = defaults.object(forKey: Key.step) as? Double ?? 0.08
        showDelay = defaults.object(forKey: Key.showDelay) as? Double ?? 0.15
        quickSwipeToPreviousApp = defaults.bool(forKey: Key.quickPrevious)
        excluded = defaults.stringArray(forKey: Key.excluded) ?? []
        onlyCovered = defaults.bool(forKey: Key.covered)
        coverThreshold = defaults.object(forKey: Key.coverThreshold) as? Double ?? 0.5
    }

    func exclude(_ bundleID: String) {
        guard !excluded.contains(bundleID) else { return }
        excluded.append(bundleID)
    }

    func include(_ bundleID: String) {
        excluded.removeAll { $0 == bundleID }
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
