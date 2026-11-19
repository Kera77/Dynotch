import AppKit
import SwiftUI

/// Dynotch's colours, corners and motion in one place (spec D-8).
enum Theme {
    /// The blue of buttons, selections and sent messages.
    /// The Apple style takes the user's accent colour and the system colours (spec D-15b).
    static var blue: Color { Color(red: 0.04, green: 0.52, blue: 1).apple(.accentColor) }
    static var nsBlue: NSColor {
        AppleStyle.isOn ? .controlAccentColor : NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
    }
    static var green: Color { Color(red: 0.2, green: 0.84, blue: 0.4).apple(.green) }
    static var red: Color { Color(red: 1, green: 0.45, blue: 0.4).apple(.red) }

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
enum Motion {
    /// Opening, closing and resizing the notch.
    static var spring: Animation { AppleStyle.spring(response: 0.38, dampingFraction: 0.82) }
    /// Switching a tab, showing or hiding a small part; the system's snappy one in the Apple style (D-15g).
    static var quick: Animation {
        guard AppleStyle.isOn else { return .easeOut(duration: 0.15) }
        return AppleStyle.reducesMotion ? .easeInOut(duration: 0.12) : .snappy(duration: 0.2)
    }
    /// Hover highlights.
    static let hover = Animation.easeOut(duration: 0.12)
}

/// The capsule-shaped segmented choice used across the notch (spec D-10): tabs, services,
/// clipboard lists.
struct CapsulePicker<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    var badge: (Item) -> Int? = { _ in nil }
    @Namespace private var namespace

    var body: some View {
        let apple = AppleStyle.isOn
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
                                .background(Capsule().fill(apple ? Color.red : Theme.blue))
                        }
                    }
                    .font(.notch(size: 11, weight: apple && item != selection ? .medium : .semibold))
                    .foregroundStyle(labelColor(item == selection, apple: apple))
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background { selectionBackground(item == selection, apple: apple) }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == selection ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.fill))
    }

    private func labelColor(_ selected: Bool, apple: Bool) -> Color {
        if apple { return Color.white.opacity(selected ? 1 : 0.7) }
        return selected ? Color.black : Color.white.opacity(0.75)
    }

    /// The original: a white capsule. The Apple style: a lighter segment that slides, like the
    /// system's segmented control on dark (spec D-15e).
    @ViewBuilder private func selectionBackground(_ selected: Bool, apple: Bool) -> some View {
        if apple {
            if selected {
                Capsule().fill(Color.white.opacity(0.24))
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
                    .matchedGeometryEffect(id: "selection", in: namespace)
            }
        } else {
            Capsule().fill(selected ? Color.white : .clear)
        }
    }
}

/// An empty or failed state, the same everywhere (spec D-11): a symbol, one sentence, and what
/// to do about it.
struct EmptyStateView: View {
    let symbol: String
    let text: String
    var actionTitle: String?
    var action: () -> Void = {}

    var body: some View {
        if AppleStyle.isOn {
            // The system's own empty state (spec D-15e).
            ContentUnavailableView {
                Label(text, systemImage: symbol)
            } actions: {
                if let actionTitle { prominentButton(actionTitle) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            original
        }
    }

    @ViewBuilder private func prominentButton(_ title: String) -> some View {
        if #available(macOS 26.0, *) {
            Button(title, action: action).buttonStyle(.glassProminent).controlSize(.small)
        } else {
            Button(title, action: action).buttonStyle(.borderedProminent).controlSize(.small)
        }
    }

    private var original: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.notch(size: 22, weight: .medium))
                .foregroundStyle(Color.white.level(0.45))
            Text(text)
                .font(.notch(size: 12))
                .foregroundStyle(Color.white.level(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.notch)
                    .font(.notch(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Capsule().fill(Theme.blue))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
