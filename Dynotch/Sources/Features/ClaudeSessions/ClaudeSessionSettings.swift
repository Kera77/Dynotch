import Foundation
import Observation

/// Following Claude Code sessions at the AI usage ring, each part can be turned off (spec CS-8).
@MainActor
@Observable
final class ClaudeSessionSettings {
    static let shared = ClaudeSessionSettings()

    private enum Key {
        static let list = "claudeRingSessions"
        static let popup = "claudeSessionPopup"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// The running sessions under the ring's limits (spec CS-6).
    var listsSessions: Bool {
        didSet { defaults.set(listsSessions, forKey: Key.list) }
    }

    /// The ring drops down by itself for a new session (spec CS-7).
    var popsUp: Bool {
        didSet { defaults.set(popsUp, forKey: Key.popup) }
    }

    /// Without the list there is nothing to drop down.
    var dropsDown: Bool { listsSessions && popsUp }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        listsSessions = defaults.object(forKey: Key.list) as? Bool ?? true
        popsUp = defaults.object(forKey: Key.popup) as? Bool ?? true
    }
}
