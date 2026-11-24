import Foundation
import Observation
import SwiftUI

/// Kept by the owner like an `AnyCancellable`: once cancelled or released, the observation stops.
@MainActor
final class ChangeObservation {
    private(set) var isCancelled = false

    func cancel() { isCancelled = true }
}

/// Runs `onChange` on the main thread once something `reads` looked at has changed (Observation
/// reports before the new value is stored, so it waits for the next run loop turn). Several changes
/// in one turn run it once. It registers again after each change, reading anew what `reads` reads.
/// `willChange` runs at once, before the first change of a turn is stored.
@MainActor
func observeChanges(
    of reads: @escaping @MainActor @Sendable () -> Void,
    willChange: (@MainActor @Sendable () -> Void)? = nil,
    onChange: @escaping @MainActor @Sendable () -> Void
) -> ChangeObservation {
    let token = ChangeObservation()
    ObservationLoop(reads: reads, willChange: willChange, onChange: onChange, token: WeakToken(value: token)).arm()
    return token
}

private struct WeakToken: Sendable {
    weak var value: ChangeObservation?
}

private struct ObservationLoop: Sendable {
    let reads: @MainActor @Sendable () -> Void
    let willChange: (@MainActor @Sendable () -> Void)?
    let onChange: @MainActor @Sendable () -> Void
    let token: WeakToken

    @MainActor
    func arm() {
        guard let observation = token.value, !observation.isCancelled else { return }
        withObservationTracking {
            reads()
        } onChange: {
            if let willChange, Thread.isMainThread {
                MainActor.assumeIsolated { willChange() }
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let observation = token.value, !observation.isCancelled else { return }
                    onChange()
                    arm()
                }
            }
        }
    }
}

/// Runs `body` with `animation`; `completion` runs once SwiftUI reports the animation logically
/// complete (spec RF-14). If nothing on screen changed, SwiftUI may never report it, so it runs
/// after `latest` seconds at the latest. Either way it runs once.
@MainActor
func animate(
    _ animation: Animation,
    atMost latest: TimeInterval,
    _ body: () -> Void,
    completion: @escaping @MainActor @Sendable () -> Void
) {
    let once = RunOnce(completion)
    withAnimation(animation, completionCriteria: .logicallyComplete, body) { once.run() }
    DispatchQueue.main.asyncAfter(deadline: .now() + latest) {
        MainActor.assumeIsolated { once.run() }
    }
}

@MainActor
private final class RunOnce {
    private var action: (@MainActor @Sendable () -> Void)?

    init(_ action: @escaping @MainActor @Sendable () -> Void) { self.action = action }

    func run() {
        let pending = action
        action = nil
        pending?()
    }
}
