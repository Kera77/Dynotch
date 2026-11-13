import Combine
import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var currentFeature: FeatureID
    @Published private(set) var geometry: NotchGeometry
    @Published private(set) var screenName: String
    /// Horizontal nudge used for the "end of list" bounce (spec S-3).
    @Published private(set) var bounceOffset: CGFloat = 0
    @Published private(set) var lastDirection: NavigationDirection = .next

    let settings: AppSettings

    init(settings: AppSettings, geometry: NotchGeometry, screenName: String) {
        self.settings = settings
        self.geometry = geometry
        self.screenName = screenName
        currentFeature = settings.initialFeature
    }

    func update(geometry: NotchGeometry, screenName: String) {
        self.geometry = geometry
        self.screenName = screenName
    }

    func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else { return }
        if expanded {
            // Re-check in case the remembered feature was disabled meanwhile (spec L-2).
            currentFeature = settings.initialFeature
        }
        isExpanded = expanded
    }

    func select(_ feature: FeatureID) {
        guard feature != currentFeature else { return }
        let list = settings.activeFeatures
        if let from = list.firstIndex(of: currentFeature), let to = list.firstIndex(of: feature) {
            lastDirection = to > from ? .next : .previous
        }
        currentFeature = feature
        settings.lastFeature = feature
    }

    func step(_ direction: NavigationDirection) {
        if let target = FeatureID.neighbor(of: currentFeature, in: settings.activeFeatures, direction: direction) {
            lastDirection = direction
            currentFeature = target
            settings.lastFeature = target
        } else {
            bounce(direction)
        }
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
