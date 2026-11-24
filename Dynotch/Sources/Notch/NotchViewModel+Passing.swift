import AppKit
import SwiftUI

/// The modules a swipe passes over: their last look stands in for them (spec M-20).
@MainActor
final class PagePassing {
    /// The last look of each module, kept when it was left.
    var snapshots: [FeatureID: NSImage] = [:]
    /// Takes a picture of the current page; set by the controller.
    var capture: () -> NSImage? = { nil }
    var settle: Task<Void, Never>?
    /// How long the swipe rests before the module it stopped on is built.
    static let settleDelay: Duration = .milliseconds(200)
}

extension NotchViewModel {
    /// Keeps the current module's look before it is left; a pick by click or shortcut builds the
    /// new module at once (spec M-20).
    func leavePage(passing isPassing: Bool = false) {
        if liveCenter == nil, isExpanded, !isShowingSettings, let image = passing.capture() {
            passing.snapshots[currentFeature] = image
        }
        if !isPassing, liveCenter != nil {
            passing.settle?.cancel()
            liveCenter = nil
        }
    }

    /// A swipe step over the icons: the modules it passes are not built, only the one it stops on (spec M-20).
    func pass(by steps: Int) {
        if liveCenter == nil {
            leavePage(passing: true)
            liveCenter = currentFeature
        }
        step(by: steps, passing: true)
        passing.settle?.cancel()
        passing.settle = Task { [weak self] in
            try? await Task.sleep(for: PagePassing.settleDelay)
            guard !Task.isCancelled, let self, self.liveCenter != nil else { return }
            withAnimation(Motion.quick) { self.liveCenter = nil }
        }
    }
}

/// A module a swipe passes over: its snapshot, or its icon and name until it has one (spec M-20).
struct PassingPage: View {
    let feature: FeatureID
    let snapshot: NSImage?

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                Image(systemName: feature.symbolName).font(.system(size: 26, weight: .medium))
                Text(feature.title).font(.notch(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.45))
            if let snapshot {
                Image(nsImage: snapshot).resizable().interpolation(.medium)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
