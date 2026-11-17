import SwiftUI

/// The modules under the closed notch (spec MS-1): see-through blurred circles with clear white
/// icons; a click opens the notch on that module.
struct ModuleStripView: View {
    let features: [FeatureID]
    /// Where the pointer was, from the notch's middle: the icons swim out from there (spec MS-1b).
    var origin: CGFloat = 0
    let open: (FeatureID) -> Void

    @State private var hovered: FeatureID?
    @State private var isOut = false

    var body: some View {
        HStack(spacing: NotchGeometry.stripSpacing) {
            ForEach(Array(features.enumerated()), id: \.element) { index, feature in
                Button {
                    open(feature)
                } label: {
                    Image(systemName: feature.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                        .frame(width: NotchGeometry.stripIconSize, height: NotchGeometry.stripIconSize)
                        .background(Circle().fill(.ultraThinMaterial))
                        .background(Circle().fill(Color.black.opacity(hovered == feature ? 0.35 : 0.15)))
                        .overlay(Circle().stroke(Color.white.opacity(hovered == feature ? 0.5 : 0.22), lineWidth: 1))
                        .scaleEffect(hovered == feature ? 1.1 : 1)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: isOut ? 0 : origin - slotX(index))
                .scaleEffect(isOut ? 1 : 0.4)
                .opacity(isOut ? 1 : 0)
                .help(feature.title)
                .onHover { inside in
                    withAnimation(Motion.hover) {
                        if inside {
                            hovered = feature
                        } else if hovered == feature {
                            hovered = nil
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) { isOut = true }
        }
        .transition(.opacity)
    }

    /// An icon's centre, from the strip's middle.
    private func slotX(_ index: Int) -> CGFloat {
        let step = NotchGeometry.stripIconSize + NotchGeometry.stripSpacing
        return (CGFloat(index) - CGFloat(features.count - 1) / 2) * step
    }
}

/// Which modules the strip shows (spec MS-5); all by default.
enum ModuleStripChoice {
    private static let key = "moduleStripHidden"

    static var hidden: Set<FeatureID> {
        Set((UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(FeatureID.init(rawValue:)))
    }

    static func setShown(_ feature: FeatureID, _ shown: Bool) {
        var set = hidden
        if shown { set.remove(feature) } else { set.insert(feature) }
        UserDefaults.standard.set(set.map(\.rawValue).sorted(), forKey: key)
    }

    static func features(from active: [FeatureID]) -> [FeatureID] {
        let hidden = hidden
        return active.filter { !hidden.contains($0) }
    }
}
