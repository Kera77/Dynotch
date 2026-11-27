import AppKit

/// The dimmed layer over every display for picking an area or a window (spec SH-2): drag a
/// rectangle, or click the highlighted window; Esc or a right click cancels.
@MainActor
final class SelectionOverlay {
    enum Kind { case area, window }

    /// Made and used on the main thread only.
    enum Result: @unchecked Sendable {
        case area(CGRect, NSScreen)
        case window(CGWindowID, CGRect)
        case cancelled
    }

    private var windows: [NSWindow] = []
    private var continuation: CheckedContinuation<Result, Never>?
    private var previousApp: NSRunningApplication?
    private static var current: SelectionOverlay?

    static func run(_ kind: Kind) async -> Result {
        current?.finish(.cancelled)
        let overlay = SelectionOverlay()
        current = overlay
        return await withCheckedContinuation { continuation in
            overlay.continuation = continuation
            overlay.show(kind)
        }
    }

    private func show(_ kind: Kind) {
        previousApp = NSWorkspace.shared.frontmostApplication
        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size), kind: kind, screen: screen)
            view.done = { [weak self] result in self?.finish(result) }
            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
        }
        NSApp.activate()
        let pointer = NSEvent.mouseLocation
        let start = windows.first { $0.frame.contains(pointer) } ?? windows.first
        start?.makeKey()
        start.map { _ = $0.makeFirstResponder($0.contentView) }
        // A cross while picking, like other screenshot tools (spec SH-2).
        windows.forEach { $0.invalidateCursorRects(for: $0.contentView ?? NSView()) }
        NSCursor.crosshair.set()
    }

    private func finish(_ result: Result) {
        guard let continuation else { return }
        self.continuation = nil
        NSCursor.arrow.set()
        windows.forEach { $0.orderOut(nil) }
        windows = []
        if Self.current === self { Self.current = nil }
        // The app that was in front gets the keyboard back.
        previousApp?.activate()
        continuation.resume(returning: result)
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Draws the dimming, the dragged rectangle with its size, or the window under the pointer.
private final class SelectionView: NSView {
    let kind: SelectionOverlay.Kind
    let screen: NSScreen
    var done: (SelectionOverlay.Result) -> Void = { _ in }
    private var start: CGPoint?
    private var current: CGPoint?
    private var hovered: (id: CGWindowID, frame: CGRect)?

    init(frame: CGRect, kind: SelectionOverlay.Kind, screen: NSScreen) {
        self.kind = kind
        self.screen = screen
        super.init(frame: frame)
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var selection: CGRect? {
        guard let start, let current else { return nil }
        return Annotation.rect(start, current)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()
        let cut: CGRect? = kind == .area ? selection : hovered.map { convert(fromGlobal: $0.frame) }
        guard let cut else { return }
        NSColor.clear.setFill()
        cut.fill(using: .copy)
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let border = NSBezierPath(rect: cut.insetBy(dx: -0.5, dy: -0.5))
        border.lineWidth = 1
        border.stroke()
        if kind == .area { drawSize(of: cut) }
    }

    private func drawSize(of rect: CGRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let origin = CGPoint(x: rect.maxX - size.width - 6, y: max(rect.minY - size.height - 8, 4))
        let back = CGRect(origin: origin, size: size).insetBy(dx: -5, dy: -2)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: back, xRadius: 4, yRadius: 4).fill()
        text.draw(at: origin, withAttributes: attributes)
    }

    private func convert(fromGlobal rect: CGRect) -> CGRect {
        rect.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
        guard kind == .window else { return }
        let found = ScreenCapture.window(at: NSEvent.mouseLocation)
        if found?.id != hovered?.id {
            hovered = found
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        if kind == .window {
            if let hovered { done(.window(hovered.id, hovered.frame)) }
            return
        }
        start = convert(event.locationInWindow, from: nil)
        current = start
    }

    override func mouseDragged(with event: NSEvent) {
        guard kind == .area else { return }
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard kind == .area, let selection else { return }
        start = nil
        // A click without dragging takes nothing.
        guard selection.width >= 4, selection.height >= 4 else {
            needsDisplay = true
            return
        }
        done(.area(selection.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY), screen))
    }

    override func rightMouseDown(with event: NSEvent) { done(.cancelled) }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { done(.cancelled) } else { super.keyDown(with: event) }
    }
}
