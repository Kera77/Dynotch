import AppKit

/// The modules opened most recently first, kept across restarts (spec QS-3).
@MainActor
final class ModuleHistory {
    static let shared = ModuleHistory()
    private static let key = "moduleHistory"

    private(set) var recent: [FeatureID]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recent = (defaults.stringArray(forKey: Self.key) ?? []).compactMap(FeatureID.init(rawValue:))
    }

    func opened(_ feature: FeatureID) {
        guard recent.first != feature else { return }
        recent = [feature] + recent.filter { $0 != feature }
        defaults.set(recent.map(\.rawValue), forKey: Self.key)
    }
}

/// The modules chosen for the swipe up, in their set order (spec QS-1…QS-12): sideways steps
/// the choice, lifting the fingers opens it, moving back down cancels.
@MainActor
final class ModuleSwitcher: ObservableObject {
    @Published private(set) var isShown = false
    @Published private(set) var items: [FeatureID] = []
    @Published private(set) var selection = 0

    let settings: SwitcherSettings
    /// The chosen modules, in the row's order, those that are off too (spec QS-10, QS-15).
    var candidates: () -> [FeatureID] = { [] }
    /// The module open in the notch under the pointer, if any.
    var current: () -> FeatureID? = { nil }
    /// Shows or hides the row in the notch.
    var present: (Bool) -> Void = { _ in }
    /// Opens the chosen module like its shortcut (spec QS-6).
    var open: (FeatureID) -> Void = { _ in }

    private var isPending = false
    private var showTimer: Timer?
    private var swipeStart = 0

    init(settings: SwitcherSettings) {
        self.settings = settings
    }

    var selected: FeatureID? { items.indices.contains(selection) ? items[selection] : nil }

    /// The row's most recently opened module, or the one before it if it is open now; without a
    /// history the first, or the second if the first is open (spec QS-11).
    nonisolated static func startIndex(_ items: [FeatureID], history: [FeatureID], current: FeatureID?) -> Int {
        let recent = history.filter(items.contains)
        let pick = current != nil && recent.first == current ? recent.dropFirst().first : recent.first
        if let pick, let index = items.firstIndex(of: pick) { return index }
        return items.count > 1 && current != nil && items.first == current ? 1 : 0
    }

    /// The tiles' scale that keeps every module in one row within `width` (spec QS-12).
    nonisolated static func rowScale(count: Int, scale: CGFloat, width: CGFloat) -> CGFloat {
        guard count > 0 else { return scale }
        let tiles = width - 2 * SwitcherLayout.padding - CGFloat(count - 1) * SwitcherLayout.spacing
        let tile = SwitcherLayout.tile(.icons, scale: 1).width
        return max(min(scale, tiles / (CGFloat(count) * tile)), 0.4)
    }

    /// The list is ready at once; it drops down only if the fingers stay (spec QS-7, AS-16).
    func swipeBegan() {
        guard settings.moduleSwitcherOn, !isShown, !isPending else { return }
        items = candidates()
        guard !items.isEmpty else { return }
        selection = Self.startIndex(items, history: ModuleHistory.shared.recent, current: current())
        swipeStart = selection
        isPending = true
        let delay = settings.showDelay
        guard delay > 0 else { return show() }
        showTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPending else { return }
                self.show()
            }
        }
    }

    private func show() {
        isPending = false
        stopTimer()
        isShown = true
        present(true)
    }

    /// One module per `settings.swipeStep` of sideways travel, stopping at either end (spec QS-5).
    func swipeMoved(travel: Double) {
        guard isShown || isPending, !items.isEmpty else { return }
        let steps = SwitcherController.steps(travel: travel, step: settings.swipeStep)
        selection = min(max(swipeStart + steps, 0), items.count - 1)
    }

    func swipeEnded(cancelled: Bool) {
        guard isShown || isPending else { return }
        let chosen = cancelled ? nil : selected
        DiagnosticsLog.append("spaces", "module switcher: \(chosen?.rawValue ?? "cancelled") quick=\(isPending)")
        finish(opening: chosen)
    }

    /// Hovering chooses, a click opens.
    func choose(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selection = index
    }

    func pick(_ index: Int) {
        guard items.indices.contains(index) else { return }
        finish(opening: items[index])
    }

    private func finish(opening chosen: FeatureID?) {
        let wasShown = isShown
        isPending = false
        isShown = false
        stopTimer()
        // The row gives way to the module itself, without closing first (spec QS-6).
        if wasShown, chosen == nil { present(false) }
        if let chosen { open(chosen) }
    }

    private func stopTimer() {
        showTimer?.invalidate()
        showTimer = nil
    }
}
