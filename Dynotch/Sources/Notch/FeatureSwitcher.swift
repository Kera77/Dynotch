import SwiftUI

/// Capsule-shaped icon switcher in the panel's top row (spec M-1). Holding Command while
/// dragging an icon reorders the features (spec M-6). During the drag the views keep their
/// order and only move by offsets, so the gesture is never interrupted; the order changes when
/// the icon is dropped.
struct FeatureSwitcher: View {
    let features: [FeatureID]
    let selected: FeatureID?
    /// Index of the first feature shown; only `visibleCount` fit beside the notch (spec M-9).
    var first = 0
    var visibleCount = Int.max
    let select: (FeatureID) -> Void
    let move: (FeatureID, Int) -> Void

    static let itemWidth: CGFloat = 32
    static let spacing: CGFloat = 2
    static var step: CGFloat { itemWidth + spacing }
    private static let coordinateSpace = "FeatureSwitcher"

    @State private var dragged: FeatureID?
    @State private var dragOffset: CGFloat = 0

    /// How many icons fit in `width`, the room left of the notch.
    static func visibleCount(for width: CGFloat) -> Int {
        max(1, Int((width - 6 + spacing) / step))
    }

    /// The first index shown: `first`, kept so that the window stays full.
    static func clampedFirst(_ first: Int, count: Int, visible: Int) -> Int {
        min(max(first, 0), max(count - visible, 0))
    }

    private var window: Range<Int> {
        let start = Self.clampedFirst(first, count: features.count, visible: visibleCount)
        return start..<min(start + visibleCount, features.count)
    }

    /// The features shown, with their index in `features`.
    private var shown: [(index: Int, feature: FeatureID)] {
        window.map { ($0, features[$0]) }
    }

    static func targetIndex(from: Int, offset: CGFloat, count: Int) -> Int {
        min(max(from + Int((offset / step).rounded()), 0), max(count - 1, 0))
    }

    /// How far an icon is shifted while another one is dragged over its place.
    static func shift(of index: Int, draggedFrom from: Int, to target: Int) -> CGFloat {
        if target > from, index > from, index <= target { return -step }
        if target < from, index >= target, index < from { return step }
        return 0
    }

    /// Dragging works within the icons shown; positions are counted from the first shown.
    private var target: Int? {
        guard let dragged, let from = shown.firstIndex(where: { $0.feature == dragged }) else { return nil }
        return Self.targetIndex(from: from, offset: dragOffset, count: shown.count)
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(shown, id: \.feature) { index, feature in
                icon(feature)
                    .offset(x: offset(of: index - window.lowerBound, feature: feature))
                    .zIndex(feature == dragged ? 1 : 0)
                    .onTapGesture { select(feature) }
                    .gesture(reorderGesture(for: feature))
                    .help("\(feature.title) (⌘-drag to reorder)")
            }
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color.white.level(0.1)))
    }

    private func offset(of index: Int, feature: FeatureID) -> CGFloat {
        if feature == dragged { return dragOffset }
        guard let dragged, let from = shown.firstIndex(where: { $0.feature == dragged }), let target else { return 0 }
        return Self.shift(of: index, draggedFrom: from, to: target)
    }

    private func icon(_ feature: FeatureID) -> some View {
        let isSelected = feature == selected
        let isDragged = feature == dragged
        let color = isSelected || isDragged ? Color.white : Color.white.level(0.7)
        return Image(systemName: feature.symbolName)
            .font(.notch(size: 12, weight: .semibold))
            .frame(width: Self.itemWidth, height: 22)
            .foregroundStyle(color)
            .background(
                Capsule(style: .continuous)
                    .fill(isDragged ? Color.white.level(0.32) : (isSelected ? Color.white.level(0.22) : .clear))
            )
            .scaleEffect(isDragged ? 1.12 : 1)
            .contentShape(Rectangle())
            .animation(Motion.quick, value: target)
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
                guard dragged == feature, let from = shown.firstIndex(where: { $0.feature == feature }) else { return }
                let target = Self.targetIndex(from: from, offset: dragOffset, count: shown.count)
                let start = window.lowerBound
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragged = nil
                    dragOffset = 0
                    if target != from { move(feature, start + target) }
                }
            }
    }
}
