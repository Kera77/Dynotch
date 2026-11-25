import AppKit
import SwiftUI

/// A floating card window, exactly as big as its content, hanging under the notch; used by the
/// tour (spec OB-30, OB-34, OB-35).
final class CardPanel: NSPanel {
    static let margin: CGFloat = 10
    /// Between the notch (or the open panel) and the card.
    static let gap: CGFloat = 8
    private var lastSize: CGSize = .zero
    /// The card's top centre: under the notch, or under the open panel (spec OB-34, OB-35).
    var anchor: () -> CGPoint? = { nil }

    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // Above the notch panel (main menu + 3).
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 4)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        alphaValue = 0
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        contentView = hosting
        // Laid out only once on screen; it appears with its first measured size.
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// The display with a built-in notch, otherwise the main one.
    static var screen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// The tallest a card may be: the visible part of its display (spec OB-30).
    static var maxHeight: CGFloat {
        (screen?.visibleFrame.height ?? 700) - 2 * margin
    }

    /// Takes the content's size, its top at the anchor (spec OB-30, OB-34).
    func fit(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        lastSize = size
        place(animated: false)
    }

    /// Follows the notch as it opens and closes (spec OB-35).
    func follow() {
        place(animated: true)
    }

    private func place(animated: Bool) {
        guard lastSize != .zero, let screen = Self.screen else { return }
        let bounds = screen.frame.insetBy(dx: Self.margin, dy: Self.margin)
        let top = anchor() ?? CGPoint(x: screen.frame.midX, y: screen.visibleFrame.maxY - Self.gap)
        let bottom = screen.visibleFrame.minY + Self.margin
        let height = min(lastSize.height, max(top.y - bottom, 120))
        var frame = CGRect(x: top.x - lastSize.width / 2, y: top.y - height, width: lastSize.width, height: height)
        frame.origin.x = min(max(frame.minX, bounds.minX), bounds.maxX - frame.width)
        frame.origin.y = max(frame.minY, bottom)
        guard frame != self.frame else { return }
        if animated, alphaValue == 1, !AppleStyle.reducesMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().setFrame(frame, display: true)
            }
        } else {
            setFrame(frame, display: true)
        }
        invalidateShadow()
        if alphaValue < 1 {
            alphaValue = 1
            makeKey()
        }
    }

    func dismiss() {
        orderOut(nil)
    }
}

/// The card's look: the chosen design, rounded, sized to its content (spec OB-30).
struct CardContainer<Content: View>: View {
    let design: NotchDesign
    let onSize: (CGSize) -> Void
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }

    var body: some View {
        content
            .background(background)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.12)))
            .environment(\.colorScheme, .dark)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onSize($0) }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var background: some View {
        switch design {
        case .black:
            Color.black
        case .glass:
            BehindWindowBlur().overlay(Color.black.opacity(0.35))
        case .blend:
            BehindWindowBlur().overlay(
                LinearGradient(colors: [.black, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
            )
        }
    }
}

/// A scroll area exactly as tall as its content, up to `maxHeight` (spec OB-30).
struct FittingScroll<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            content
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(max(height, 1), max(maxHeight, 120)))
    }
}
