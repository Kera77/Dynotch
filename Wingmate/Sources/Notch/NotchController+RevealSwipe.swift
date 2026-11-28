import AppKit
import SwiftUI

// MARK: - Drop-downs with a swipe down (spec DS-1…DS-3)

extension NotchController {
    /// With swipe drop-downs on, a swipe down over the hovered item opens its drop-down (or its
    /// module), a swipe up over the row closes it again.
    /// - Returns: true when the event was used.
    func handleRevealSwipe(_ event: NSEvent) -> Bool {
        guard GestureSettings.shared.dropdownsOnSwipe, !model.isExpanded,
              model.hoveredIndicator != nil || model.hoveredBadge != nil
        else { return false }
        let began: Bool? = event.phase.isEmpty && event.momentumPhase.isEmpty ? nil : event.phase.contains(.began)
        // Positive = fingers moved down, regardless of "natural scrolling".
        let fingerDown = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        guard let direction = model.reveal.swipe.handle(
            fingerDown: fingerDown, across: event.scrollingDeltaX, began: began,
            isMomentum: !event.momentumPhase.isEmpty, time: event.timestamp
        ) else { return false }
        switch direction {
        case .open:
            guard !model.dropdownRevealed else { return false }
            revealHoveredDropdown()
            return true
        case .close:
            // Only over the row itself: a long list under it scrolls instead (spec DS-3).
            let notch = model.geometry.notchRect
            guard model.dropdownRevealed, NSEvent.mouseLocation.y >= notch.minY - NotchGeometry.topEdgeTolerance else { return false }
            withAnimation(Self.animation) { model.dropdownRevealed = false }
            return true
        }
    }

    private func revealHoveredDropdown() {
        let items = collapsedRow().items
        if let index = model.hoveredIndicator, items.indices.contains(index) {
            let item = items[index]
            if item.opensModuleOnHover(statsWarnings: !stats.indicator.warnings.isEmpty) {
                // The stats and the Cleaner open their module (spec DS-2).
                if case .cleaner = item { return openCleanerFromIndicator() }
                return openFromIndicator(.stats)
            }
        }
        Haptics.perform(.dayStep, settings: settings)
        withAnimation(Self.animation) { model.dropdownRevealed = true }
    }
}
