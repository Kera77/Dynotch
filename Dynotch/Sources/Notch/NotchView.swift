import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendar: CalendarService
    @ObservedObject var notifications: NotificationService
    let calculator: CalculatorStore
    /// Gear button: opens the settings in the notch or in a window, as configured.
    let toggleSettings: () -> Void

    private static let indicatorSideWidth: CGFloat = 60
    /// Content scales up from the notch and fades in with the same spring as the background.
    private static let contentTransition: AnyTransition =
        .scale(scale: 0.4, anchor: .top).combined(with: .opacity)

    private var geometry: NotchGeometry { model.geometry }

    /// Closed notch, widened on both sides while an upcoming event is shown (spec K-7).
    private var collapsedSize: CGSize {
        if notifications.peek != nil { return geometry.peekSize }
        guard calendar.upcoming != nil else { return geometry.notchSize }
        return CGSize(
            width: geometry.notchSize.width + 2 * Self.indicatorSideWidth,
            height: geometry.notchSize.height
        )
    }

    private var size: CGSize { model.isExpanded ? model.openSize : collapsedSize }
    private var cornerRadius: CGFloat { model.isExpanded ? 24 : (notifications.peek != nil ? 16 : 10) }

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
            } else if !model.isExpanded, let event = calendar.upcoming {
                UpcomingEventIndicator(
                    event: event,
                    leadTime: calendar.leadTime,
                    notchWidth: geometry.notchSize.width,
                    sideWidth: Self.indicatorSideWidth
                )
                .frame(height: geometry.notchSize.height)
                .transition(.opacity)
            }

            if model.isExpanded {
                expandedContent
                    .frame(width: model.openSize.width, height: model.openSize.height)
                    .transition(Self.contentTransition)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(.black)
        .clipShape(shape)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(NotchController.animation, value: calendar.upcoming?.id)
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

/// Capsule-shaped icon switcher in the panel's top row (spec M-1).
private struct FeatureSwitcher: View {
    let features: [FeatureID]
    let selected: FeatureID?
    let select: (FeatureID) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(features) { feature in
                Button {
                    select(feature)
                } label: {
                    Image(systemName: feature.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 32, height: 22)
                        .foregroundStyle(feature == selected ? Color.white : Color.white.opacity(0.7))
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(feature == selected ? Color.white.opacity(0.22) : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(feature.title)
            }
        }
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
    }
}
