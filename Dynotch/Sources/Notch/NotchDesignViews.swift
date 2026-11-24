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
    /// How dark the glass is tinted; the refined design follows the wallpaper (spec D-14c).
    var tint = 0.45
    /// The system accent colour mixed into the dark tint, so the glass is not a neutral grey;
    /// nil keeps it black (spec D-17, D-17b).
    var accent: NSColor?
    /// Crisp look: the clearer glass over a full blur, tinted deeper (spec D-18).
    var crisp = false
    /// How much of the accent goes into the tint: more under Black to glass, whose lighter,
    /// regular glass otherwise hid it (spec D-17d).
    var accentShare: CGFloat = 0.18
    /// A wash of the accent laid over the glass: the regular glass of Black to glass hid even a
    /// stronger tint (spec D-17e).
    var accentWash: Double = 0

    /// The tint's colour: black, or black with a share of the accent colour.
    private var tintColor: Color {
        guard let accent, let rgb = accent.usingColorSpace(.sRGB),
              let mixed = NSColor.black.blended(withFraction: accentShare, of: rgb) else { return .black }
        return Color(nsColor: mixed)
    }

    var body: some View {
        if AppleStyle.reducesTransparency {
            // *Reduce transparency* in the Apple style: solid, like the system (spec D-15f).
            shape.fill(Color(white: 0.12))
        } else if #available(macOS 26.0, *) {
            Color.clear.glassEffect((crisp ? Glass.clear : .regular).tint(tintColor.opacity(tint)), in: shape)
                .overlay { wash }
        } else {
            shape.fill(.ultraThinMaterial).overlay(shape.fill(tintColor.opacity(tint))).overlay { wash }
        }
    }

    @ViewBuilder private var wash: some View {
        if let accent, accentWash > 0 {
            shape.fill(Color(nsColor: accent).opacity(accentWash)).allowsHitTesting(false)
        }
    }

    /// The accent's share of the tint and its wash for a design at a strength, 0.5 being the
    /// default (spec D-17d, D-17e, D-17f).
    nonisolated static func accent(blend: Bool, strength: Double) -> (share: CGFloat, wash: Double) {
        let scale = strength / 0.5
        if blend { return (min(0.35 * scale, 0.9), 0.12 * scale) }
        return (min(0.18 * scale, 0.9), max(0, scale - 1) * 0.08)
    }
}

/// The refined design's soft shadow around the open panel, never inside it (spec D-14a).
struct OuterShadow<S: Shape>: View {
    let shape: S

    var body: some View {
        shape.fill(Color.black)
            .shadow(color: .black.opacity(0.38), radius: 16, y: 8)
            .mask {
                Rectangle()
                    .padding(-60)
                    .overlay(shape.fill(Color.black).blendMode(.destinationOut))
                    .compositingGroup()
            }
            .allowsHitTesting(false)
    }
}

/// Blurs what is behind the window: the desktop and other apps (spec D-13b).
struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
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
    /// The open panel's opacity (spec D-13); the closed notch is always fully black.
    var openOpacity = 1.0
    /// The top row's height, which stays black in the blend (spec D-14d).
    var topRow: CGFloat = 38
    /// The glass tint, following the wallpaper (spec D-14c).
    var glassTint = 0.45
    /// A touch of the accent colour in the glass (spec D-17).
    var glassAccent = false
    /// How strong the accent is (spec D-17f).
    var accentStrength = 0.5
    /// The notch panel's look (spec D-14, D-14e): rim light and a deepening black. The menu bar
    /// panels leave it off.
    var refined = false
    /// The trial crisp look (spec D-18), read here so the panel follows the switch at once.
    @AppStorage(AppleStyle.crispKey) private var crisp = true
    /// The accent colour set in macOS, followed live (spec D-17b).
    @ObservedObject private var systemAccent = SystemAccent.shared

    /// Refined black to glass: black over the top row, then an eased fade over 80 pt (spec D-14d).
    static func refinedBlendStops(height: CGFloat, topRow: CGFloat) -> [Gradient.Stop] {
        guard height > 0 else { return [.init(color: .black, location: 0)] }
        let start = min(topRow / height, 1)
        let span = 80 / height
        return (0...8).map { step in
            let part = Double(step) / 8
            let eased = part * part * (3 - 2 * part)
            return .init(color: .black.opacity(1 - eased), location: min(start + span * part, 1))
        }
    }

    /// How strong the extra blur is: none for a closed or fully black panel; for black a bit
    /// more than its opacity, so 40 % still blurs gently; under the glass most of it.
    /// Crisp: the clear glass blurs little itself, so the full blur keeps the content readable (spec D-18).
    nonisolated static func blurOpacity(glass: Bool, isOpen: Bool, openOpacity: Double, crisp: Bool = false) -> Double {
        guard isOpen else { return 0 }
        if glass { return (crisp ? 1 : 0.75) * openOpacity }
        return openOpacity < 1 ? min(1, openOpacity + 0.15) : 0
    }

    /// Crisp: a deeper tint, black rather than grey (spec D-18).
    nonisolated static func tint(_ base: Double, crisp: Bool) -> Double {
        crisp ? min(base + 0.15, 0.75) : base
    }

    var body: some View {
        let glass = isOpen && design != .black
        let open = isOpen ? openOpacity : 1
        switch layer {
        case .glass:
            ZStack {
                // A see-through black panel blurs what is behind it, the blur fading with the
                // opacity so the background shows through; under the glass it makes the
                // system's glass blur stronger (spec D-13b, D-13c).
                BehindWindowBlur()
                    .clipShape(shape)
                    .opacity(Self.blurOpacity(glass: glass, isOpen: isOpen, openOpacity: openOpacity, crisp: crisp))
                // Black to glass keeps the regular, lighter glass: deepened, it turned as black as
                // the top and the fade disappeared (spec D-18b).
                let deep = crisp && design != .blend
                let accent = GlassFill<S>.accent(blend: design == .blend, strength: accentStrength)
                GlassFill(
                    shape: shape, tint: Self.tint(glassTint, crisp: deep),
                    accent: glassAccent ? systemAccent.color : nil, crisp: deep,
                    accentShare: accent.share, accentWash: accent.wash
                )
                    .opacity(glass ? open : 0)
            }
        case .content:
            ZStack {
                shape.fill(solid)
                    .opacity(glass ? 0 : open)
                // Always there and faded: inserted, it would stand at the open size before the
                // panel has grown into it (spec PV-49).
                if refined, design == .black {
                    // Pure black at the top, merging with the notch; a touch lighter at the bottom.
                    shape.fill(LinearGradient(colors: [.clear, .white.level(0.045)], startPoint: .top, endPoint: .bottom))
                        .opacity(isOpen ? open : 0)
                }
                if design == .blend {
                    shape.fill(solid)
                        .mask { blendMask }
                        .opacity(glass ? open : 0)
                }
                if refined {
                    RimLight(shape: shape, topRow: topRow)
                        .opacity(isOpen ? 1 : 0)
                }
            }
        }
    }
}

extension DesignBackground {
    fileprivate var blendMask: some View {
        GeometryReader { proxy in
            LinearGradient(
                stops: Self.refinedBlendStops(height: proxy.size.height, topRow: topRow),
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}

/// A hairline of light along the open panel's edge: none at the top, where it meets the notch,
/// brightest below the top row, fading downwards (spec D-14a).
struct RimLight<S: Shape>: View {
    let shape: S
    let topRow: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let height = max(proxy.size.height, 1)
            let row = min(topRow / height, 0.9)
            // Twice the width: the panel's clip keeps the inner half.
            shape.stroke(
                LinearGradient(
                    stops: [
                        .init(color: .white.level(0), location: 0),
                        .init(color: .white.level(0), location: row * 0.6),
                        .init(color: .white.level(0.16), location: row + 0.08),
                        .init(color: .white.level(0.05), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: 1.5
            )
        }
        .allowsHitTesting(false)
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
