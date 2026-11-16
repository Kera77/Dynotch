import SwiftUI

/// Capsule-shaped icon switcher in the panel's top row (spec M-1). Holding Command while
/// dragging an icon reorders the features (spec M-6). During the drag the views keep their
/// order and only move by offsets, so the gesture is never interrupted; the order changes when
/// the icon is dropped.
struct FeatureSwitcher: View {
    let features: [FeatureID]
    let selected: FeatureID?
    let select: (FeatureID) -> Void
    let move: (FeatureID, Int) -> Void

    static let itemWidth: CGFloat = 32
    static let spacing: CGFloat = 2
    static var step: CGFloat { itemWidth + spacing }
    private static let coordinateSpace = "FeatureSwitcher"

    @State private var dragged: FeatureID?
    @State private var dragOffset: CGFloat = 0

    static func targetIndex(from: Int, offset: CGFloat, count: Int) -> Int {
        min(max(from + Int((offset / step).rounded()), 0), max(count - 1, 0))
    }

    /// How far an icon is shifted while another one is dragged over its place.
    static func shift(of index: Int, draggedFrom from: Int, to target: Int) -> CGFloat {
        if target > from, index > from, index <= target { return -step }
        if target < from, index >= target, index < from { return step }
        return 0
    }

    private var target: Int? {
        guard let dragged, let from = features.firstIndex(of: dragged) else { return nil }
        return Self.targetIndex(from: from, offset: dragOffset, count: features.count)
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(Array(features.enumerated()), id: \.element) { index, feature in
                icon(feature)
                    .offset(x: offset(of: index, feature: feature))
                    .zIndex(feature == dragged ? 1 : 0)
                    .onTapGesture { select(feature) }
                    .gesture(reorderGesture(for: feature))
                    .help("\(feature.title) (⌘-drag to reorder)")
            }
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
    }

    private func offset(of index: Int, feature: FeatureID) -> CGFloat {
        if feature == dragged { return dragOffset }
        guard let dragged, let from = features.firstIndex(of: dragged), let target else { return 0 }
        return Self.shift(of: index, draggedFrom: from, to: target)
    }

    private func icon(_ feature: FeatureID) -> some View {
        let isSelected = feature == selected
        let isDragged = feature == dragged
        return Image(systemName: feature.symbolName)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: Self.itemWidth, height: 22)
            .foregroundStyle(isSelected || isDragged ? Color.white : Color.white.opacity(0.7))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDragged ? Color.white.opacity(0.32) : (isSelected ? Color.white.opacity(0.22) : .clear))
            )
            .scaleEffect(isDragged ? 1.12 : 1)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: target)
    }

    private func reorderGesture(for feature: FeatureID) -> some Gesture {
        // Measured in the row's space: the dragged icon moving does not change the translation.
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.coordinateSpace))
            .onChanged { value in
                if dragged == nil {
                    // Only a drag started with Command held reorders.
                    guard NSEvent.modifierFlags.contains(.command) else { return }
                    dragged = feature
                }
                guard dragged == feature else { return }
                dragOffset = value.translation.width
            }
            .onEnded { _ in
                guard dragged == feature, let from = features.firstIndex(of: feature) else { return }
                let target = Self.targetIndex(from: from, offset: dragOffset, count: features.count)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragged = nil
                    dragOffset = 0
                    if target != from { move(feature, target) }
                }
            }
    }
}
