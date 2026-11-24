import SwiftUI

/// The modules under the closed notch (spec MS-1): see-through blurred circles with clear white
/// icons; a click opens the notch on that module.
struct ModuleStripView: View {
    let features: [FeatureID]
    /// Where the pointer was, from the notch's middle: the icons swim out from there (spec MS-1b).
    var origin: CGFloat = 0
    /// Under the Wings the icons come down from above, one after the other (spec PV-28).
    var fromAbove = false
    let open: (FeatureID) -> Void
    /// Dragging an icon sideways puts it to a new place (spec MS-6).
    var move: (FeatureID, Int) -> Void = { _, _ in }
    /// Resting on an icon this long opens it too; nil: only a click does (spec MS-7).
    var hoverOpenDelay: Double?
    /// Under the Wings resting on an icon only switches the Wings to it; a click opens (spec MS-8).
    var hoverSwitch: ((FeatureID) -> Void)?
    /// How long the pointer rests on an icon before the Wings switch to it (spec MS-9).
    var hoverSwitchDelay: Double = 0

    @State private var hovered: FeatureID?
    @State private var isOut = false
    @State private var dragged: FeatureID?
    @State private var dragX: CGFloat = 0
    @State private var hoverOpen: Task<Void, Never>?

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
                .offset(x: isOut || fromAbove ? 0 : origin - slotX(index), y: isOut || !fromAbove ? 0 : -NotchGeometry.stripIconSize)
                .scaleEffect(isOut ? 1 : fromAbove ? 0.8 : 0.4)
                .opacity(isOut ? 1 : 0)
                .animation(
                    fromAbove ? Motion.spring
                        : Motion.quick,
                    value: isOut
                )
                .help(feature.title)
                .onHover { inside in
                    withAnimation(Motion.hover) {
                        if inside {
                            hovered = feature
                        } else if hovered == feature {
                            hovered = nil
                        }
                    }
                    if let hoverSwitch {
                        scheduleHoverAction(inside && dragged == nil ? feature : nil, delay: hoverSwitchDelay, hoverSwitch)
                    } else {
                        scheduleHoverAction(inside ? feature : nil, delay: hoverOpenDelay, open)
                    }
                }
            }
        }
        .onAppear { isOut = true }
        .onDisappear { hoverOpen?.cancel() }
        .transition(.opacity)
    }

    /// Starts the wait again on every icon; leaving the strip or dragging cancels it (spec MS-7, MS-9).
    private func scheduleHoverAction(_ feature: FeatureID?, delay: Double?, _ action: @escaping (FeatureID) -> Void) {
        hoverOpen?.cancel()
        hoverOpen = nil
        guard let feature, let delay else { return }
        guard delay > 0 else { return action(feature) }
        hoverOpen = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, hovered == feature, dragged == nil else { return }
            action(feature)
        }
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
                if dragged == nil {
                    hoverOpen?.cancel()
                    withAnimation(Motion.hover) { dragged = feature }
                }
                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.86)) { dragX = value.translation.width }
            }
            .onEnded { _ in
                let landing = target(from: index)
                withAnimation(Motion.quick) {
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
