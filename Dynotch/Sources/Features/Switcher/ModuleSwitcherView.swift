import SwiftUI

/// The chosen modules in one row under the notch (spec QS-4, QS-12), like the switcher's App Icons.
struct ModuleSwitcherView: View {
    @ObservedObject var switcher: ModuleSwitcher
    let notchHeight: CGFloat
    let width: CGFloat

    /// Smaller tiles rather than a second row (spec QS-12).
    private var scale: CGFloat {
        ModuleSwitcher.rowScale(count: switcher.items.count, scale: switcher.settings.size.scale, width: width)
    }
    /// The highlight slides from one module to the next (spec AS-5b).
    @Namespace private var highlight

    var body: some View {
        let tile = SwitcherLayout.tile(.icons, scale: scale)
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: SwitcherLayout.spacing) {
                ForEach(Array(switcher.items.enumerated()), id: \.element) { index, feature in
                    entry(feature, isSelected: index == switcher.selection)
                        .frame(width: tile.width, height: tile.height)
                        .contentShape(Rectangle())
                        .onHover { if $0 { switcher.choose(index) } }
                        .onTapGesture { switcher.pick(index) }
                }
            }
            .padding(SwitcherLayout.padding)
            .animation(AppleStyle.spring(response: 0.25, dampingFraction: 0.8), value: switcher.selection)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func entry(_ feature: FeatureID, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppleStyle.corner(12) * scale, style: .continuous)
        return VStack(spacing: 4) {
            Image(systemName: feature.symbolName)
                .font(.system(size: 26 * scale, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 60 * scale, height: 60 * scale)
                .background(Circle().fill(Color.white.level(0.1)))
            Text(feature.title)
                .font(.notch(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(6)
        .background {
            if isSelected {
                shape.fill(Color.white.level(0.18))
                    .overlay(shape.strokeBorder(Theme.blue, lineWidth: 2))
                    .matchedGeometryEffect(id: "selection", in: highlight)
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1)
    }
}
