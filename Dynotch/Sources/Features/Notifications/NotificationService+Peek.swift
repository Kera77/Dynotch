import Foundation

// MARK: - Holding the peek beside the notch (spec PV-39)

extension NotificationService {
    /// The pointer came onto or left the notification beside one display's notch. Leaving, the
    /// newest that came meanwhile shows; otherwise the shown one goes after its usual time.
    func holdPeek(_ held: Bool, by holder: ObjectIdentifier) {
        guard held != peekHolders.contains(holder) else { return }
        if held {
            peekHolders.insert(holder)
            return
        }
        peekHolders.remove(holder)
        guard peekHolders.isEmpty, let newer = heldPeek else { return }
        showPeek(newer)
    }
}
