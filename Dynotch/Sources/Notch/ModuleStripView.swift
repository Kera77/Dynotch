import SwiftUI

/// The modules under the closed notch (spec MS-1): see-through blurred circles with clear white
/// icons; a click opens the notch on that module.
struct ModuleStripView: View {
    let features: [FeatureID]
    /// Where the pointer was, from the notch's middle: the icons swim out from there (spec MS-1b).
    var origin: CGFloat = 0
    let open: (FeatureID) -> Void
    /// Dragging an icon sideways puts it to a new place (spec MS-6).
    var move: (FeatureID, Int) -> Void = { _, _ in }

    @State private var hovered: FeatureID?
    @State private var isOut = false
    @State private var dragged: FeatureID?
    @State private var dragX: CGFloat = 0

    var body: some View {
        HStack(spacing: NotchGeometry.stripSpacing) {
            ForEach(Array(features.enumerated()), id: \.element) { index, feature in
                Button {
                    open(feature)
                } label: {
                    Image(systemName: feature.symbolName)
                        .font(.notch(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                        .frame(width: NotchGeometry.stripIconSize, height: NotchGeometry.stripIconSize)
                        .background(Circle().fill(.ultraThinMaterial))
                        .background(Circle().fill(Color.black.opacity(hovered == feature ? 0.35 : 0.15)))
                        .overlay(Circle().stroke(Color.white.level(hovered == feature ? 0.5 : 0.22), lineWidth: 1))
                        .scaleEffect(hovered == feature ? 1.1 : 1)
                        .contentShape(Circle())
                }
                .buttonStyle(.notch)
                .offset(x: dragOffset(of: feature, at: index))
                .zIndex(dragged == feature ? 1 : 0)
                .highPriorityGesture(drag(feature, from: index))
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
            withAnimation(AppleStyle.spring(response: 0.22, dampingFraction: 0.82)) { isOut = true }
        }
        .transition(.opacity)
    }

    private var step: CGFloat { NotchGeometry.stripIconSize + NotchGeometry.stripSpacing }

    /// Where the dragged icon would land.
    private func target(from index: Int) -> Int {
        min(max(index + Int((dragX / step).rounded()), 0), features.count - 1)
    }

    /// The dragged icon follows the pointer; the ones it passes step aside.
    private func dragOffset(of feature: FeatureID, at index: Int) -> CGFloat {
        guard let dragged, let from = features.firstIndex(of: dragged) else { return 0 }
        if feature == dragged { return dragX }
        let landing = target(from: from)
        if from < landing, index > from, index <= landing { return -step }
        if landing < from, index >= landing, index < from { return step }
        return 0
    }

    private func drag(_ feature: FeatureID, from index: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragged == nil { withAnimation(Motion.hover) { dragged = feature } }
                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.86)) { dragX = value.translation.width }
            }
            .onEnded { _ in
                let landing = target(from: index)
                withAnimation(AppleStyle.spring(response: 0.26, dampingFraction: 0.84)) {
                    if landing != index { move(feature, landing) }
                    dragged = nil
                    dragX = 0
                }
            }
    }

    /// An icon's centre, from the strip's middle.
    private func slotX(_ index: Int) -> CGFloat {
        (CGFloat(index) - CGFloat(features.count - 1) / 2) * step
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
