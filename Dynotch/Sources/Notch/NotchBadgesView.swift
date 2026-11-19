import SwiftUI

/// The chosen apps' unread counts left of the closed notch (spec B-4…B-7): an icon with a
/// number each. A click opens the app, dragging reorders them.
struct NotchBadgesView: View {
    let badges: [BadgeItem]
    let hoveredID: String?
    let now: Date
    let open: (BadgeItem) -> Void
    /// Right click: the app's unopened notifications (spec B-6).
    var showNotifications: (BadgeItem) -> Void = { _ in }
    /// A badge was dropped at a new place among the visible ones.
    let move: (String, Int) -> Void

    private static let coordinateSpace = "NotchBadges"

    @State private var dragged: String?
    @State private var dragOffset: CGFloat = 0

    private var widths: [CGFloat] { badges.map(\.width) }

    private var draggedIndex: Int? {
        dragged.flatMap { id in badges.firstIndex { $0.id == id } }
    }

    private var target: Int? {
        draggedIndex.map {
            BadgeReorder.targetIndex(widths: widths, from: $0, offset: dragOffset, spacing: IndicatorLayout.badgeSpacing)
        }
    }

    var body: some View {
        HStack(spacing: IndicatorLayout.badgeSpacing) {
            ForEach(Array(badges.enumerated()), id: \.element.id) { index, badge in
                BadgeChip(badge: badge, isHighlighted: badge.id == hoveredID || badge.id == dragged, now: now)
                    .frame(width: badge.width, height: IndicatorLayout.iconHeight)
                    .contentShape(Rectangle())
                    .offset(x: offset(of: index, badge: badge))
                    .zIndex(badge.id == dragged ? 1 : 0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.85), value: target)
                    .onTapGesture { open(badge) }
                    .gesture(reorderGesture(for: badge))
                    .overlay(RightClickCatcher { showNotifications(badge) })
                    .help("\(badge.app.name): \(badge.label) — click opens the app, right click its notifications, drag reorders")
            }
        }
        .coordinateSpace(name: Self.coordinateSpace)
    }

    private func offset(of index: Int, badge: BadgeItem) -> CGFloat {
        if badge.id == dragged { return dragOffset }
        guard let from = draggedIndex, let target else { return 0 }
        return BadgeReorder.shift(
            of: index, from: from, target: target, draggedWidth: widths[from], spacing: IndicatorLayout.badgeSpacing
        )
    }

    private func reorderGesture(for badge: BadgeItem) -> some Gesture {
        // Measured in the row's space: the dragged badge moving does not change the translation.
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.coordinateSpace))
            .onChanged { value in
                if dragged == nil { dragged = badge.id }
                guard dragged == badge.id else { return }
                dragOffset = value.translation.width
            }
            .onEnded { _ in
                guard dragged == badge.id else { return }
                let destination = target
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragged = nil
                    dragOffset = 0
                    if let destination, destination != badges.firstIndex(where: { $0.id == badge.id }) {
                        move(badge.id, destination)
                    }
                }
            }
    }
}

/// One app: icon and number. It pulses gently for five minutes after a new notification.
private struct BadgeChip: View {
    let badge: BadgeItem
    let isHighlighted: Bool
    let now: Date

    private static let period: TimeInterval = 1.8
    @State private var dimmed = false

    /// The pulse is a repeating animation the system runs on its own, not a redraw 20 times a
    /// second for five minutes.
    var body: some View {
        if BadgeTracker.isPulsing(since: badge.pulseStart, now: now) {
            content
                .opacity(dimmed ? 0.62 : 1)
                .scaleEffect(dimmed ? 0.96 : 1.04)
                .animation(.easeInOut(duration: Self.period / 2).repeatForever(autoreverses: true), value: dimmed)
                .onAppear { dimmed = true }
                .onDisappear { dimmed = false }
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: BadgeItem.gap) {
            BadgeIconView(icon: badge.app.icon, bundleID: badge.app.bundleID)
            Text(badge.text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
        }
        .brightness(isHighlighted ? 0.12 : 0)
        .scaleEffect(isHighlighted ? 1.08 : 1)
    }
}

/// Takes right clicks only; everything else goes to the views below.
private struct RightClickCatcher: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.action = action
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.action = action
    }

    final class CatcherView: NSView {
        var action: () -> Void = {}

        override func hitTest(_ point: NSPoint) -> NSView? {
            let type = NSApp.currentEvent?.type
            return type == .rightMouseDown || type == .rightMouseUp ? super.hitTest(point) : nil
        }

        override func rightMouseDown(with event: NSEvent) {
            action()
        }
    }
}
