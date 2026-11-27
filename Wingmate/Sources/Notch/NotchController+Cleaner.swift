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

/// The clean beside the closed notch in the rings' style (spec TT-13, TT-27): while it cleans a
/// blue arc runs round the grey ring with sparkles in the middle; when done the ring fills green
/// with a tick in it.
struct CleanerGlanceView: View {
    let glance: CleanerService.NotchGlance

    @State private var turning = false
    private static let lineWidth: CGFloat = 3

    var body: some View {
        let done = glance == .done
        ZStack {
            Circle().stroke(Color.white.level(0.22), lineWidth: Self.lineWidth)
            Circle()
                .trim(from: 0, to: done ? 1 : 0.3)
                .stroke(done ? Theme.green : Theme.blue, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(done ? -90 : turning ? 270 : -90))
                .animation(done ? Motion.quick : .linear(duration: 1).repeatForever(autoreverses: false), value: turning)
            Image(systemName: done ? "checkmark" : "sparkles")
                .font(.notch(size: done ? 10 : 9.5, weight: .bold))
                .foregroundStyle(done ? Theme.green : Color.white.level(0.85))
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(Self.lineWidth / 2)
        .frame(width: LevelRing.size, height: LevelRing.size)
        .frame(width: IndicatorLayout.ringSlotWidth, height: LevelRing.size)
        .animation(Motion.quick, value: done)
        .onAppear { turning = !done }
        .onChange(of: done) { _, isDone in turning = !isDone }
        .help(done ? "Cleaned: hover to see what was freed" : "Cleaning…")
    }
}
