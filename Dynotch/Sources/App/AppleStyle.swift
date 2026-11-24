import AppKit
import SwiftUI

/// The Apple style (spec D-15, D-16): the notch's only look, close to Apple's own design.
enum AppleStyle {
    /// The system's accessibility settings (spec D-15f).
    nonisolated static var reducesMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    nonisolated static var reducesTransparency: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
    nonisolated static var increasesContrast: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }

    /// The trial crisp look (spec D-18): deeper glass, lighter fills, stronger text. On by default.
    nonisolated static let crispKey = "crispLook"
    nonisolated static var crisp: Bool { UserDefaults.standard.object(forKey: crispKey) as? Bool ?? true }

    // MARK: - Type (spec D-15a)

    /// The macOS text style sizes: nothing below 9 pt, no 14 pt between body and title 3.
    nonisolated static func textSize(_ size: CGFloat) -> CGFloat {
        switch size {
        case ..<9: return 9
        case 14: return 13
        default: return size
        }
    }

    /// Regular, medium and semibold only; bold and heavier stay for large type.
    nonisolated static func weight(_ weight: Font.Weight, size: CGFloat) -> Font.Weight {
        guard size <= 15, [Font.Weight.bold, .heavy, .black].contains(weight) else { return weight }
        return .semibold
    }

    // MARK: - Levels of white (spec D-15c)

    /// White on the dark notch in four levels, like the system's label colors, instead of a
    /// dozen opacities: primary, secondary, tertiary and the fills below them.
    nonisolated static func level(_ opacity: Double, crisp: Bool = AppleStyle.crisp) -> Double {
        let contrast = increasesContrast
        // Crisp: stronger text, lighter grey fills (spec D-18).
        let crisp = !contrast && crisp
        switch opacity {
        // Nearly invisible fills only catch the mouse: they stay as they are.
        case ..<0.03: return opacity
        case 0.78...: return contrast || crisp ? 1 : 0.86
        case 0.5..<0.78: return contrast ? 0.75 : crisp ? 0.68 : 0.6
        case 0.3..<0.5: return contrast ? 0.55 : 0.4
        case 0.12..<0.3: return contrast ? 0.24 : crisp ? 0.12 : 0.16
        case 0.07..<0.12: return contrast ? 0.16 : crisp ? 0.06 : 0.1
        default: return contrast ? 0.1 : crisp ? 0.035 : 0.05
        }
    }

    // MARK: - Corners (spec D-15d)

    /// Concentric corners: controls 6, rows 8, cards 12, the panel's own larger ones untouched.
    nonisolated static func corner(_ radius: CGFloat) -> CGFloat {
        switch radius {
        case ..<4: return radius
        case 4..<5.5: return 4
        case 5.5..<7: return 6
        case 7..<10: return 8
        case 10..<15: return 12
        default: return radius
        }
    }

    // MARK: - Motion (spec D-15g)

    /// The system's smooth or snappy animation instead of a spring; with *Reduce motion* a short
    /// fade-like ease.
    static func spring(response: Double, dampingFraction: Double) -> Animation {
        if reducesMotion { return .easeInOut(duration: 0.15) }
        return dampingFraction < 0.75 ? .snappy(duration: response) : .smooth(duration: response)
    }
}

extension Font {
    /// `Font.system(size:weight:design:)` that follows the Apple style's type ladder (spec D-15a).
    static func notch(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let size = AppleStyle.textSize(size)
        return .system(size: size, weight: AppleStyle.weight(weight, size: size), design: design)
    }
}

extension Color {
    /// The nearest of the four levels of white to this opacity (spec D-15c).
    func level(_ opacity: Double) -> Color {
        self.opacity(AppleStyle.level(opacity))
    }
}

extension View {
    /// Numbers that change roll over (spec D-15h).
    func numericTransition() -> some View {
        monospacedDigit().contentTransition(.numericText())
    }

    /// A symbol that changes (play and pause, mute) is replaced with the system's effect (spec D-15h).
    func symbolReplace() -> some View {
        contentTransition(.symbolEffect(.replace))
    }
}

// MARK: - Buttons (spec D-15e, D-15i)

/// The plain button of the notch with a hover highlight and a pressed state, like the system's
/// borderless buttons.
struct NotchButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(configuration).buttonStyle(AppleHoverButtonStyle())
    }
}

extension PrimitiveButtonStyle where Self == NotchButtonStyle {
    static var notch: NotchButtonStyle { NotchButtonStyle() }
}

private struct AppleHoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration)
    }

    private struct HoverBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .background {
                    HoverHighlight(opacity: configuration.isPressed ? 0.14 : (isHovered ? 0.08 : 0))
                }
                .opacity(configuration.isPressed ? 0.7 : 1)
                .onHover { isHovered = isEnabled && $0 }
                .animation(Motion.hover, value: isHovered)
        }
    }
}

/// The hover and pressed highlight of a notch button, following the control's shape: a capsule
/// for a small icon button, at most a 10 pt curve for a larger row (spec D-15j).
struct HoverHighlight: View {
    let opacity: Double

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: proxy.size.width + 6, height: proxy.size.height + 6)
            RoundedRectangle(cornerRadius: Self.radius(for: size), style: .continuous)
                .fill(Color.white.opacity(opacity))
                .frame(width: size.width, height: size.height)
                .offset(x: -3, y: -3)
        }
    }

    nonisolated static func radius(for size: CGSize) -> CGFloat {
        min(min(size.width, size.height) / 2, 10)
    }
}

// MARK: - Root

/// The Apple style's environment for the notch: hierarchical symbols (spec D-15h).
struct AppleStyleRoot: ViewModifier {
    func body(content: Content) -> some View {
        content.symbolRenderingMode(.hierarchical)
    }
}
