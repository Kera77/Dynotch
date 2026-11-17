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

    /// Countdowns appearing, disappearing or moving up after one is hidden (spec K-8e).
    static let quickAnimation = Animation.easeOut(duration: 0.16)

    /// Content scales up from the notch and fades in with the same spring as the background.
    private static let contentTransition: AnyTransition =
        .scale(scale: 0.4, anchor: .top).combined(with: .opacity)

    var geometry: NotchGeometry { model.geometry }

    /// Closed notch, widened on both sides while meetings are counted down (spec K-7), and
    /// taller while one of them is hovered (spec K-8d).
    private var collapsedSize: CGSize {
        if hud.display != nil {
            return CGSize(width: geometry.notchSize.width + 2 * HUDView.sideWidth, height: geometry.notchSize.height)
        }
        if calls.call != nil { return geometry.callSize(composing: calls.isComposing) }
        if notifications.peek != nil { return geometry.peekSize }
        let labelHeight = labelIndex.map { indicatorItems[$0].labelHeight } ?? (shownNotice == nil ? nil : IndicatorLayout.labelHeight)
        if indicatorLayout.isEmpty, let labelHeight {
            // Only the notice: centred under the bare notch.
            return CGSize(width: IndicatorLayout.labelWidth, height: geometry.notchSize.height + labelHeight)
        }
        return indicatorLayout.size(notch: geometry.notchSize, labelHeight: labelHeight)
    }

    /// Meeting countdowns and the Claude usage beside the closed notch.
    private var indicatorItems: [IndicatorItem] {
        IndicatorItem.items(
            meetings: calendar.indicatorEvents, usage: claudeUsage.notchLimits, working: chat.isWorking,
            lowBatteries: battery.warnings
        )
    }

    private var indicatorLayout: IndicatorLayout {
        IndicatorLayout(items: indicatorItems, badges: badges.visible)
    }

    /// The closed notch with countdowns is asymmetric: keep the physical notch in place.
    private var collapsedOffset: CGFloat {
        guard !model.isExpanded, notifications.peek == nil, hud.display == nil, calls.call == nil else { return 0 }
        return indicatorLayout.horizontalOffset
    }

    /// A sticky notice is written under the notch unless an indicator's details are open there.
    private var shownNotice: StickyNotice? { labelIndex == nil ? notices.notice : nil }

    /// The indicator whose details are open: the hovered one, otherwise the announced meeting.
    private var labelIndex: Int? {
        if let hoveredIndicator { return hoveredIndicator }
        guard let announcement = calendar.announcement else { return nil }
        return indicatorItems.firstIndex { item in
            if case .meeting(let event) = item { event.id == announcement.id } else { false }
        }
    }

    private var hoveredIndicator: Int? {
        model.hoveredIndicator.flatMap { indicatorItems.indices.contains($0) ? $0 : nil }
    }

    private var size: CGSize { model.isExpanded ? model.openSize : collapsedSize }
    private var cornerRadius: CGFloat {
        if model.isExpanded { return model.isPreview ? 18 : 24 }
        if hud.display != nil { return 10 }
        if calls.call != nil { return 20 }
        return notifications.peek != nil || labelIndex != nil || shownNotice != nil ? 16 : 10
    }

    var body: some View {
        // Content lives inside the black background and is clipped by it, so both grow and
        // shrink together in one animation instead of the content appearing first.
        ZStack(alignment: .top) {
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
            } else if !model.isExpanded, !indicatorLayout.isEmpty || shownNotice != nil {
                NotchIndicatorView(
                    items: indicatorItems,
                    leadTime: calendar.leadTime,
                    notchSize: geometry.notchSize,
                    hoveredIndex: labelIndex,
                    badges: badges.visible,
                    hoveredBadge: model.hoveredBadge,
                    notice: shownNotice,
                    openBadge: { badges.open($0.app) },
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
                    }
                )
                .frame(width: collapsedSize.width, height: collapsedSize.height, alignment: .top)
                .transition(.opacity)
            }

            if model.isExpanded, model.isShowingNotifications {
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
                    .transition(Self.contentTransition)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(.black)
        .clipShape(shape)
        .offset(x: collapsedOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Self.quickAnimation, value: indicatorItems.map(\.id))
        .animation(Self.quickAnimation, value: badges.visible.map { $0.id + $0.text })
        .animation(NotchController.animation, value: labelIndex)
        .animation(NotchController.animation, value: notifications.peek?.id)
        .animation(Self.quickAnimation, value: hud.display != nil)
        .animation(NotchController.animation, value: calls.call != nil)
        .animation(NotchController.animation, value: notices.notice)
        .animation(Self.quickAnimation, value: calls.isComposing)
        .environment(\.colorScheme, .dark)
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            style: .continuous
        )
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            menuBar
            if model.isShowingSettings {
                SettingsView(
                    settings: settings, calendar: calendar, notifications: notifications,
                    badges: badges, shortcuts: shortcuts, updates: updates
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

    // MARK: - Menu bar (spec M-1…M-5)

    private var sideWidth: CGFloat {
        (model.openSize.width - geometry.notchSize.width) / 2
    }

    private var menuBar: some View {
        HStack(spacing: 0) {
            FeatureSwitcher(
                features: settings.activeFeatures,
                selected: model.isShowingSettings ? nil : model.currentFeature
            ) { feature in
                withAnimation(NotchController.animation) { model.select(feature) }
            } move: { feature, index in
                settings.moveActiveFeature(feature, toActiveIndex: index)
            }
            .padding(.leading, 14)
            .frame(width: sideWidth, alignment: .leading)

            Color.clear.frame(width: geometry.notchSize.width)

            // Right side of the notch: settings; later also status (volume/brightness HUD).
            TrailingControls(
                followsMouse: settings.focusFollowsMouse,
                toggleFollowsMouse: { settings.focusFollowsMouse.toggle() },
                isKeyboardLocked: keyboardLock.isLocked,
                toggleKeyboardLock: { keyboardLock.toggle() },
                isPinned: model.isPinned,
                isShowingSettings: model.isShowingSettings,
                togglePin: { model.isPinned.toggle() },
                toggleSettings: toggleSettings
            )
            .padding(.trailing, 14)
                .frame(width: sideWidth, alignment: .trailing)
        }
        .frame(height: geometry.menuBarHeight)
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
            ForEach(features) { feature in
                page(for: feature)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .frame(width: pageWidth)
                    .frame(maxHeight: .infinity)
                    .allowsHitTesting(feature == model.currentFeature)
            }
        }
        .frame(width: pageWidth, alignment: .leading)
        .offset(x: -CGFloat(index) * pageWidth)
        .clipped()
    }
}

/// Lock and gear on the right of the panel's top row (spec C-1, SZ-8).
private struct TrailingControls: View {
    let followsMouse: Bool
    let toggleFollowsMouse: () -> Void
    let isKeyboardLocked: Bool
    let toggleKeyboardLock: () -> Void
    let isPinned: Bool
    let isShowingSettings: Bool
    let togglePin: () -> Void
    let toggleSettings: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            // Focus follows mouse on and off (spec F-9): blue while on.
            Button(action: toggleFollowsMouse) {
                Image(systemName: "arrow.up.square.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 22)
                    .foregroundStyle(followsMouse ? ClaudeUsageView.blue : Color.white.opacity(0.45))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(followsMouse ? "Focus follows the mouse: click to turn off" : "Focus follows the mouse is off: click to turn on")
            // Blocks the keyboard for cleaning (spec KL-1): grey when off, blue when on.
            Button(action: toggleKeyboardLock) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 22)
                    .foregroundStyle(isKeyboardLocked ? ClaudeUsageView.blue : Color.white.opacity(0.45))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isKeyboardLocked ? "Keyboard is locked: click to unlock" : "Lock the keyboard (for cleaning)")
            PinButton(isPinned: isPinned, action: togglePin)
            Button(action: toggleSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 22)
                    .foregroundStyle(isShowingSettings ? Color.white : Color.white.opacity(0.7))
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isShowingSettings ? Color.white.opacity(0.22) : .clear)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
    }
}
