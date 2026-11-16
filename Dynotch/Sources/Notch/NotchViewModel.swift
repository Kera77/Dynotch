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
    /// The new notifications the panel lists instead of the features (spec E-4); empty otherwise.
    @Published private(set) var notifications: [AppNotification] = []
    /// The listed notifications can be answered from the panel (spec E-11).
    @Published private(set) var notificationsCanReply = false

    var isShowingNotifications: Bool { !notifications.isEmpty }
    /// Lock in the top row: the panel stays open even when the pointer leaves it (spec SZ-8).
    @Published var isPinned = false
    /// Countdown beside the closed notch under the pointer (spec K-8d).
    @Published var hoveredIndicator: Int?
    /// App badge beside the closed notch under the pointer (spec B-6).
    @Published var hoveredBadge: String?
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

    /// The panel needs keyboard focus: for the settings' controls and for typing calculations.
    var wantsKeyboard: Bool {
        isExpanded && (isShowingNotifications ? notificationsCanReply
            : isShowingSettings || [.calculator, .notes, .reminders, .notifications].contains(currentFeature))
    }

    /// Size of the panel while it is open.
    var openSize: CGSize {
        // Room at the bottom for the reply field, or the "open to reply" button.
        if isShowingNotifications { return geometry.notificationSize(count: notifications.count, hasReply: true) }
        if isShowingSettings { return geometry.settingsSize }
        if currentFeature == .claudeUsage { return geometry.usageSize }
        if isLarge, [.notes, .reminders].contains(currentFeature) { return geometry.mediumSize }
        return isLarge ? geometry.largeSize : geometry.expandedSize
    }

    /// - Parameters:
    ///   - presenting: new notifications to list instead of the features (opened from a
    ///     notification peek); the remembered feature is not changed.
    ///   - canReply: whether the list gets a reply field.
    func setExpanded(_ expanded: Bool, presenting presented: [AppNotification] = [], canReply: Bool = false) {
        guard expanded != isExpanded else { return }
        if expanded {
            // Re-check in case the remembered feature was disabled meanwhile (spec L-2).
            currentFeature = settings.initialFeature
        }
        notifications = expanded ? presented : []
        notificationsCanReply = expanded && !presented.isEmpty && canReply
        if !expanded, isShowingSettings { isShowingSettings = false }
        if !expanded, isPinned { isPinned = false }
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
        let large = isExpanded && !isShowingNotifications && !isShowingSettings
            && ([.notes, .reminders].contains(currentFeature) || (currentFeature == .calendar && settings.calendarLarge))
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
