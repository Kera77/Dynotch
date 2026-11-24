import AppKit
import SwiftUI

/// Dynotch's colours, corners and motion in one place (spec D-8).
enum Theme {
    /// The blue of buttons, selections and sent messages: the user's accent colour and the
    /// system colours (spec D-15b).
    static var blue: Color { .accentColor }
    static var nsBlue: NSColor { .controlAccentColor }
    static var green: Color { .green }
    static var red: Color { .red }

    /// Fills on the dark notch: a control, a hovered or selected row.
    static var fill: Color { Color.white.level(0.1) }
    static var selectedFill: Color { Color.white.level(0.16) }

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }
}

/// Three kinds of motion instead of a dozen timings (spec D-9).
/// The app's two tempos and the hover (spec D-19): every movement uses one of them.
enum Motion {
    /// Opening, closing and resizing the notch, and anything that moves as far.
    static var spring: Animation { AppleStyle.spring(response: 0.23, dampingFraction: 0.84) }
    /// Switching a tab, showing or hiding a small part: the system's snappy one (D-15g).
    static var quick: Animation {
        AppleStyle.reducesMotion ? .easeInOut(duration: 0.12) : .snappy(duration: 0.13)
    }
    /// Hover highlights.
    static let hover = Animation.easeOut(duration: 0.12)
}

/// The capsule-shaped segmented choice used across the notch (spec D-10): tabs, services,
/// clipboard lists. A lighter segment slides, like the system's segmented control on dark
/// (spec D-15e).
struct CapsulePicker<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    var badge: (Item) -> Int? = { _ in nil }
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(Motion.quick) { selection = item }
                } label: {
                    HStack(spacing: 4) {
                        Text(title(item))
                        if let count = badge(item), count > 0 {
                            Text("\(count)")
                                .font(.notch(size: 9, weight: .bold))
                                .numericTransition()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .background(Capsule().fill(Color.red))
                        }
                    }
                    .font(.notch(size: 11, weight: item != selection ? .medium : .semibold))
                    .foregroundStyle(Color.white.opacity(item == selection ? 1 : 0.7))
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background {
                        if item == selection {
                            Capsule().fill(Color.white.opacity(0.24))
                                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == selection ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.fill))
    }
}

/// An empty or failed state, the same everywhere (spec D-11): the system's own empty state
/// (spec D-15e) with a symbol, one sentence, and what to do about it.
struct EmptyStateView: View {
    let symbol: String
    let text: String
    var actionTitle: String?
    var action: () -> Void = {}

    /// Every module's empty state looks like the AI's "Ask … anything": a 26 pt symbol and
    /// 13 pt medium text, not the system's large bold title (spec D-20).
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.notch(size: 26))
                .foregroundStyle(Color.white.level(0.45))
            Text(text)
                .font(.notch(size: 13, weight: .medium))
                .foregroundStyle(Color.white.level(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle { prominentButton(actionTitle).padding(.top, 4) }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private func prominentButton(_ title: String) -> some View {
        if #available(macOS 26.0, *) {
            Button(title, action: action).buttonStyle(.glassProminent).controlSize(.small)
        } else {
            Button(title, action: action).buttonStyle(.borderedProminent).controlSize(.small)
        }
    }
}
