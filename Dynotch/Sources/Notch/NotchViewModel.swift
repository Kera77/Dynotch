import AppKit
import SwiftUI

@MainActor
@Observable
final class NotchViewModel {
    private(set) var isExpanded = false { didSet { noteOpened() } }
    private(set) var currentFeature: FeatureID { didSet { noteOpened() } }
    /// True while the panel shows the full calendar and uses the large size.
    private(set) var isLarge = false { didSet { onLargeChange(isLarge) } }
    /// True while the panel shows the settings instead of the features (spec C-2).
    private(set) var isShowingSettings = false
    /// Only the quick toggles, from their top-row button (spec QT-6).
    private(set) var isShowingToggles = false
    /// The Claude chat has a conversation to show, so the panel is taller (spec CC-3).
    private(set) var isChatTall = false
    /// The open panel only shows a preview of the current feature (spec PV-1).
    private(set) var isPreview = false { didSet { if !isPreview, wings != WingsState() { wings = WingsState() }; noteOpened() } }
    /// What the Wings' content asks of the panel: wider, the hovered app or clip (spec PV-31…PV-35).
    var wings = WingsState()
    /// What outlives one opening of the Wings: each side's need, the reminders ticked (spec PV-24, PV-33).
    var wingsLasting = WingsLasting()
    /// The new notifications the panel lists instead of the features (spec E-4); empty otherwise.
    private(set) var notifications: [AppNotification] = []
    /// The listed notifications can be answered from the panel (spec E-11).
    private(set) var notificationsCanReply = false
    /// The hovered card's measured height; nil: by the number of messages.
    @ObservationIgnored private(set) var notificationsHeight: CGFloat?

    var isShowingNotifications: Bool { !notifications.isEmpty }
    /// What's new, opened from its notice under the notch (spec WN-6).
    private(set) var whatsNew: [WhatsNewRelease] = []

    func showWhatsNew(_ releases: [WhatsNewRelease]) {
        whatsNew = releases
    }
    /// The first-launch tour fills the open panel until it ends (spec OB-36).
    var showsTour = false
    /// Lock in the top row: the panel stays open even when the pointer leaves it (spec SZ-8).
    var isPinned = false
    /// The settings keep the panel open until the next click outside it (spec C-6).
    @ObservationIgnored var holdsForSettings = false
    /// A click into a reply or text field keeps the panel open when the pointer leaves, until
    /// the next click outside it (spec E-21); the lock (isPinned) stays until it is released.
    @ObservationIgnored var holdsForTyping = false
    /// Held open until a click outside: by the settings or by typing.
    var isHeldByClick: Bool { holdsForSettings || holdsForTyping }
    /// A tray file's Quick Look is open: the notch stays whatever the pointer does (spec FT-8b).
    @ObservationIgnored var holdsForPreview = false
    /// Countdown beside the closed notch under the pointer (spec K-8d).
    var hoveredIndicator: Int?
    /// App badge beside the closed notch under the pointer (spec B-6).
    var hoveredBadge: String?
    /// Right after a Space switch everything beside the closed notch is drawn in, then unfolds
    /// again (spec N-10).
    private(set) var isGathered = false

    func setGathered(_ gathered: Bool) {
        if gathered != isGathered { isGathered = gathered }
    }

    /// The modules show under the closed notch (spec MS-1).
    private(set) var isShowingStrip = false

    /// Where the pointer was when the strip came (spec MS-1b).
    var stripOrigin: CGFloat = 0

    func setStripShown(_ shown: Bool) {
        if shown != isShowingStrip { isShowingStrip = shown }
    }

    /// Told when the large size comes or goes (the panel keeps the pointer inside for a moment).
    @ObservationIgnored var onLargeChange: (Bool) -> Void = { _ in }
    /// Closes the panel; set by the controller (spec AI-7).
    @ObservationIgnored var requestCollapse: () -> Void = {}
    /// The panel takes the keyboard for a reply field focused by itself (spec E-27).
    @ObservationIgnored var requestKeyboard: () -> Void = {}
    /// Looks again whether the pointer still keeps the open panel (spec PV-54).
    @ObservationIgnored var recheckPointer: () -> Void = {}

    /// Events that already opened their module by the smart opening (spec SO-3).
    @ObservationIgnored var smartUsed: Set<String> = []

    /// A full-screen app is in front on this display: the closed notch is hidden (spec N-12).
    private(set) var isHiddenForFullScreen = false

    func setHiddenForFullScreen(_ hidden: Bool) {
        if hidden != isHiddenForFullScreen { isHiddenForFullScreen = hidden }
    }

    /// Room left of the notch before the menu bar's own items; nil: no limit (spec B-8).
    private(set) var badgeRoom: CGFloat?
    /// The badges behind the "+" are shown, while the pointer is on them.
    private(set) var badgesUnfolded = false

    func setBadgeRoom(_ room: CGFloat?) {
        // Small changes (a clock ticking in the menu bar) do not move the badges.
        if let room, let current = badgeRoom, abs(room - current) < 2 { return }
        if room != badgeRoom { badgeRoom = room }
    }

    func setBadgesUnfolded(_ unfolded: Bool) {
        if unfolded != badgesUnfolded { badgesUnfolded = unfolded }
    }

    /// The first feature icon shown in the top row; the others are swiped into view (spec M-9).
    private(set) var switcherFirst = 0

    /// The page a merged module opens on: the tab last picked by hand, else the host's own
    /// (System, Chat), kept across restarts (spec MG-10).
    func lastTab(of feature: FeatureID) -> FeatureID {
        guard let tabs = settings.mergedTabs(for: feature), feature == tabs[0],
              let last = settings.chosenTab(of: feature), tabs.contains(last) else { return feature }
        return last
    }

    /// A swipe over the icons is passing through the modules: the pages around this one stay
    /// built, the others show their snapshots until it settles (spec M-20). nil: pages follow the current module.
    var liveCenter: FeatureID?
    let passing = PagePassing()

    /// Horizontal nudge used for the "end of list" bounce (spec S-3).
    private(set) var bounceOffset: CGFloat = 0

    let settings: AppSettings
    let geometry: NotchGeometry
    let screenName: String
    let moduleSizes: ModuleSizes
    /// The size while the resize handle is dragged; saved when the drag ends (spec RS-1).
    var resizingSize: CGSize?

    init(settings: AppSettings, geometry: NotchGeometry, screenName: String, moduleSizes: ModuleSizes = ModuleSizes()) {
        self.settings = settings
        self.moduleSizes = moduleSizes
        self.geometry = geometry
        self.screenName = screenName
        currentFeature = settings.initialFeature
        currentFeature = lastTab(of: settings.hostFeature(of: settings.initialFeature))
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
    var notificationsTab: NotificationsTab = NotchViewModel.storedTab {
        didSet { UserDefaults.standard.set(notificationsTab.rawValue, forKey: Self.tabKey) }
    }

    private static let tabKey = "notificationsTab"
    /// The pointer is over the notifications' tab picker (spec UM-8d); not published, read by the swipe.
    @ObservationIgnored var isOverNotificationsTabs = false
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
    private(set) var isShowingClipboardPicker = false
    /// Files are being dragged over the notch (spec FT-1).
    /// Mission Control is showing: no hover opening (spec N-19).
    var isHiddenForMissionControl = false
    /// The Beeper tab's chat list is open: only then does it need the wide panel (spec BP-1d).
    var beeperListOpen = true

    /// The screen is shared or recorded: nothing appears by itself (spec N-21).
    var isScreenShared = false
    private(set) var isShowingDropZone = false

    /// A page that replaces the modules for a moment.
    /// The clipboard's items under the open module, not instead of it (spec CB-3c).
    private(set) var isClipboardInline = false
    static let inlinePickerHeight: CGFloat = 150

    /// The window switcher in the notch (spec AS-6), and its measured size.
    private(set) var isShowingSwitcher = false
    @ObservationIgnored private(set) var switcherSize = CGSize.zero
    /// The glass (and its shadow) waits while the switcher moves: it would trail behind (spec AS-18).
    var hidesGlass = false

    /// The switcher's place shows the modules instead of the windows (spec QS-4).
    private(set) var showsModuleSwitcher = false

    func setSwitcher(_ shown: Bool, size: CGSize = .zero, modules: Bool = false) {
        if shown { switcherSize = size }
        if shown != isShowingSwitcher { isShowingSwitcher = shown }
        if (shown && modules) != showsModuleSwitcher { showsModuleSwitcher = shown && modules }
    }

    /// The screenshot editor, large in the notch (spec SH-7).
    private(set) var editor: ScreenshotEditor?
    /// Opened from the pop-up: closing it closes the notch too.
    @ObservationIgnored private(set) var editorClosesNotch = false
    /// The app that had the keyboard before the editor took it; it gets it back on closing (spec SH-7b).
    @ObservationIgnored var appBeforeEditor: NSRunningApplication?

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
            // A merged module opens on its picked tab, not on the one an alert showed (spec MG-10).
            currentFeature = lastTab(of: settings.hostFeature(of: settings.initialFeature))
        }
        notifications = expanded ? presented : []
        notificationsCanReply = expanded && !presented.isEmpty && canReply
        notificationsHeight = expanded ? stackHeight : nil
        if !expanded {
            leavePages()
            if settings.visitingFeature != nil { settings.visitingFeature = nil }
            holdsForSettings = false
            holdsForTyping = false
            holdsForPreview = false
        }
        if !expanded {
            isShowingSwitcher = false
            showsModuleSwitcher = false
            editor = nil
            isShowingClipboardPicker = false
            isClipboardInline = false
            whatsNew = []
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
        if showing, isShowingToggles { isShowingToggles = false }
        updateLarge()
    }

    /// A closed notch opens on its module again, not on the settings or the toggles.
    private func leavePages() {
        if isShowingSettings { isShowingSettings = false }
        if isShowingToggles { isShowingToggles = false }
    }

    /// The quick toggles' page on or off; it leaves the settings (spec QT-6).
    func setShowingToggles(_ showing: Bool) {
        guard isExpanded, showing != isShowingToggles else { return }
        if isPreview { isPreview = false }
        if showing, isShowingSettings { isShowingSettings = false }
        isShowingToggles = showing
        updateLarge()
    }

    /// - Parameter remember: false for a module opened by its shortcut: the next hover still opens
    ///   the one used last in the notch (spec SC-4).
    /// - Parameter exact: a merged module's tab picks its page; otherwise its icon opens its last tab (spec MG-2).
    func select(_ requested: FeatureID, remember: Bool = true, exact: Bool = false) {
        // Picking a feature (even the current one) leaves the settings and the preview.
        if isShowingSettings { isShowingSettings = false }
        if isShowingToggles { isShowingToggles = false }
        holdsForSettings = false
        if isPreview { isPreview = false }
        let feature = exact ? requested : lastTab(of: requested)
        guard feature != currentFeature else {
            updateLarge()
            return
        }
        leavePage()
        Signposts.moduleSwitch(to: feature)
        currentFeature = feature
        if remember { settings.lastFeature = feature }
        updateLarge()
    }

    /// Moves `steps` modules at once, stopping at either end (spec S-1, M-12); the icon stays in view.
    func step(by steps: Int, passing isPassing: Bool = false) {
        let features = settings.listedFeatures
        guard let index = features.firstIndex(of: settings.hostFeature(of: currentFeature)) else { return }
        let target = min(max(index + steps, 0), features.count - 1)
        guard target != index else { return bounce(steps > 0 ? .next : .previous) }
        if isShowingToggles { isShowingToggles = false }
        leavePage(passing: isPassing)
        Signposts.moduleSwitch(to: features[target])
        currentFeature = lastTab(of: features[target])
        settings.lastFeature = currentFeature
        updateLarge()
        revealCurrentFeature()
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
        let large = isExpanded && !isShowingNotifications && !isShowingSettings && !isShowingToggles
            && ([.notes, .reminders].contains(currentFeature) || (currentFeature == .calendar && settings.calendarLarge))
        if large != isLarge { isLarge = large }
        revealCurrentFeature()
    }

    private func bounce(_ direction: NavigationDirection) {
        let distance: CGFloat = direction == .next ? -14 : 14
        // Springs back once the push has ended (spec RF-14).
        animate(.easeOut(duration: 0.1), atMost: 0.15) { bounceOffset = distance } completion: { [weak self] in
            withAnimation(AppleStyle.spring(response: 0.3, dampingFraction: 0.5)) { self?.bounceOffset = 0 }
        }
    }
}

extension NotchViewModel {
    /// Anything that keeps the open panel from closing when the pointer leaves.
    var keepsOpen: Bool {
        isPinned || isHeldByClick || holdsForPreview || isShowingClipboardPicker || editor != nil || holdsForTerminal || showsTour
    }
}

extension NotchViewModel {
    var isShowingOverlayPage: Bool {
        (isShowingClipboardPicker && !isClipboardInline) || isShowingDropZone || isShowingSwitcher || editor != nil || !whatsNew.isEmpty
            || showsTour
    }
}
