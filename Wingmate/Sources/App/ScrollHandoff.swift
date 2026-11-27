import AppKit
import SwiftUI

extension View {
    /// Put inside a small scroll view that sits in a larger one: once the small one reaches its
    /// end (or start), the scroll goes on in the larger one instead of bouncing (spec HT-55).
    func scrollHandoff() -> some View {
        background(ScrollHandoff())
    }
}

private struct ScrollHandoff: NSViewRepresentable {
    func makeNSView(context: Context) -> HandoffView { HandoffView() }
    func updateNSView(_ view: HandoffView, context: Context) {}
    static func dismantleNSView(_ view: HandoffView, coordinator: ()) { view.stop() }
}

/// Lives inside the small scroll view; watches the scroll events of its window.
private final class HandoffView: NSView {
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stop()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated { self?.route(event) ?? true } ? event : nil
        }
        DispatchQueue.main.async { [weak self] in self?.enclosingScrollView?.verticalScrollElasticity = .none }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// True: the event goes on as usual; false: the larger scroll view got it.
    private func route(_ event: NSEvent) -> Bool {
        guard let inner = enclosingScrollView, let outer = inner.superview?.enclosingScrollView,
              event.window === window, event.scrollingDeltaY != 0,
              abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX),
              inner.convert(inner.bounds, to: nil).contains(event.locationInWindow)
        else { return true }
        let down = event.scrollingDeltaY < 0
        let innerCanMove = down ? !Self.isAtEnd(inner) : !Self.isAtStart(inner)
        guard !innerCanMove else { return true }
        outer.scrollWheel(with: event)
        return false
    }

    private static func isAtStart(_ scrollView: NSScrollView) -> Bool {
        guard let document = scrollView.documentView else { return true }
        let shown = scrollView.contentView.documentVisibleRect
        return document.isFlipped ? shown.minY <= document.bounds.minY + 1 : shown.maxY >= document.bounds.maxY - 1
    }

    private static func isAtEnd(_ scrollView: NSScrollView) -> Bool {
        guard let document = scrollView.documentView else { return true }
        let shown = scrollView.contentView.documentVisibleRect
        return document.isFlipped ? shown.maxY >= document.bounds.maxY - 1 : shown.minY <= document.bounds.minY + 1
    }
}
