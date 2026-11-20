// The newest note, for the Wings (spec PV-19, PV-60, PV-63).
import Foundation

extension NotesStore {
    /// Looks up the note changed last, at most every 20 seconds.
    func refreshLatest(now: Date = Date()) {
        // Also before the Notes panel was opened: only a refusal stops it (spec PV-34).
        guard access != .denied, latestLoaded.map({ now.timeIntervalSince($0) > 20 }) ?? true else { return }
        latestLoaded = now
        Task {
            do {
                if let found = try await bridge.latest(), found != latest { latest = found }
            } catch { latestLoaded = Date().addingTimeInterval(-17) } // Failed: again soon (spec PV-60).
        }
    }

    /// While the Wings show Notes and the latest note is missing: every second, for 10 seconds
    /// at most, one fetch at a time (spec PV-63). Ends early when the view goes away.
    func retryLatestWhileMissing(attempts: Int = 10) async {
        for _ in 0..<attempts {
            guard latest == nil, access != .denied, !Task.isCancelled else { return }
            if !isFetchingLatest {
                isFetchingLatest = true
                if let found = try? await bridge.latest(), found != latest { latest = found }
                isFetchingLatest = false
                latestLoaded = Date()
                if latest != nil { return }
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
