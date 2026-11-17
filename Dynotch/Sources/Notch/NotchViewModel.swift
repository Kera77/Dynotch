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
    /// The Claude chat has a conversation to show, so the panel is taller (spec CC-3).
    @Published private(set) var isChatTall = false
    /// The open panel only shows a preview of the current feature (spec PV-1).
    @Published private(set) var isPreview = false
    /// The new notifications the panel lists instead of the features (spec E-4); empty otherwise.
    @Published private(set) var notifications: [AppNotification] = []
    /// The listed notifications can be answered from the panel (spec E-11).
    @Published private(set) var notificationsCanReply = false

    var isShowingNotifications: Bool { !notifications.isEmpty }
    /// Lock in the top row: the panel stays open even when the pointer leaves it (spec SZ-8).
    @Published var isPinned = false
    /// The settings keep the panel open until the next click outside it (spec C-6).
    var holdsForSettings = false
    /// Countdown beside the closed notch under the pointer (spec K-8d).
    @Published var hoveredIndicator: Int?
    /// App badge beside the closed notch under the pointer (spec B-6).
    @Published var hoveredBadge: String?
    /// Right after a Space switch everything beside the closed notch is drawn in, then unfolds
    /// again (spec N-10).
    @Published private(set) var isGathered = false

    func setGathered(_ gathered: Bool) {
        if gathered != isGathered { isGathered = gathered }
    }

    /// A full-screen app is in front on this display: the closed notch is hidden (spec N-12).
    @Published private(set) var isHiddenForFullScreen = false

    func setHiddenForFullScreen(_ hidden: Bool) {
        if hidden != isHiddenForFullScreen { isHiddenForFullScreen = hidden }
    }

    /// Room left of the notch before the menu bar's own items; nil: no limit (spec B-8).
    @Published private(set) var badgeRoom: CGFloat?
    /// The badges behind the "+" are shown, while the pointer is on them.
    @Published private(set) var badgesUnfolded = false

    func setBadgeRoom(_ room: CGFloat?) {
        // Small changes (a clock ticking in the menu bar) do not move the badges.
        if let room, let current = badgeRoom, abs(room - current) < 2 { return }
        if room != badgeRoom { badgeRoom = room }
    }

    func setBadgesUnfolded(_ unfolded: Bool) {
        if unfolded != badgesUnfolded { badgesUnfolded = unfolded }
    }

    /// The first feature icon shown in the top row; the others are swiped into view (spec M-9).
    @Published private(set) var switcherFirst = 0

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
        isExpanded && !isPreview && (isShowingNotifications ? notificationsCanReply
            : isShowingSettings || [.calculator, .notes, .reminders, .notifications, .claudeChat].contains(currentFeature))
    }

    /// Size of the panel while it is open.
    var openSize: CGSize {
        // Room at the bottom for the reply field, or the "open to reply" button.
        if isShowingNotifications { return geometry.notificationSize(count: notifications.count, hasReply: true) }
        if isPreview { return geometry.previewSize }
        if isShowingSettings { return geometry.settingsSize }
        if currentFeature == .claudeUsage { return geometry.usageSize }
        if currentFeature == .claudeChat { return isChatTall ? geometry.chatSize : geometry.expandedSize }
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
        if !expanded { holdsForSettings = false }
        if !expanded, isPinned { isPinned = false }
        if !expanded, isPreview { isPreview = false }
        isExpanded = expanded
        updateLarge()
    }

    func setCalendarLarge(_ large: Bool) {
        if settings.calendarLarge != large { settings.calendarLarge = large }
        updateLarge()
    }

    func setPreview(_ preview: Bool) {
        guard isExpanded, !isShowingNotifications, preview != isPreview else { return }
        isPreview = preview
    }

    func setChatTall(_ tall: Bool) {
        if tall != isChatTall { isChatTall = tall }
    }

    func setShowingSettings(_ showing: Bool) {
        guard isExpanded, showing != isShowingSettings else { return }
        if isPreview { isPreview = false }
        isShowingSettings = showing
        updateLarge()
    }

    func select(_ feature: FeatureID) {
        // Picking a feature (even the current one) leaves the settings and the preview.
        if isShowingSettings { isShowingSettings = false }
        holdsForSettings = false
        if isPreview { isPreview = false }
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

    /// How many feature icons fit left of the notch in the open panel.
    var switcherVisibleCount: Int {
        // The row's left side, less its margins (14 at the edge, 8 before the notch).
        let room = (openSize.width - geometry.notchSize.width) / 2 - 22
        return FeatureSwitcher.visibleCount(for: room)
    }

    /// Swipes the icons without switching features.
    func scrollSwitcher(by steps: Int) {
        let count = settings.activeFeatures.count
        let next = FeatureSwitcher.clampedFirst(switcherFirst + steps, count: count, visible: switcherVisibleCount)
        if next != switcherFirst { switcherFirst = next }
    }

    /// The current feature's icon is in view.
    func revealCurrentFeature() {
        let features = settings.activeFeatures
        guard let index = features.firstIndex(of: currentFeature) else { return }
        let visible = switcherVisibleCount
        var first = FeatureSwitcher.clampedFirst(switcherFirst, count: features.count, visible: visible)
        if index < first { first = index }
        if index >= first + visible { first = index - visible + 1 }
        if first != switcherFirst { switcherFirst = first }
    }

    private func updateLarge() {
        let large = isExpanded && !isShowingNotifications && !isShowingSettings
            && ([.notes, .reminders].contains(currentFeature) || (currentFeature == .calendar && settings.calendarLarge))
        if large != isLarge { isLarge = large }
        revealCurrentFeature()
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
