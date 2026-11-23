import AppKit
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
    @Published private(set) var isPreview = false { didSet { if !isPreview, wings != WingsState() { wings = WingsState() } } }
    /// What the Wings' content asks of the panel: wider, the hovered app or clip (spec PV-31…PV-35).
    @Published var wings = WingsState()
    /// What outlives one opening of the Wings: each side's need, the reminders ticked (spec PV-24, PV-33).
    @Published var wingsLasting = WingsLasting()
    /// The new notifications the panel lists instead of the features (spec E-4); empty otherwise.
    @Published private(set) var notifications: [AppNotification] = []
    /// The listed notifications can be answered from the panel (spec E-11).
    @Published private(set) var notificationsCanReply = false
    /// The hovered card's measured height; nil: by the number of messages.
    private(set) var notificationsHeight: CGFloat?

    var isShowingNotifications: Bool { !notifications.isEmpty }
    /// Lock in the top row: the panel stays open even when the pointer leaves it (spec SZ-8).
    @Published var isPinned = false
    /// The settings keep the panel open until the next click outside it (spec C-6).
    var holdsForSettings = false
    /// A click into a reply or text field keeps the panel open when the pointer leaves, until
    /// the next click outside it (spec E-21); the lock (isPinned) stays until it is released.
    var holdsForTyping = false
    /// Held open until a click outside: by the settings or by typing.
    var isHeldByClick: Bool { holdsForSettings || holdsForTyping }
    /// A tray file's Quick Look is open: the notch stays whatever the pointer does (spec FT-8b).
    var holdsForPreview = false
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

    /// The modules show under the closed notch (spec MS-1).
    @Published private(set) var isShowingStrip = false

    /// Where the pointer was when the strip came (spec MS-1b).
    var stripOrigin: CGFloat = 0

    func setStripShown(_ shown: Bool) {
        if shown != isShowingStrip { isShowingStrip = shown }
    }

    /// Closes the panel; set by the controller (spec AI-7).
    var requestCollapse: () -> Void = {}
    /// Looks again whether the pointer still keeps the open panel (spec PV-54).
    var recheckPointer: () -> Void = {}

    /// Events that already opened their module by the smart opening (spec SO-3).
    var smartUsed: Set<String> = []

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
    /// The tab last shown of each merged module, by its host (spec MG-2).
    private var lastTabs: [FeatureID: FeatureID] = [:]

    /// Merged, the AI tabs sit in the header beside the chat list, which needs the medium width (spec MG-2).
    private func mergedAIWidth(_ size: CGSize) -> CGSize {
        settings.isMerged(.claudeUsage) ? CGSize(width: max(size.width, geometry.mediumSize.width), height: size.height) : size
    }

    /// The page a merged module's icon opens: the tab last shown, while it is still merged.
    func lastTab(of feature: FeatureID) -> FeatureID {
        guard let tabs = settings.mergedTabs(for: feature), feature == tabs[0],
              let last = lastTabs[feature], tabs.contains(last) else { return feature }
        return last
    }

    /// Horizontal nudge used for the "end of list" bounce (spec S-3).
    @Published private(set) var bounceOffset: CGFloat = 0

    let settings: AppSettings
    let geometry: NotchGeometry
    let screenName: String
    let moduleSizes: ModuleSizes
    /// The size while the resize handle is dragged; saved when the drag ends (spec RS-1).
    @Published var resizingSize: CGSize?

    init(settings: AppSettings, geometry: NotchGeometry, screenName: String, moduleSizes: ModuleSizes = ModuleSizes()) {
        self.settings = settings
        self.moduleSizes = moduleSizes
        self.geometry = geometry
        self.screenName = screenName
        currentFeature = settings.initialFeature
    }

    /// The panel needs keyboard focus: for the settings' controls and for typing calculations.
    var wantsKeyboard: Bool {
        // The screenshot editor types text and takes ⌘Z and Esc (spec SH-7).
        if editor != nil { return true }
        guard !isShowingOverlayPage else { return false }
        return isExpanded && !isPreview && (isShowingNotifications ? notificationsCanReply
            : isShowingSettings || Self.typingFeatures.contains(currentFeature))
    }

    /// Modules that take the keyboard (text fields, Space for Quick Look).
    private static let typingFeatures: Set<FeatureID> = [
        .calculator, .notes, .reminders, .notifications, .claudeChat, .clipboard, .tray, .terminal
    ]

    /// The notifications module's tab, kept across launches (spec UM-8).
    @Published var notificationsTab: NotificationsTab = NotchViewModel.storedTab {
        didSet { UserDefaults.standard.set(notificationsTab.rawValue, forKey: Self.tabKey) }
    }

    private static let tabKey = "notificationsTab"
    /// The pointer is over the notifications' tab picker (spec UM-8d); not published, read by the swipe.
    var isOverNotificationsTabs = false
    private static var storedTab: NotificationsTab {
        UserDefaults.standard.string(forKey: tabKey).flatMap(NotificationsTab.init(rawValue:)) ?? .all
    }

    /// Swiping steps through the tabs first (spec UM-8); false at either end.
    func stepNotificationsTab(by offset: Int) -> Bool {
        let tabs = NotificationsTab.shown(mail: settings.mailSource == .appleMail, networks: BeeperService.storedHighlights())
        guard let index = tabs.firstIndex(of: notificationsTab), tabs.indices.contains(index + offset) else { return false }
        notificationsTab = tabs[index + offset]
        updateLarge()
        return true
    }

    /// The clipboard's items while its shortcut is held (spec CB-3).
    @Published private(set) var isShowingClipboardPicker = false
    /// Files are being dragged over the notch (spec FT-1).
    /// Mission Control is showing: no hover opening (spec N-19).
    @Published var isHiddenForMissionControl = false
    /// The Beeper tab's chat list is open: only then does it need the wide panel (spec BP-1d).
    @Published var beeperListOpen = true

    var showsWideTab: Bool {
        notificationsTab.isWide && (notificationsTab != .beeper || beeperListOpen)
    }

    /// The screen is shared or recorded: nothing appears by itself (spec N-21).
    @Published var isScreenShared = false
    @Published private(set) var isShowingDropZone = false

    /// A page that replaces the modules for a moment.
    /// The clipboard's items under the open module, not instead of it (spec CB-3c).
    @Published private(set) var isClipboardInline = false
    static let inlinePickerHeight: CGFloat = 150

    /// The window switcher in the notch (spec AS-6), and its measured size.
    @Published private(set) var isShowingSwitcher = false
    private(set) var switcherSize = CGSize.zero
    /// The glass (and its shadow) waits while the switcher moves: it would trail behind (spec AS-18).
    @Published var hidesGlass = false

    func setSwitcher(_ shown: Bool, size: CGSize = .zero) {
        if shown { switcherSize = size }
        if shown != isShowingSwitcher { isShowingSwitcher = shown }
    }

    /// The screenshot editor, large in the notch (spec SH-7).
    @Published private(set) var editor: ScreenshotEditor?
    /// Opened from the pop-up: closing it closes the notch too.
    private(set) var editorClosesNotch = false
    /// The app that had the keyboard before the editor took it; it gets it back on closing (spec SH-7b).
    var appBeforeEditor: NSRunningApplication?

    func setEditor(_ editor: ScreenshotEditor?, closesNotch: Bool = false) {
        self.editor = editor
        editorClosesNotch = editor != nil && closesNotch
    }

    func setClipboardPicker(_ shown: Bool, inline: Bool = false) {
        if shown != isShowingClipboardPicker { isShowingClipboardPicker = shown }
        if (shown && inline) != isClipboardInline { isClipboardInline = shown && inline }
    }

    func setDropZone(_ shown: Bool) {
        if shown != isShowingDropZone { isShowingDropZone = shown }
    }

    /// Size of the panel while it is open: the module's resized size, or its normal one.
    var openSize: CGSize {
        let size = canResize ? (resizingSize ?? savedModuleSize ?? normalOpenSize) : normalOpenSize
        return isClipboardInline ? CGSize(width: size.width, height: size.height + Self.inlinePickerHeight) : size
    }

    /// Size of the panel while it is open, without a resized module (spec RS-1).
    var normalOpenSize: CGSize {
        // Room at the bottom for the reply field, or the "open to reply" button.
        if isShowingNotifications {
            let size = geometry.notificationSize(count: notifications.count, hasReply: true)
            return CGSize(width: size.width, height: notificationsHeight ?? size.height)
        }
        if isShowingSwitcher { return switcherSize }
        if editor != nil { return geometry.maxModuleSize }
        // Files over the wings: they stay at the notch's height (spec PV-14).
        if isShowingDropZone, isPreview { return geometry.previewSize(side: WingsDropView.side) }
        if isShowingOverlayPage {
            return CGSize(width: geometry.expandedSize.width, height: geometry.notchSize.height + (isShowingDropZone ? 150 : 170))
        }
        if isPreview { return geometry.wingsSize(wingsSides) }
        // Settings first: over the wide chat tabs they got that lower panel and pushed the top row
        // out of sight (spec C-11).
        if isShowingSettings { return geometry.settingsSize }
        if currentFeature == .notifications, showsWideTab { return geometry.chatPanelSize }
        // Room for the tab picker above a card (spec UM-8c).
        if currentFeature == .notifications, !isLarge { return geometry.notificationsModuleSize }
        if currentFeature == .claudeUsage { return mergedAIWidth(geometry.usageSize) }
        if currentFeature == .claudeChat { return isChatTall ? geometry.chatSize : mergedAIWidth(geometry.expandedSize) }
        if isLarge, [.notes, .reminders].contains(currentFeature) { return geometry.mediumSize }
        // The stats' tiles and process list need the room (spec SY-1).
        if currentFeature == .stats { return geometry.mediumSize }
        return isLarge ? geometry.largeSize : geometry.expandedSize
    }

    /// - Parameters:
    ///   - presenting: new notifications to list instead of the features (opened from a
    ///     notification peek); the remembered feature is not changed.
    ///   - canReply: whether the list gets a reply field.
    /// - Parameter stackHeight: the hovered card's height for its texts (spec E-23).
    func setExpanded(
        _ expanded: Bool, presenting presented: [AppNotification] = [], canReply: Bool = false, stackHeight: CGFloat? = nil
    ) {
        guard expanded != isExpanded else { return }
        if expanded {
            // Re-check in case the remembered feature was disabled meanwhile (spec L-2).
            currentFeature = settings.initialFeature
        }
        notifications = expanded ? presented : []
        notificationsCanReply = expanded && !presented.isEmpty && canReply
        notificationsHeight = expanded ? stackHeight : nil
        if !expanded, isShowingSettings { isShowingSettings = false }
        if !expanded {
            holdsForSettings = false
            holdsForTyping = false
            holdsForPreview = false
        }
        if !expanded {
            isShowingSwitcher = false
            editor = nil
            isShowingClipboardPicker = false
            isClipboardInline = false
        }
        if !expanded { isShowingDropZone = false }
        if expanded, isShowingStrip { isShowingStrip = false }
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

    /// - Parameter remember: false for a module opened by its shortcut: the next hover still opens
    ///   the one used last in the notch (spec SC-4).
    /// - Parameter exact: a merged module's tab picks its page; otherwise its icon opens its last tab (spec MG-2).
    func select(_ requested: FeatureID, remember: Bool = true, exact: Bool = false) {
        // Picking a feature (even the current one) leaves the settings and the preview.
        if isShowingSettings { isShowingSettings = false }
        holdsForSettings = false
        if isPreview { isPreview = false }
        let feature = exact ? requested : lastTab(of: requested)
        guard feature != currentFeature else {
            updateLarge()
            return
        }
        currentFeature = feature
        if remember { settings.lastFeature = feature }
        updateLarge()
    }

    /// Moves `steps` modules at once, stopping at either end (spec S-1, M-12); the icon stays in view.
    func step(by steps: Int) {
        let features = settings.listedFeatures
        guard let index = features.firstIndex(of: settings.hostFeature(of: currentFeature)) else { return }
        let target = min(max(index + steps, 0), features.count - 1)
        guard target != index else { return bounce(steps > 0 ? .next : .previous) }
        currentFeature = lastTab(of: features[target])
        settings.lastFeature = currentFeature
        updateLarge()
        revealCurrentFeature()
    }

    /// How many feature icons fit left of the notch in the open panel.
    var switcherVisibleCount: Int {
        // The row's left side, less its margins (14 at the edge, 8 before the notch).
        let room = (openSize.width - geometry.notchSize.width) / 2 - 22
        return FeatureSwitcher.visibleCount(for: room)
    }

    /// The current feature's icon is in view.
    func revealCurrentFeature() {
        let features = settings.listedFeatures
        guard let index = features.firstIndex(of: settings.hostFeature(of: currentFeature)) else { return }
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
        if settings.mergedTabs(for: currentFeature) != nil { lastTabs[settings.hostFeature(of: currentFeature)] = currentFeature }
        revealCurrentFeature()
    }

    private func bounce(_ direction: NavigationDirection) {
        let distance: CGFloat = direction == .next ? -14 : 14
        withAnimation(.easeOut(duration: 0.1)) { bounceOffset = distance }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(AppleStyle.spring(response: 0.3, dampingFraction: 0.5)) { self?.bounceOffset = 0 }
        }
    }
}

extension NotchViewModel {
    /// Anything that keeps the open panel from closing when the pointer leaves.
    var keepsOpen: Bool {
        isPinned || isHeldByClick || holdsForPreview || isShowingClipboardPicker || editor != nil || holdsForTerminal
    }
}

extension NotchViewModel {
    var isShowingOverlayPage: Bool {
        (isShowingClipboardPicker && !isClipboardInline) || isShowingDropZone || isShowingSwitcher || editor != nil
    }
}
