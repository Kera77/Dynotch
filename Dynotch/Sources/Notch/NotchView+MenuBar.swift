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

    var body: some View {
        HStack(spacing: TrailingControlsMetrics.spacing) {
            // An iPad as a display (spec TB-1).
            TabletMenu(service: tablets)
            // Focus follows mouse on and off (spec F-9): blue while on.
            Button(action: toggleFollowsMouse) {
                Image(systemName: "arrow.up.square.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                    .foregroundStyle(followsMouse ? ClaudeUsageView.blue : Color.white.opacity(0.45))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(followsMouse ? "Focus follows the mouse: click to turn off" : "Focus follows the mouse is off: click to turn on")
            // Blocks the keyboard for cleaning (spec KL-1): grey when off, blue when on.
            Button(action: toggleKeyboardLock) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                    .foregroundStyle(isKeyboardLocked ? ClaudeUsageView.blue : Color.white.opacity(0.45))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isKeyboardLocked ? "Keyboard is locked: click to unlock" : "Lock the keyboard (for cleaning)")
            PinButton(isPinned: isPinned, action: togglePin)
            Button(action: toggleSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                    .foregroundStyle(isShowingSettings ? Color.white : Color.white.opacity(0.7))
                    .background(
                        Capsule(style: .continuous)
                            .fill(isShowingSettings ? Color.white.opacity(0.22) : .clear)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
    }
}
