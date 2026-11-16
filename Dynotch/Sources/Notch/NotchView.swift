import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendar: CalendarService
    @ObservedObject var notifications: NotificationService
    let calculator: CalculatorStore
    let notes: NotesStore
    let reminders: RemindersStore
    let claudeUsage: ClaudeUsageService
    /// Gear button: opens the settings in the notch or in a window, as configured.
    let toggleSettings: () -> Void

    /// Countdowns appearing, disappearing or moving up after one is hidden (spec K-8e).
    static let quickAnimation = Animation.easeOut(duration: 0.16)

    /// Content scales up from the notch and fades in with the same spring as the background.
    private static let contentTransition: AnyTransition =
        .scale(scale: 0.4, anchor: .top).combined(with: .opacity)

    private var geometry: NotchGeometry { model.geometry }

    /// Closed notch, widened on both sides while meetings are counted down (spec K-7), and
    /// taller while one of them is hovered (spec K-8d).
    private var collapsedSize: CGSize {
        if notifications.peek != nil { return geometry.peekSize }
        return IndicatorLayout(count: calendar.indicatorEvents.count)
            .size(notch: geometry.notchSize, showsLabel: hoveredIndicator != nil)
    }

    private var indicatorLayout: IndicatorLayout {
        IndicatorLayout(count: calendar.indicatorEvents.count)
    }

    /// The closed notch with countdowns is asymmetric: keep the physical notch in place.
    private var collapsedOffset: CGFloat {
        guard !model.isExpanded, notifications.peek == nil else { return 0 }
        return indicatorLayout.horizontalOffset
    }

    private var hoveredIndicator: Int? {
        model.hoveredIndicator.flatMap { calendar.indicatorEvents.indices.contains($0) ? $0 : nil }
    }

    private var size: CGSize { model.isExpanded ? model.openSize : collapsedSize }
    private var cornerRadius: CGFloat {
        if model.isExpanded { return 24 }
        return notifications.peek != nil || hoveredIndicator != nil ? 16 : 10
    }

    var body: some View {
        // Content lives inside the black background and is clipped by it, so both grow and
        // shrink together in one animation instead of the content appearing first.
        ZStack(alignment: .top) {
            if !model.isExpanded, let notification = notifications.peek {
                NotificationPeekView(
                    app: notifications.catalog.app(for: notification.appIdentifier),
                    content: notifications.content(for: notification),
                    notchHeight: geometry.notchSize.height
                )
                .frame(width: geometry.peekSize.width, height: geometry.peekSize.height)
                .transition(.opacity)
            } else if !model.isExpanded, !calendar.indicatorEvents.isEmpty {
                UpcomingEventIndicator(
                    events: calendar.indicatorEvents,
                    leadTime: calendar.leadTime,
                    notchSize: geometry.notchSize,
                    hoveredIndex: hoveredIndicator
                ) { event in
                    withAnimation(Self.quickAnimation) {
                        model.hoveredIndicator = nil
                        calendar.dismissIndicator(event)
                    }
                }
                .frame(width: collapsedSize.width, height: collapsedSize.height, alignment: .top)
                .transition(.opacity)
            }

            if model.isExpanded, let notification = model.notification {
                NotificationCardView(
                    app: notifications.catalog.app(for: notification.appIdentifier),
                    content: notifications.content(for: notification),
                    date: notification.date,
                    notchHeight: geometry.notchSize.height
                )
                .frame(width: model.openSize.width, height: model.openSize.height)
                .onTapGesture { notifications.catalog.open(notification.appIdentifier) }
                .transition(Self.contentTransition)
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
        .animation(Self.quickAnimation, value: calendar.indicatorEvents.map(\.id))
        .animation(NotchController.animation, value: hoveredIndicator)
        .animation(NotchController.animation, value: notifications.peek?.id)
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
                SettingsView(settings: settings, calendar: calendar, notifications: notifications)
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

    @ViewBuilder
    private func page(for feature: FeatureID) -> some View {
        switch feature {
        case .home:
            HomeFeatureView()
        case .calendar:
            CalendarFeatureView(service: calendar, model: model)
        case .notifications:
            NotificationsFeatureView(service: notifications)
        case .calculator:
            CalculatorFeatureView(store: calculator)
        case .notes:
            NotesFeatureView(store: notes, isActive: model.isExpanded && model.currentFeature == .notes)
        case .reminders:
            RemindersFeatureView(store: reminders, isActive: model.isExpanded && model.currentFeature == .reminders)
        case .claudeUsage:
            ClaudeUsageFeatureView(service: claudeUsage, isActive: model.isExpanded && model.currentFeature == .claudeUsage)
        case .info:
            InfoFeatureView(geometry: geometry, screenName: model.screenName)
        }
    }
}

/// Lock and gear on the right of the panel's top row (spec C-1, SZ-8).
private struct TrailingControls: View {
    let isPinned: Bool
    let isShowingSettings: Bool
    let togglePin: () -> Void
    let toggleSettings: () -> Void

    var body: some View {
        HStack(spacing: 2) {
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
            .help("Beállítások")
        }
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
    }
}

/// Capsule-shaped icon switcher in the panel's top row (spec M-1). Holding Command while
/// dragging an icon reorders the features (spec M-6). During the drag the views keep their
/// order and only move by offsets, so the gesture is never interrupted; the order changes when
/// the icon is dropped.
struct FeatureSwitcher: View {
    let features: [FeatureID]
    let selected: FeatureID?
    let select: (FeatureID) -> Void
    let move: (FeatureID, Int) -> Void

    static let itemWidth: CGFloat = 32
    static let spacing: CGFloat = 2
    static var step: CGFloat { itemWidth + spacing }
    private static let coordinateSpace = "FeatureSwitcher"

    @State private var dragged: FeatureID?
    @State private var dragOffset: CGFloat = 0

    static func targetIndex(from: Int, offset: CGFloat, count: Int) -> Int {
        min(max(from + Int((offset / step).rounded()), 0), max(count - 1, 0))
    }

    /// How far an icon is shifted while another one is dragged over its place.
    static func shift(of index: Int, draggedFrom from: Int, to target: Int) -> CGFloat {
        if target > from, index > from, index <= target { return -step }
        if target < from, index >= target, index < from { return step }
        return 0
    }

    private var target: Int? {
        guard let dragged, let from = features.firstIndex(of: dragged) else { return nil }
        return Self.targetIndex(from: from, offset: dragOffset, count: features.count)
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(Array(features.enumerated()), id: \.element) { index, feature in
                icon(feature)
                    .offset(x: offset(of: index, feature: feature))
                    .zIndex(feature == dragged ? 1 : 0)
                    .onTapGesture { select(feature) }
                    .gesture(reorderGesture(for: feature))
                    .help("\(feature.title) (⌘ + húzás: átrendezés)")
            }
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
    }

    private func offset(of index: Int, feature: FeatureID) -> CGFloat {
        if feature == dragged { return dragOffset }
        guard let dragged, let from = features.firstIndex(of: dragged), let target else { return 0 }
        return Self.shift(of: index, draggedFrom: from, to: target)
    }

    private func icon(_ feature: FeatureID) -> some View {
        let isSelected = feature == selected
        let isDragged = feature == dragged
        return Image(systemName: feature.symbolName)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: Self.itemWidth, height: 22)
            .foregroundStyle(isSelected || isDragged ? Color.white : Color.white.opacity(0.7))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDragged ? Color.white.opacity(0.32) : (isSelected ? Color.white.opacity(0.22) : .clear))
            )
            .scaleEffect(isDragged ? 1.12 : 1)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: target)
    }

    private func reorderGesture(for feature: FeatureID) -> some Gesture {
        // Measured in the row's space: the dragged icon moving does not change the translation.
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.coordinateSpace))
            .onChanged { value in
                if dragged == nil {
                    // Only a drag started with Command held reorders.
                    guard NSEvent.modifierFlags.contains(.command) else { return }
                    dragged = feature
                }
                guard dragged == feature else { return }
                dragOffset = value.translation.width
            }
            .onEnded { _ in
                guard dragged == feature, let from = features.firstIndex(of: feature) else { return }
                let target = Self.targetIndex(from: from, offset: dragOffset, count: features.count)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragged = nil
                    dragOffset = 0
                    if target != from { move(feature, target) }
                }
            }
    }
}
