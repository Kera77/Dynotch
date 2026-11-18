import SwiftUI

// MARK: - Menu bar (spec M-1…M-5)

extension NotchView {
    var sideWidth: CGFloat {
        (model.openSize.width - geometry.notchSize.width) / 2
    }

    var menuBar: some View {
        HStack(spacing: 0) {
            FeatureSwitcher(
                features: settings.activeFeatures,
                selected: model.isShowingSettings ? nil : model.currentFeature,
                first: model.switcherFirst,
                visibleCount: model.switcherVisibleCount
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
                tablets: tablets,
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
}

/// Lock and gear on the right of the panel's top row (spec C-1, SZ-8).
/// Sizes of the controls right of the notch: five buttons fit beside even the smallest panel.
enum TrailingControlsMetrics {
    static let buttonWidth: CGFloat = 30
    static let buttonCount = 5
    static let spacing: CGFloat = 2
    /// The capsule's padding and the margin at the panel's edge.
    static let insets: CGFloat = 2 * 3 + 14

    static var width: CGFloat {
        CGFloat(buttonCount) * buttonWidth + CGFloat(buttonCount - 1) * spacing + insets
    }
}

struct TrailingControls: View {
    @ObservedObject var tablets: TabletDisplayService
    let followsMouse: Bool
    let toggleFollowsMouse: () -> Void
    let isKeyboardLocked: Bool
    let toggleKeyboardLock: () -> Void
    let isPinned: Bool
    let isShowingSettings: Bool
    let togglePin: () -> Void
    let toggleSettings: () -> Void

    @ObservedObject private var layout = TopRowLayout.shared
    @State private var dragged: TopRowControl?
    @State private var dragOffset: CGFloat = 0
    private static let space = "TrailingControls"
    private static var step: CGFloat { TrailingControlsMetrics.buttonWidth + TrailingControlsMetrics.spacing }

    var body: some View {
        let shown = layout.visible
        HStack(spacing: TrailingControlsMetrics.spacing) {
            ForEach(Array(shown.enumerated()), id: \.element) { index, control in
                button(control)
                    .offset(x: offset(of: index, control: control, in: shown))
                    .zIndex(control == dragged ? 1 : 0)
                    .simultaneousGesture(reorder(control, in: shown))
            }
        }
        .coordinateSpace(name: Self.space)
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
    }

    @ViewBuilder private func button(_ control: TopRowControl) -> some View {
        switch control {
        case .tablet:
            // An iPad as a display (spec TB-1).
            TabletMenu(service: tablets)
        case .followMouse:
            // Focus follows mouse on and off (spec F-9): blue while on.
            iconButton(control.symbol, isOn: followsMouse, action: toggleFollowsMouse)
                .help(followsMouse ? "Focus follows the mouse: click to turn off" : "Focus follows the mouse is off: click to turn on")
        case .keyboardLock:
            // Blocks the keyboard for cleaning (spec KL-1): grey when off, blue when on.
            iconButton(control.symbol, isOn: isKeyboardLocked, action: toggleKeyboardLock)
                .help(isKeyboardLocked ? "Keyboard is locked: click to unlock" : "Lock the keyboard (for cleaning)")
        case .pin:
            PinButton(isPinned: isPinned, action: togglePin)
        case .settings:
            Button(action: toggleSettings) {
                Image(systemName: control.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                    .foregroundStyle(isShowingSettings ? Color.white : Color.white.opacity(0.7))
                    .background(Capsule(style: .continuous).fill(isShowingSettings ? Color.white.opacity(0.22) : .clear))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings (⌘-drag to reorder)")
            .accessibilityLabel("Settings")
        }
    }

    private func iconButton(_ symbol: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                .foregroundStyle(isOn ? ClaudeUsageView.blue : Color.white.opacity(0.45))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func offset(of index: Int, control: TopRowControl, in shown: [TopRowControl]) -> CGFloat {
        if control == dragged { return dragOffset }
        guard let dragged, let from = shown.firstIndex(of: dragged) else { return 0 }
        let target = Self.target(from: from, offset: dragOffset, count: shown.count)
        if target > from, index > from, index <= target { return -Self.step }
        if target < from, index >= target, index < from { return Self.step }
        return 0
    }

    static func target(from: Int, offset: CGFloat, count: Int) -> Int {
        min(max(from + Int((offset / step).rounded()), 0), max(count - 1, 0))
    }

    /// Command-drag reorders, like the module icons (spec M-11).
    private func reorder(_ control: TopRowControl, in shown: [TopRowControl]) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if dragged == nil {
                    guard NSEvent.modifierFlags.contains(.command) else { return }
                    dragged = control
                }
                guard dragged == control else { return }
                dragOffset = value.translation.width
            }
            .onEnded { _ in
                guard dragged == control, let from = shown.firstIndex(of: control) else { return }
                let target = Self.target(from: from, offset: dragOffset, count: shown.count)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragged = nil
                    dragOffset = 0
                    if target != from { layout.move(control, toVisibleIndex: target) }
                }
            }
    }
}
