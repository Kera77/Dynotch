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

/// The background of the notch and the menu bar panels in the chosen design. `isOpen` false:
/// black, like the closed notch, whatever the design (spec D-3).
struct DesignBackground<S: Shape>: View {
    let design: NotchDesign
    let shape: S
    var isOpen = true
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
        ZStack {
            GlassFill(shape: shape)
                .opacity(glass ? 1 : 0)
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
