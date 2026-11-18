import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendar: CalendarService
    @ObservedObject var notifications: NotificationService
    let calculator: CalculatorStore
    let notes: NotesStore
    let reminders: RemindersStore
    @ObservedObject var claudeUsage: ClaudeUsageService
    @ObservedObject var hud: HUDService
    @ObservedObject var badges: BadgeService
    @ObservedObject var calls: CallService
    @ObservedObject var keyboardLock: KeyboardLock
    @ObservedObject var notices: NoticeService
    @ObservedObject var chat: ClaudeChatService
    @ObservedObject var battery: BatteryService
    let shortcuts: ShortcutStore
    let updates: UpdateService
    /// Watched by its own views, not by the whole notch (spec N-16).
    let tablets: TabletDisplayService
    /// The content's window, or the glass window behind it (spec D-6).
    var layer = DesignLayer.content
    let clipboard: ClipboardStore
    /// Watched by its own views, not by the whole notch (spec N-16).
    let clipboardPicker: ClipboardPicker
    /// Watched by its own views, not by the whole notch (spec N-16).
    let tray: TrayStore
    /// Watched by its own views, not by the whole notch (spec N-16).
    let beeper: BeeperService
    @ObservedObject var devices: DeviceWatcher
    /// Gear button: opens the settings in the notch or in a window, as configured.
    let toggleSettings: () -> Void
    /// Closes the notification card (spec E-12).
    var closeNotifications: () -> Void = {}
    /// Clears every notification and closes the card (spec E-12).
    var clearNotifications: () -> Void = {}
    /// A right click on an app badge: its unopened notifications (spec B-6).
    var showBadgeNotifications: (BadgeItem) -> Void = { _ in }
    /// Opens the whole panel from the preview (spec PV-3).
    var openFully: () -> Void = {}
    /// A module picked in the strip under the closed notch (spec MS-3).
    var openModule: (FeatureID) -> Void = { _ in }
    /// Opens the notch on the Beeper tab (spec BP-12).
    var openBeeper: () -> Void = {}
    /// Files dropped on the notch's "Keep" / "AirDrop" targets (spec FT-1, FT-3).
    var keepInTray: ([URL]) -> Void = { _ in }
    var sendWithAirDrop: ([URL]) -> Void = { _ in }

    /// Countdowns appearing, disappearing or moving up after one is hidden (spec K-8e).
    static let quickAnimation = Motion.quick

    /// Content fades in and slides down a little with the background. Not scaled: text drawn
    /// while scaled stayed blurry until the next redraw (spec N-17).
    private static let contentTransition: AnyTransition =
        .opacity.combined(with: .offset(y: -10))

    var geometry: NotchGeometry { model.geometry }

    /// Meeting countdowns and the Claude usage beside the closed notch.
    private var indicatorItems: [IndicatorItem] {
        IndicatorItem.items(
            meetings: calendar.indicatorEvents, usage: claudeUsage.notchLimits, working: chat.isWorking,
            lowBatteries: battery.warnings
        )
    }

    /// The badges that fit beside the menu bar, and how many wait behind the "+" (spec B-8).
    private var badgeFit: BadgeFit {
        BadgeFit.make(badges: badges.visible, items: indicatorItems, room: model.badgeRoom, unfolded: model.badgesUnfolded)
    }

    private var indicatorLayout: IndicatorLayout {
        let fit = badgeFit
        return IndicatorLayout(items: indicatorItems, badges: fit.shown, overflow: fit.hidden > 0)
    }

    /// The closed notch with countdowns is asymmetric: keep the physical notch in place.
    var collapsedOffset: CGFloat {
        guard !model.isExpanded, notifications.peek == nil, devices.current == nil, hud.display == nil, calls.call == nil, !isGathered
        else { return 0 }
        return indicatorLayout.horizontalOffset
    }

    /// A sticky notice is written under the notch unless an indicator's details are open there.
    var shownNotice: StickyNotice? { labelIndex == nil ? notices.notice : nil }

    /// The indicator whose details are open: the hovered one, otherwise the announced meeting.
    var labelIndex: Int? {
        if let hoveredIndicator { return hoveredIndicator }
        guard let announcement = calendar.announcement else { return nil }
        return indicatorItems.firstIndex { item in
            if case .meeting(let event) = item { event.id == announcement.id } else { false }
        }
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
                        .transition(.opacity)
                } else if !model.isExpanded, let call = calls.call {
                    CallView(service: calls, call: call, notchHeight: geometry.notchSize.height)
                        .frame(width: collapsedSize.width, height: collapsedSize.height, alignment: .top)
                        .transition(.opacity)
                } else if !model.isExpanded, let notification = notifications.peek {
                    NotificationPeekView(
                        app: notifications.catalog.app(for: notification.appIdentifier),
                        content: notifications.content(for: notification),
                        notchHeight: geometry.notchSize.height,
                        newCount: notifications.unseen.count
                    )
                    .frame(width: geometry.peekSize.width, height: geometry.peekSize.height)
                    .transition(.opacity)
                } else if !model.isExpanded, let event = devices.current {
                    DevicePeekView(event: event, notchHeight: geometry.notchSize.height) { devices.perform($0) }
                        .frame(width: geometry.peekSize.width, height: geometry.peekSize.height)
                        .transition(.opacity)
                } else if !model.isExpanded, !indicatorLayout.isEmpty || shownNotice != nil {
                    NotchIndicatorView(
                        items: indicatorItems,
                        leadTime: calendar.leadTime,
                        notchSize: geometry.notchSize,
                        hoveredIndex: labelIndex,
                        badges: badgeFit.shown,
                        hiddenBadges: badgeFit.hidden,
                        hoveredBadge: model.hoveredBadge,
                        notice: shownNotice,
                        openBadge: { badge in
                            // Beeper's badge opens its chats in the notch (spec BP-12).
                            if badge.app.bundleID.lowercased().contains("beeper"), settings.isEnabled(.notifications) {
                                openBeeper()
                            } else {
                                badges.open(badge.app)
                            }
                        },
                        moveBadge: { id, index in
                            withAnimation(Self.quickAnimation) { badges.moveVisible(id, toVisibleIndex: index) }
                        },
                        showBadgeNotifications: showBadgeNotifications,
                        dismiss: { item in
                            withAnimation(Self.quickAnimation) {
                                model.hoveredIndicator = nil
                                switch item {
                                case .meeting(let event): calendar.dismissIndicator(event)
                                case .usage: claudeUsage.dismissIndicator()
                                case .working: break
                                case .battery(let device): battery.dismissWarning(for: device)
                                }
                            }
                        },
                        join: { calendar.join($0) },
                        batterySamples: { battery.history.samples[$0] ?? [] }
                    )
                    // Laid out at full size and kept in place while the black area unfolds over it.
                    .frame(width: naturalCollapsedSize.width, height: naturalCollapsedSize.height, alignment: .top)
                    .offset(x: isGathered ? indicatorLayout.horizontalOffset : 0)
                    .blur(radius: isGathered ? 6 : 0)
                    .opacity(isGathered ? 0 : 1)
                    .transition(.opacity)
                }

                if model.isExpanded, model.isShowingOverlayPage {
                    overlayPage.frame(width: model.openSize.width, height: model.openSize.height).transition(.opacity)
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
                    FeaturePreviewView(
                        feature: model.currentFeature, preview: featurePreview, notchHeight: geometry.notchSize.height,
                        hint: settings.previewOpensOnClick ? "Click to open" : nil
                    )
                    .frame(width: model.openSize.width, height: model.openSize.height)
                    .onTapGesture { if settings.previewOpensOnClick { openFully() } }
                    .transition(.opacity)
                } else if model.isExpanded {
                    expandedContent
                        .frame(width: model.openSize.width, height: model.openSize.height)
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
        .background(DesignBackground(
            design: settings.design, shape: shape, isOpen: showsDesign, layer: layer, openOpacity: settings.panelOpacity
        ))
        .clipShape(shape)
        .offset(x: collapsedOffset + capsule.shift)
        .opacity(isHiddenForFullScreen ? 0 : 1)
        .animation(NotchController.animation, value: isHiddenForFullScreen)
        .padding(.top, isPill ? Self.pillGap : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .top) {
            if layer == .content, model.isShowingStrip, !model.isExpanded {
                ModuleStripView(features: stripFeatures, origin: model.stripOrigin, open: openModule)
                    .padding(.top, geometry.notchSize.height + NotchGeometry.stripGap + (isPill ? Self.pillGap : 0))
            }
        }
        .animation(Self.quickAnimation, value: model.isShowingStrip)
        .animation(NotchController.animation, value: model.notificationsTab)
        .animation(Self.quickAnimation, value: indicatorItems.map(\.id))
        .animation(Self.quickAnimation, value: badges.visible.map { $0.id + $0.text })
        .animation(NotchController.animation, value: badgeFit.hidden)
        .animation(NotchController.animation, value: labelIndex)
        .animation(NotchController.animation, value: notifications.peek?.id)
        .animation(NotchController.animation, value: devices.current?.id)
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
        .environment(\.pinNotch) { [model] in model.isPinned = true }
        .environment(\.closeNotch) { [model] in model.requestCollapse() }
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            menuBar
            if model.isShowingSettings {
                SettingsView(
                    settings: settings, calendar: calendar, notifications: notifications,
                    badges: badges, shortcuts: shortcuts, updates: updates, clipboard: clipboard, tray: tray, beeper: beeper,
                    devices: devices, chat: chat
                )
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            } else {
                featureContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: model.bounceOffset)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Content

    /// All features sit side by side and the row slides (spec S-5): switching to the next feature
    /// moves the current one out to the left while the new one comes in from the right, and
    /// the other way round.
    private var featureContent: some View {
        let features = settings.activeFeatures
        let index = features.firstIndex(of: model.currentFeature) ?? 0
        let pageWidth = model.openSize.width
        return HStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.element) { position, feature in
                // Only the module shown and its neighbours (for the swipe) are built (spec N-16).
                if abs(position - index) <= 1 {
                    page(for: feature)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .frame(width: pageWidth)
                        .frame(maxHeight: .infinity)
                        .allowsHitTesting(feature == model.currentFeature)
                } else {
                    Color.clear.frame(width: pageWidth)
                }
            }
        }
        .frame(width: pageWidth, alignment: .leading)
        .offset(x: -CGFloat(index) * pageWidth)
        .clipped()
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
        if notifications.peek != nil || devices.current != nil { return geometry.peekSize }
        let labelHeight = labelIndex.map { indicatorItems[$0].labelHeight } ?? (shownNotice == nil ? nil : IndicatorLayout.labelHeight)
        if indicatorLayout.isEmpty, let labelHeight {
            // Only the notice: centred under the bare notch.
            return CGSize(width: IndicatorLayout.labelWidth, height: geometry.notchSize.height + labelHeight)
        }
        return indicatorLayout.size(notch: geometry.notchSize, labelHeight: labelHeight)
    }
}
