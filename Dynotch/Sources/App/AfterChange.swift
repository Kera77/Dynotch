import Combine
import Foundation

extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// Runs `action` on the main thread once the object has changed (`objectWillChange` fires
    /// before the new value is stored). Several changes in one run-loop turn run it once.
    func afterChange(_ action: @escaping @MainActor @Sendable () -> Void) -> AnyCancellable {
        objectWillChange
            .debounce(for: .zero, scheduler: DispatchQueue.main)
            .sink { _ in MainActor.assumeIsolated { action() } }
    }
}
