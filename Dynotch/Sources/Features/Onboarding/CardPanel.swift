import AppKit
import SwiftUI

/// A floating card window, exactly as big as its content and draggable with the mouse; used by
/// the tour and What's new (spec OB-30, OB-31, WN-1).
final class CardPanel: NSPanel {
    static let margin: CGFloat = 10
    /// Where the user dragged it (top centre), kept until it closes (spec OB-31).
    private var userAnchor: CGPoint?
    private var isPlacing = false
    private var lastSize: CGSize = .zero
    /// Lower down, the top edge at the screen's middle, so the real notch opens freely above it.
    private var anchorsLow = false

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
        isMovable = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        alphaValue = 0
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        contentView = hosting
        delegate = self
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

    /// Moved by the user, not by `fit` (spec OB-31).
    fileprivate func userMoved() {
        guard !isPlacing else { return }
        userAnchor = CGPoint(x: frame.midX, y: frame.maxY)
    }

    func setAnchorsLow(_ low: Bool) {
        guard anchorsLow != low else { return }
        anchorsLow = low
        if lastSize != .zero { fit(lastSize) }
    }

    /// Takes the content's size, keeping the top edge where it was (spec OB-30, OB-31).
    func fit(_ size: CGSize) {
        guard size.width > 1, size.height > 1, let screen = Self.screen else { return }
        lastSize = size
        let area = screen.visibleFrame.insetBy(dx: Self.margin, dy: Self.margin)
        let anchor = userAnchor ?? CGPoint(x: area.midX, y: anchorsLow ? screen.frame.midY : area.maxY)
        let height = min(size.height, area.height)
        var frame = CGRect(x: anchor.x - size.width / 2, y: anchor.y - height, width: size.width, height: height)
        frame.origin.x = min(max(frame.minX, area.minX), area.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, area.minY), area.maxY - frame.height)
        isPlacing = true
        setFrame(frame, display: true)
        isPlacing = false
        invalidateShadow()
        if alphaValue < 1 {
            alphaValue = 1
            makeKey()
        }
    }

    func dismiss() {
        delegate = nil
        orderOut(nil)
    }
}

extension CardPanel: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        userMoved()
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
            .overlay(alignment: .top) { CardGrip() }
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

/// The handle at the card's top: drag it to move the card (spec OB-31).
private struct CardGrip: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.25))
            .frame(width: 36, height: 4)
            .frame(width: 140, height: 14)
            .background(WindowDragArea())
            .padding(.top, 3)
            .accessibilityLabel("Move")
    }
}

private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}
