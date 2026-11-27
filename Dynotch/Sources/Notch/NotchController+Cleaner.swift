import AppKit
import SwiftUI

/// The Cleaner on the Stats: the pinch back, the swipe out of an app, and the tick beside the
/// closed notch (spec TT-8, TT-13, TT-14).
extension NotchController {
    /// A pinch over the Cleaner goes back to the Stats; from there the next one does its usual job (spec TT-8).
    func handleCleanerPinch(_ event: NSEvent) -> Bool {
        guard model.isExpanded, model.showsCleaner, model.currentFeature == .stats,
              model.geometry.rect(for: model.openSize).contains(NSEvent.mouseLocation)
        else { return false }
        if tileBack.pinch(phase: Self.phase(of: event), magnification: event.magnification) == .inward {
            withAnimation(Motion.spring) { model.closeCleaner() }
            DiagnosticsLog.append("cleaner", "back to Stats: pinch")
            Haptics.perform(.featureSwitch, settings: settings)
        }
        return true
    }

    /// In an app of the Apps tab a sideways swipe goes back to the list, not to another module (spec TT-14).
    func swipesOutOfCleanerApp() -> Bool {
        let cleaner = CleanerService.shared
        guard model.showsCleaner, model.currentFeature == .stats, cleaner.tab == .apps, cleaner.app != nil,
              !cleaner.isCleaning
        else { return false }
        withAnimation(Motion.quick) { cleaner.pick(nil) }
        Haptics.perform(.featureSwitch, settings: settings)
        return true
    }

    /// The spinner or the tick beside the closed notch, hovered: the Cleaner opens again (spec TT-13).
    func openCleanerFromIndicator() {
        noteEdgeOrigin()
        setHoveredIndicator(nil)
        setHoveredBadge(nil)
        expand(fromEdge: true)
        withAnimation(Self.animation) { model.openCleaner() }
        CleanerService.shared.clearNotchGlance()
    }
}

/// The clean beside the closed notch: the same spinner as in the Cleaner, then a green tick (spec TT-13).
struct CleanerGlanceView: View {
    let glance: CleanerService.NotchGlance

    var body: some View {
        Group {
            switch glance {
            case .cleaning:
                ProgressView().controlSize(.small).scaleEffect(0.8)
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.notch(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: IndicatorLayout.ringSlotWidth, height: LevelRing.size)
        .help(glance == .cleaning ? "Cleaning…" : "Cleaned: hover to see what was freed")
    }
}
