import Combine
import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var currentFeature: FeatureID
    /// True while the panel shows the full calendar and uses the large size.
    @Published private(set) var isLarge = false
    /// True while the panel shows the settings instead of the features (spec C-2).
    @Published private(set) var isShowingSettings = false
    /// Horizontal nudge used for the "end of list" bounce (spec S-3).
    @Published private(set) var bounceOffset: CGFloat = 0

    let settings: AppSettings
    let geometry: NotchGeometry
    let screenName: String

    init(settings: AppSettings, geometry: NotchGeometry, screenName: String) {
        self.settings = settings
        self.geometry = geometry
        self.screenName = screenName
        currentFeature = settings.initialFeature
    }

    /// Size of the panel while it is open.
    var openSize: CGSize {
        if isShowingSettings { return geometry.settingsSize }
        return isLarge ? geometry.largeSize : geometry.expandedSize
    }

    /// - Parameter showing: feature to open with instead of the remembered one (e.g. the
    ///   notifications when opened from a notification peek); it does not change what is remembered.
    func setExpanded(_ expanded: Bool, showing override: FeatureID? = nil) {
        guard expanded != isExpanded else { return }
        if expanded {
            // Re-check in case the remembered feature was disabled meanwhile (spec L-2).
            currentFeature = override.flatMap { settings.isEnabled($0) ? $0 : nil } ?? settings.initialFeature
        }
        if !expanded, isShowingSettings { isShowingSettings = false }
        isExpanded = expanded
        updateLarge()
    }

    func setCalendarLarge(_ large: Bool) {
        if settings.calendarLarge != large { settings.calendarLarge = large }
        updateLarge()
    }

    func setShowingSettings(_ showing: Bool) {
        guard isExpanded, showing != isShowingSettings else { return }
        isShowingSettings = showing
        updateLarge()
    }

    func select(_ feature: FeatureID) {
        // Picking a feature (even the current one) leaves the settings.
        if isShowingSettings { isShowingSettings = false }
        guard feature != currentFeature else {
            updateLarge()
            return
        }
        currentFeature = feature
        settings.lastFeature = feature
        updateLarge()
    }

    func step(_ direction: NavigationDirection) {
        if let target = FeatureID.neighbor(of: currentFeature, in: settings.activeFeatures, direction: direction) {
            currentFeature = target
            settings.lastFeature = target
            updateLarge()
        } else {
            bounce(direction)
        }
    }

    private func updateLarge() {
        let large = isExpanded && !isShowingSettings && currentFeature == .calendar && settings.calendarLarge
        if large != isLarge { isLarge = large }
    }

    private func bounce(_ direction: NavigationDirection) {
        let distance: CGFloat = direction == .next ? -14 : 14
        withAnimation(.easeOut(duration: 0.1)) { bounceOffset = distance }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { self?.bounceOffset = 0 }
        }
    }
}
