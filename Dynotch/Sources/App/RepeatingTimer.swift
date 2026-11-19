import Foundation

/// The repeating timer every polling service uses: on the main run loop in common mode (so it
/// also fires while a menu is open or a scroll runs) with 20 % tolerance, so macOS can group
/// wake-ups.
enum RepeatingTimer {
    @MainActor
    static func start(
        every interval: TimeInterval, tolerance: Double = 0.2, _ action: @escaping @MainActor @Sendable () -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { action() }
        }
        timer.tolerance = interval * tolerance
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
