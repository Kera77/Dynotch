import AppKit
import SwiftUI

/// The Apple style (spec D-15): the notch closer to Apple's own design, switchable against the
/// current look in *Settings › Appearance* to compare them. Off, everything stays as it was.
/// The values are read while drawing; switching rebuilds the notch (`AppleStyleRoot`).
enum AppleStyle {
    static let key = "appleStyle"

    nonisolated static var isOn: Bool { UserDefaults.standard.bool(forKey: key) }

    /// The system's accessibility settings, followed only in the Apple style (spec D-15f).
    nonisolated static var reducesMotion: Bool { isOn && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    nonisolated static var reducesTransparency: Bool {
        isOn && NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
    nonisolated static var increasesContrast: Bool {
        isOn && NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }

    // MARK: - Type (spec D-15a)

    /// The macOS text style sizes: nothing below 9 pt, no 14 pt between body and title 3.
    nonisolated static func textSize(_ size: CGFloat) -> CGFloat {
        guard isOn else { return size }
        switch size {
        case ..<9: return 9
        case 14: return 13
        default: return size
        }
    }

    /// Regular, medium and semibold only; bold and heavier stay for large type.
    nonisolated static func weight(_ weight: Font.Weight, size: CGFloat) -> Font.Weight {
        guard isOn, size <= 15, [Font.Weight.bold, .heavy, .black].contains(weight) else { return weight }
        return .semibold
    }

    // MARK: - Levels of white (spec D-15c)

    /// White on the dark notch in four levels, like the system's label colors, instead of a
    /// dozen opacities: primary, secondary, tertiary and the fills below them.
    nonisolated static func level(_ opacity: Double) -> Double {
        guard isOn else { return opacity }
        let contrast = increasesContrast
        switch opacity {
        // Nearly invisible fills only catch the mouse: they stay as they are.
        case ..<0.03: return opacity
        case 0.78...: return contrast ? 1 : 0.86
        case 0.5..<0.78: return contrast ? 0.75 : 0.6
        case 0.3..<0.5: return contrast ? 0.55 : 0.4
        case 0.12..<0.3: return contrast ? 0.24 : 0.16
        case 0.07..<0.12: return contrast ? 0.16 : 0.1
        default: return contrast ? 0.1 : 0.05
        }
    }

    // MARK: - Corners (spec D-15d)

    /// Concentric corners: controls 6, rows 8, cards 12, the panel's own larger ones untouched.
    nonisolated static func corner(_ radius: CGFloat) -> CGFloat {
        guard isOn else { return radius }
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

    /// A spring, or in the Apple style the system's smooth or snappy one; with *Reduce motion*
    /// a short fade-like ease.
    static func spring(response: Double, dampingFraction: Double) -> Animation {
        guard isOn else { return .spring(response: response, dampingFraction: dampingFraction) }
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
    /// This opacity, or in the Apple style the nearest of the four levels (spec D-15c).
    func level(_ opacity: Double) -> Color {
        self.opacity(AppleStyle.level(opacity))
    }

    /// This colour, or in the Apple style the system colour that adapts to the accessibility
    /// settings (spec D-15b).
    func apple(_ system: Color) -> Color {
        AppleStyle.isOn ? system : self
    }
}

extension View {
    /// Numbers that change roll over in the Apple style (spec D-15h).
    @ViewBuilder func numericTransition() -> some View {
        if AppleStyle.isOn {
            monospacedDigit().contentTransition(.numericText())
        } else {
            self
        }
    }

    /// A symbol that changes (play and pause, mute) is replaced with the system's effect (spec D-15h).
    @ViewBuilder func symbolReplace() -> some View {
        if AppleStyle.isOn {
            contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }
}

// MARK: - Buttons (spec D-15e, D-15i)

/// The plain button of the notch: as before, or in the Apple style with a hover highlight and
/// a pressed state, like the system's borderless buttons.
struct NotchButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if AppleStyle.isOn {
            Button(configuration).buttonStyle(AppleHoverButtonStyle())
        } else {
            PlainButtonStyle().makeBody(configuration: configuration)
        }
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
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(configuration.isPressed ? 0.14 : (isHovered ? 0.08 : 0)))
                        .padding(-3)
                }
                .opacity(configuration.isPressed ? 0.7 : 1)
                .onHover { isHovered = isEnabled && $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
    }
}

// MARK: - Root

/// Rebuilds the notch when the Apple style is switched, and gives it the style's environment:
/// hierarchical symbols (spec D-15).
struct AppleStyleRoot: ViewModifier {
    @AppStorage(AppleStyle.key) private var isOn = false

    func body(content: Content) -> some View {
        if isOn {
            content
                .symbolRenderingMode(.hierarchical)
                .id(true)
        } else {
            content.id(false)
        }
    }
}
