import AppKit
import SwiftUI

extension View {
    /// When `isOpen` turns true, the settings scroll so the whole opened row is in view, with no
    /// scrolling by hand (spec C-12).
    func revealWhenOpened(_ isOpen: Bool) -> some View {
        background(RevealAnchor(isOpen: isOpen))
    }
}

/// An invisible view the size of the row: it asks the enclosing scroll view to show it.
private struct RevealAnchor: NSViewRepresentable {
    let isOpen: Bool

    func makeNSView(context: Context) -> NSView { PassThroughView() }

    func updateNSView(_ view: NSView, context: Context) {
        guard isOpen, !context.coordinator.wasOpen else {
            context.coordinator.wasOpen = isOpen
            return
        }
        context.coordinator.wasOpen = true
        // After the opening animation has laid the row out at its new height.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NSAnimationContext.runAnimationGroup { animation in
                animation.duration = 0.2
                animation.allowsImplicitAnimation = true
                _ = view.scrollToVisible(view.bounds)
            }
        }
    }

    /// A row already open when the settings appear (spec SD-19) does not scroll to itself.
    func makeCoordinator() -> Coordinator { Coordinator(wasOpen: isOpen) }

    final class Coordinator {
        var wasOpen: Bool

        init(wasOpen: Bool) { self.wasOpen = wasOpen }
    }
}

/// Never takes the mouse: under a row it caught the drag that reorders it (spec M-15).
private final class PassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
