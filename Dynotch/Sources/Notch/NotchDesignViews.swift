import AppKit
import SwiftUI

// MARK: - Design (spec D-1…D-4)

private struct NotchDesignKey: EnvironmentKey {
    static let defaultValue = NotchDesign.black
}

extension EnvironmentValues {
    /// The look of the open notch and the menu bar panels.
    var notchDesign: NotchDesign {
        get { self[NotchDesignKey.self] }
        set { self[NotchDesignKey.self] = newValue }
    }
}

/// Passes the chosen design down and keeps it current.
struct DesignEnvironment<Content: View>: View {
    @ObservedObject var settings: AppSettings
    let content: Content

    var body: some View {
        content.environment(\.notchDesign, settings.design)
    }
}

/// Dark liquid glass: the system's glass from macOS 26, a dark material before. Tinted dark so
/// white text stays readable in front of a light background (spec D-2).
struct GlassFill<S: Shape>: View {
    let shape: S

    var body: some View {
        if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular.tint(Color.black.opacity(0.45)), in: shape)
        } else {
            shape.fill(.ultraThinMaterial).overlay(shape.fill(Color.black.opacity(0.45)))
        }
    }
}

/// Which part of the design a window draws. The glass sits in a window of its own that never
/// takes the keyboard: the system draws glass darker, nearly black, in a window that has it
/// (spec D-6).
enum DesignLayer: Sendable {
    /// The content's window: the black parts.
    case content
    /// The window behind it: only the glass.
    case glass
}

/// The background of the notch and the menu bar panels in the chosen design. `isOpen` false:
/// black, like the closed notch, whatever the design (spec D-3).
struct DesignBackground<S: Shape>: View {
    let design: NotchDesign
    let shape: S
    var isOpen = true
    var layer = DesignLayer.content
    /// The solid colour of the black design.
    var solid = Color.black

    /// Black to glass: black over the top row, then fading out.
    static var blendMask: LinearGradient {
        LinearGradient(
            stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.12), .init(color: .clear, location: 0.55)],
            startPoint: .top, endPoint: .bottom
        )
    }

    var body: some View {
        let glass = isOpen && design != .black
        switch layer {
        case .glass:
            GlassFill(shape: shape)
                .opacity(glass ? 1 : 0)
        case .content:
            ZStack {
                shape.fill(solid)
                    .opacity(glass ? 0 : 1)
                if design == .blend {
                    shape.fill(solid)
                        .mask(Self.blendMask)
                        .opacity(glass ? 1 : 0)
                }
            }
        }
    }
}

/// The glass behind a menu bar panel, in the window under it (spec D-4, D-6).
struct PopoverGlassLayer: View {
    @ObservedObject var state: MenuBarPanelState
    @Environment(\.notchDesign) private var design

    var body: some View {
        DesignBackground(design: design, shape: PopoverShape(arrowX: state.arrowX), layer: .glass)
            .padding(1)
    }
}

/// A window that only shows the glass: never takes the keyboard or the mouse.
final class GlassPanel: NSPanel {
    init(level: NSWindow.Level) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // Like the notch panel, it may cover the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
