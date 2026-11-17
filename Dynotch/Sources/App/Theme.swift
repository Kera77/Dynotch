import AppKit
import SwiftUI

/// Dynotch's colours, corners and motion in one place (spec D-8).
enum Theme {
    /// The blue of buttons, selections and sent messages.
    static let blue = Color(red: 0.04, green: 0.52, blue: 1)
    static let nsBlue = NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
    static let green = Color(red: 0.2, green: 0.84, blue: 0.4)
    static let red = Color(red: 1, green: 0.45, blue: 0.4)

    /// Fills on the dark notch: a control, a hovered or selected row.
    static let fill = Color.white.opacity(0.1)
    static let selectedFill = Color.white.opacity(0.16)

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }
}

/// Three kinds of motion instead of a dozen timings (spec D-9).
enum Motion {
    /// Opening, closing and resizing the notch.
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
    /// Switching a tab, showing or hiding a small part.
    static let quick = Animation.easeOut(duration: 0.15)
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
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .background(Capsule().fill(Theme.blue))
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item == selection ? Color.black : Color.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background(Capsule().fill(item == selection ? Color.white : .clear))
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

/// An empty or failed state, the same everywhere (spec D-11): a symbol, one sentence, and what
/// to do about it.
struct EmptyStateView: View {
    let symbol: String
    let text: String
    var actionTitle: String?
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.45))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
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
