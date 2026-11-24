import AppKit
import SwiftUI

/// Borderless, non-activating panel that sits on top of the menu bar at the notch (spec N-6, N-7).
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
    }

    /// The panel only takes keyboard focus while it shows the settings, so its controls look
    /// and behave like in an active window.
    var allowsKey = false
    /// The pointer (screen point) is over the open notch, where typing must not be cut off;
    /// outside it focus may follow the mouse away (spec F-4, F-17).
    var keepsKeyboard: (CGPoint) -> Bool = { _ in true }
    /// Gives the keyboard back to the app in front for real (spec F-15c, F-17).
    var letGoOfKeyboard: () -> Void = {}

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    // Allow covering the menu bar; the default implementation pushes windows below it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Lets buttons react to the first click even though the panel never becomes key.
/// Its content never slides: no "make this visible" scroll moves it, and a shift is undone and
/// logged, so the notch's top row always stays in view (spec N-26).
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollToVisible(_ rect: NSRect) -> Bool { false }

    override func setBoundsOrigin(_ newOrigin: NSPoint) {
        if newOrigin != .zero {
            DiagnosticsLog.append("notch-layout", "content shift undone: \(newOrigin)")
        }
        super.setBoundsOrigin(.zero)
    }
}
