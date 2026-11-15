import Combine
import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var currentFeature: FeatureID
    /// True while the panel shows the full calendar and uses the large size.
    @Published private(set) var isLarge = false
    /// Horizontal nudge used for the "end of list" bounce (spec S-3).
    @Published private(set) var bounceOffset: CGFloat = 0
    @Published private(set) var lastDirection: NavigationDirection = .next

    let settings: AppSettings
    let geometry: NotchGeometry
    let screenName: String

    private var wantsLargeCalendar = false

    init(settings: AppSettings, geometry: NotchGeometry, screenName: String) {
        self.settings = settings
        self.geometry = geometry
        self.screenName = screenName
        currentFeature = settings.initialFeature
    }

    /// Size of the panel while it is open.
    var openSize: CGSize {
        isLarge ? geometry.largeSize : geometry.expandedSize
    }

    func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else { return }
        if expanded {
            // Re-check in case the remembered feature was disabled meanwhile (spec L-2).
            currentFeature = settings.initialFeature
        } else {
            wantsLargeCalendar = false
        }
        isExpanded = expanded
        updateLarge()
    }

    func setCalendarLarge(_ large: Bool) {
        wantsLargeCalendar = large
        updateLarge()
    }

    func select(_ feature: FeatureID) {
        guard feature != currentFeature else { return }
        let list = settings.activeFeatures
        if let fromIndex = list.firstIndex(of: currentFeature), let toIndex = list.firstIndex(of: feature) {
            lastDirection = toIndex > fromIndex ? .next : .previous
        }
        currentFeature = feature
        settings.lastFeature = feature
        updateLarge()
    }

    func step(_ direction: NavigationDirection) {
        if let target = FeatureID.neighbor(of: currentFeature, in: settings.activeFeatures, direction: direction) {
            lastDirection = direction
            currentFeature = target
            settings.lastFeature = target
            updateLarge()
        } else {
            bounce(direction)
        }
    }

    private func updateLarge() {
        let large = isExpanded && currentFeature == .calendar && wantsLargeCalendar
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
