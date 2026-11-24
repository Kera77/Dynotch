import SwiftUI

struct NotchView: View {
    @Bindable var model: NotchViewModel
    var settings: AppSettings
    var wallpaperTone = WallpaperTone.shared
    /// The day view watches the calendar itself; the notch only the meetings beside it.
    let calendar: CalendarService
    var calendarIndicator: CalendarIndicator
    var notifications: NotificationService
    let calculator: CalculatorStore
    let notes: NotesStore
    let reminders: RemindersStore
    var tasks: TaskIndicator
    var claudeUsage: ClaudeUsageService
    var hud: HUDService
    var badges: BadgeService
    var calls: CallService
    var keyboardLock: KeyboardLock
    var notices: NoticeService
    /// Watched by its own views: every streamed word and keystroke of the chat used to redraw
    /// the whole notch. The notch only needs whether it works.
    let chat: ClaudeChatService
    var chatIndicator: ChatIndicator
    var battery: BatteryService
    let shortcuts: ShortcutStore
    let updates: UpdateService
    /// Watched by its own views, not by the whole notch (spec N-16).
    let tablets: TabletDisplayService
    /// The content's window, or the glass window behind it (spec D-6).
    var layer = DesignLayer.content
    let clipboard: ClipboardStore
    /// Watched by its own views, not by the whole notch (spec N-16).
    let clipboardPicker: ClipboardPicker
    /// The window switcher (spec AS-6); set after creation.
    var switcher: SwitcherController?
    /// Watched by its own views, not by the whole notch (spec N-16).
    let tray: TrayStore
    /// Watched by its own views, not by the whole notch (spec N-16).
    /// Observed: its unread chats show in the Notifications wings (spec PV-52).
    var beeper: BeeperService
    var devices: DeviceWatcher
    /// Only whether a cover or a value shows beside the notch; the numbers are watched by their
    /// own views (spec MU-2, SY-7).
    var musicIndicator: MusicIndicator
    var statsIndicator: StatsIndicator
    let music: MusicService
    let stats: StatsService
    /// The mode chooser, the pop-up after a shot and the recording (spec SH-1, SH-6, SH-5).
    var screenshots: ScreenshotService
    /// Gear button: opens the settings in the notch or in a window, as configured.
    let toggleSettings: () -> Void
    /// Closes the notification card (spec E-12).
    var closeNotifications: () -> Void = {}
    /// Clears every notification and closes the card (spec E-12).
    var clearNotifications: () -> Void = {}
    /// A right click on an app badge: its unopened notifications (spec B-6).
    var showBadgeNotifications: (BadgeItem) -> Void = { _ in }
    /// A line of a badge's drop-down: that chat, open and ready to answer (spec B-10f).
    var openBadgeChat: (BadgeItem, BadgeNotificationRow) -> Void = { _, _ in }
    /// Opens the whole panel from the preview (spec PV-3).
    var openFully: () -> Void = {}
    var backToWings: () -> Void = {}
    /// A module picked in the strip under the closed notch (spec MS-3).
    var openModule: (FeatureID) -> Void = { _ in }
    /// The notice under the closed notch clicked (spec CN-6).
    var openNotice: () -> Void = {}
    /// The X of a notice beside the notch: it swims into the notch (spec PV-48); a notification's
    /// bin deletes it from Dynotch (spec PV-55).
    var dismissNotice: () -> Void = {}
    /// A meeting joined from its row under the closed notch (spec K-8k).
    var joinedMeeting: (CalendarEvent) -> Void = { _ in }
    /// Files dropped on the notch's "Keep" / "AirDrop" targets (spec FT-1, FT-3).
    var keepInTray: ([URL]) -> Void = { _ in }
    var sendWithAirDrop: ([URL]) -> Void = { _ in }
    /// Opens a screenshot in the editor, and closes the editor (spec SH-7, SH-11).
    var editScreenshot: (URL) -> Void = { _ in }
    var closeScreenshotEditor: () -> Void = {}

    /// Content fades in and slides down a little with the background. Not scaled: text drawn
    /// while scaled stayed blurry until the next redraw (spec N-17).
    private static let contentTransition: AnyTransition =
        .opacity.combined(with: .offset(y: -10))

    var geometry: NotchGeometry { model.geometry }

    /// The badges that fit beside the menu bar, and how many wait behind the "+" (spec B-8).
    var badgeFit: BadgeFit {
        BadgeFit.make(badges: badges.visible, items: indicatorItems, room: model.badgeRoom, unfolded: model.badgesUnfolded)
    }

    private var indicatorLayout: IndicatorLayout {
        let fit = badgeFit
        return IndicatorLayout(items: indicatorItems, badges: fit.shown, overflow: fit.hidden > 0)
    }

    /// The closed notch with countdowns is asymmetric: keep the physical notch in place.
    var collapsedOffset: CGFloat {
        // The Wings are as wide on each side as their content (spec PV-24).
        if model.isExpanded { return model.openOffset }
        // Beside the notch each side is as wide as its content; the notch stays (spec PV-38).
        if wingsPeek != nil { return isGathered ? 0 : model.peekSides.offset }
        // A notification keeps the row where it is and drops down under it (spec E-24b).
        guard devices.current == nil, hud.display == nil, calls.call == nil, !isGathered,
              !showsScreenshotPeek
        else { return 0 }
        return indicatorLayout.horizontalOffset
    }

    /// A sticky notice is written under the notch unless an indicator's details are open there.
    var shownNotice: StickyNotice? { labelIndex == nil ? notices.notice : nil }

    /// The indicator whose details are open: the hovered one, otherwise the announced meeting.
    var labelIndex: Int? {
        // The recording drops nothing down: its dot becomes Stop (spec SH-5b).
        if let hoveredIndicator { return isRecordingHovered ? nil : hoveredIndicator }
        // Beside the notch the announced meeting is a notice of its own (spec PV-67).
        if let announcement = calendarIndicator.announcement, !settings.noticesBeside {
            return indicatorItems.firstIndex { item in
                if case .meeting(let event, _) = item { event.id == announcement.id } else { false }
            }
        }
        // A new track's name, for a moment (spec MU-4).
        // Beside the notch it is a small notice of its own (spec PV-68).
        guard musicIndicator.isAnnouncing, !settings.noticesBeside else { return nil }
        return indicatorItems.firstIndex { if case .music = $0 { true } else { false } }
    }

    private var hoveredIndicator: Int? {
        model.hoveredIndicator.flatMap { indicatorItems.indices.contains($0) ? $0 : nil }
    }

    var size: CGSize { model.isExpanded ? model.openSize : collapsedSize }

    var body: some View {
        // Content lives inside the black background and is clipped by it, so both grow and
        // shrink together in one animation instead of the content appearing first.
        ZStack(alignment: .top) {
            // The glass window draws only the glass (spec D-6).
            if layer == .content {
                if !model.isExpanded, let display = hud.display {
                    // Volume and brightness come first (spec H-1).
                    HUDView(display: display, notchWidth: geometry.notchSize.width)
                        .frame(height: geometry.notchSize.height)
                        // The ring fills as the HUD comes and empties as it goes (spec H-3c).
                        .transition(.hudReveal(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion))
                } else if !model.isExpanded, let call = calls.call {
                    CallView(service: calls, call: call, notchHeight: geometry.notchSize.height)
                        .frame(width: collapsedSize.width, height: collapsedSize.height, alignment: .top)
                        .transition(.opacity)
                } else if !model.isExpanded, !model.isScreenShared, let notification = notifications.peek {
                    // The closed notch's row stays; the notification drops down under it (spec E-24).
                    ZStack(alignment: .top) {
                        peekView(notification, width: naturalCollapsedSize.width)
                        // In Wings mode the notification stands beside the notch, over the row (spec PV-13).
                        if !indicatorLayout.isEmpty, !settings.noticesBeside {
                            indicatorRow(hoveredIndex: nil, notice: nil, showsBadgeList: false)
                                .frame(width: naturalCollapsedSize.width, height: geometry.notchSize.height, alignment: .top)
                        }
                    }
                    .frame(width: naturalCollapsedSize.width, height: naturalCollapsedSize.height, alignment: .top)
                    .transition(settings.noticesBeside ? .wingsSpreadIn : .opacity)
                } else if !model.isExpanded, !model.isScreenShared, let event = devices.current {
                    devicePeek(event)
                } else if !model.isExpanded, showsScreenshotPeek {
                    screenshotPeek
                        .frame(width: screenshotPeekSize.width, height: screenshotPeekSize.height)
                        .transition(.opacity)
                } else if let notice = wingsNoticePeek {
                    // The notice or the announced meeting stands beside the notch, over the row (spec PV-37, PV-67).
                    wingsPeekView(notice).transition(.wingsSpreadIn)
                } else if !model.isExpanded, !model.isScreenShared, !indicatorLayout.isEmpty || shownNotice != nil {
                    indicatorRow(hoveredIndex: labelIndex, notice: shownNotice)
                    // Laid out at full size and kept in place while the black area unfolds over it.
                    .frame(width: naturalCollapsedSize.width, height: naturalCollapsedSize.height, alignment: .top)
                    .offset(x: isGathered ? indicatorLayout.horizontalOffset : 0)
                    .blur(radius: isGathered ? 6 : 0)
                    .opacity(isGathered ? 0 : 1)
                    // After the Wings' content has gone, the row swims out of the notch (spec PV-26).
                    .transition(settings.hoverPreview ? .notchItemsOut : .opacity)
                }

                if model.isExpanded, model.isShowingOverlayPage {
                    overlayPage.frame(width: model.openSize.width, height: model.openSize.height).transition(.wingsOr(model.isPreview))
                } else if model.isExpanded, model.isShowingNotifications {
                    NotificationStackView(
                        service: notifications,
                        notifications: model.notifications,
                        canReply: model.notificationsCanReply,
                        notchHeight: geometry.notchSize.height,
                        close: closeNotifications,
                        clearAll: clearNotifications
                    )
                    .frame(width: model.openSize.width, height: model.openSize.height)
                    .transition(Self.contentTransition)
                } else if model.isExpanded, model.isPreview {
                    wingsContent.transition(.wingsSpreadIn)
                } else if model.isExpanded {
                    expandedContent
                        .frame(width: model.openSize.width, height: model.openSize.height)
                        .overlay(alignment: .top) { backToWingsArea }
                        .overlay(alignment: .bottomTrailing) {
                            // The resize handle (spec RS-1).
                            if layer == .content, model.canResize { ResizeCorner(model: model, radius: cornerRadius) }
                        }
                        .transition(Self.contentTransition)
                }
            }
        }
        .offset(y: -pillTrim / 2)
        .frame(width: size.width, height: size.height - pillTrim, alignment: .top)
        // The capsule may reach beyond the content (spec N-11); the content stays in place.
        .offset(x: -capsule.shift)
        .frame(width: capsule.width, height: size.height - pillTrim)
        .background(designBackground)
        .clipShape(shape)
        .background { designShadow }
        .offset(x: collapsedOffset + capsule.shift)
        .opacity(isHiddenForFullScreen ? 0 : 1)
        .animation(NotchController.animation, value: isHiddenForFullScreen)
        // Mission Control: slides up out of the way and back down the same way, quickly (spec N-19b).
        .offset(y: model.isHiddenForMissionControl ? -(size.height + 12) : 0)
        .opacity(model.isHiddenForMissionControl ? 0 : 1)
        .animation(Self.missionControlAnimation, value: model.isHiddenForMissionControl)
        .padding(.top, isPill ? Self.pillGap : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .top) {
            if layer == .content, showsStrip {
                ModuleStripView(
                    features: stripFeatures, origin: model.stripOrigin, fromAbove: model.isPreview, open: openModule,
                    move: { feature, index in settings.moveFeature(feature, to: index, among: stripFeatures) },
                    hoverOpenDelay: stripHoverOpenDelay, hoverSwitch: stripHoverSwitch,
                    hoverSwitchDelay: settings.moduleStripHoverDelay
                )
                    // Under whatever hangs below the Wings (spec PV-29).
                    .padding(.top, stripTop + NotchGeometry.stripGap + (isPill ? Self.pillGap : 0))
            }
        }
        .animation(Self.quickAnimation, value: showsStrip)
        .animation(NotchController.animation, value: model.notificationsTab)
        .animation(Self.quickAnimation, value: indicatorItems.map(\.id))
        .animation(Self.quickAnimation, value: badges.visible.map { $0.id + $0.text })
        .animation(NotchController.animation, value: badgeFit.hidden)
        .animation(NotchController.animation, value: labelIndex)
        .animation(NotchController.animation, value: notifications.peek?.id)
        .animation(NotchController.animation, value: devices.current?.id)
        .animation(NotchController.animation, value: screenshots.peek?.id)
        .animation(Self.quickAnimation, value: screenshots.choosing)
        .animation(Self.quickAnimation, value: hud.display != nil)
        .animation(NotchController.animation, value: calls.call != nil)
        .animation(NotchController.animation, value: notices.notice)
        .animation(Self.quickAnimation, value: calls.isComposing)
        .animation(NotchController.animation, value: settings.roundedNotch)
        .animation(NotchController.animation, value: settings.roundOnlyWhereShown)
        .animation(NotchController.animation, value: settings.design)
        .animation(Self.quickAnimation, value: settings.panelOpacity)
        .animation(NotchController.animation, value: settings.externalStyle)
        .environment(\.colorScheme, .dark)
        .environment(\.notchDesign, settings.design)
        .environment(\.pinNotch) { [model] in model.holdsForTyping = true }
        .environment(\.closeNotch) { [model] in model.requestCollapse() }
        .environment(\.takeKeyboard) { [model] in model.requestKeyboard() }
        .modifier(AppleStyleRoot())
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            menuBar
            if model.isShowingSettings {
                SettingsView(
                    settings: settings, calendar: calendar, notifications: notifications,
                    badges: badges, shortcuts: shortcuts, updates: updates, clipboard: clipboard, tray: tray, beeper: beeper,
                    devices: devices, chat: chat, tasks: tasks, switcher: switcher?.settings,
                    screenshots: screenshots.settings, battery: battery
                )
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            } else {
                // Never taller than its room, so it cannot push the top row up (spec N-26).
                featureContent
                    .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .offset(x: model.bounceOffset)
                    .transition(.opacity)
                if model.isClipboardInline {
                    // ⌥V in the open notch: the items under the module (spec CB-3c).
                    ClipboardPickerView(picker: clipboardPicker, store: clipboard, notchHeight: 0)
                        .frame(height: NotchViewModel.inlinePickerHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Closed size

extension NotchView {
    /// Right after a Space switch: drawn into the notch, then unfolding (spec N-10).
    private var isGathered: Bool {
        model.isGathered && !model.isExpanded && hud.display == nil && calls.call == nil && notifications.peek == nil
    }

    private var collapsedSize: CGSize {
        isGathered ? geometry.notchSize : naturalCollapsedSize
    }

    /// Closed notch, widened on both sides while meetings are counted down (spec K-7), and
    /// taller while one of them is hovered (spec K-8d).
    private var naturalCollapsedSize: CGSize {
        if hud.display != nil {
            return CGSize(width: geometry.notchSize.width + 2 * HUDView.sideWidth, height: geometry.notchSize.height)
        }
        if calls.call != nil { return geometry.callSize(composing: calls.isComposing) }
        if model.isScreenShared { return geometry.notchSize }
        // Beside the notch in Wings mode (spec PV-37, PV-38).
        if wingsPeek != nil { return geometry.wingsSize(model.peekSides) }
        if notifications.peek != nil {
            // As wide as the row above it, when that is wider (spec E-24).
            let peek = notifications.peekSize(in: geometry)
            let row = indicatorLayout.isEmpty ? 0 : indicatorLayout.size(notch: geometry.notchSize, labelHeight: nil).width
            return CGSize(width: max(peek.width, row), height: peek.height)
        }
        if devices.current != nil { return geometry.devicePeekSize }
        if showsScreenshotPeek { return screenshotPeekSize }
        let labelHeight = labelIndex.map(labelHeight(of:)) ?? hoveredBadgeHeight
            ?? (shownNotice == nil ? nil : IndicatorLayout.labelHeight)
        if indicatorLayout.isEmpty, let labelHeight {
            // Only the notice: centred under the bare notch.
            return CGSize(width: IndicatorLayout.labelWidth, height: geometry.notchSize.height + labelHeight)
        }
        return indicatorLayout.size(notch: geometry.notchSize, labelHeight: labelHeight)
    }

    /// The cover's player drops down only when hovered; announced, only the track's name (spec MU-2, MU-4).
    func labelHeight(of index: Int) -> CGFloat {
        if case .music = indicatorItems[index], hoveredIndicator == nil { return IndicatorLayout.musicAnnounceHeight }
        return indicatorItems[index].labelHeight
    }
}

extension NotchView {
    /// Countdowns appearing, disappearing or moving up after one is hidden (spec K-8e).
    static var quickAnimation: Animation { Motion.quick }
    static var missionControlAnimation: Animation { Motion.quick }
}
