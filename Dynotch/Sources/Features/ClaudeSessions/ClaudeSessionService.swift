import Foundation
import Observation

/// One step of a Claude Code session, from the session hook's input (spec CS-3).
struct ClaudeSessionEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case start, prompt, stop, end
    }

    let kind: Kind
    let sessionID: String
    let folder: String
    let transcript: String?
    /// The prompt's first line; shown, never logged.
    let prompt: String?
    let app: String?
    let date: Date

    init?(input: [String: Any], app: String?, date: Date) {
        let kinds: [String: Kind] = ["SessionStart": .start, "UserPromptSubmit": .prompt, "Stop": .stop, "SessionEnd": .end]
        guard let name = input["hook_event_name"] as? String, let kind = kinds[name],
              let id = input["session_id"] as? String, !id.isEmpty
        else { return nil }
        self.kind = kind
        sessionID = id
        folder = input["cwd"] as? String ?? ""
        transcript = input["transcript_path"] as? String
        prompt = (input["prompt"] as? String).map { ClaudeQuestionHook.oneLine($0, limit: 120) }
        self.app = app
        self.date = date
    }
}

/// A Claude Code session in the Sessions tab (spec CS-1).
struct ClaudeSession: Equatable, Identifiable, Sendable {
    enum State: Equatable, Sendable {
        case ready, working, asks, needsYou, background, finished

        var title: String {
            switch self {
            case .ready: "Ready"
            case .working: "Working"
            case .asks: "Asks"
            case .needsYou: "Needs you"
            case .background: "Background task"
            case .finished: "Finished"
            }
        }
    }

    let id: String
    var project: String
    var app: String?
    var state: State
    /// Since when it is in this state.
    var since: Date
    var lastEvent: Date
    var prompt: String?
}

@MainActor
@Observable
final class ClaudeSessionService {
    private(set) var sessions: [ClaudeSession] = []
    /// A quiet session goes after this long (spec CS-3).
    static let forgetAfter: TimeInterval = 12 * 3600

    func handle(_ event: ClaudeSessionEvent) {
        forgetQuiet(now: event.date)
        popupActivity = event.date
        // A new session drops the usage down with the sessions (spec CS-7).
        if [.start, .prompt].contains(event.kind), !sessions.contains(where: { $0.id == event.sessionID }) {
            showPopup()
        }
        guard event.kind != .end else {
            sessions.removeAll { $0.id == event.sessionID }
            return
        }
        var session = sessions.first { $0.id == event.sessionID } ?? ClaudeSession(
            id: event.sessionID, project: Self.projectName(event.folder), app: event.app,
            state: .ready, since: event.date, lastEvent: event.date
        )
        session.app = event.app ?? session.app
        session.lastEvent = event.date
        switch event.kind {
        case .start:
            break
        case .prompt:
            session.prompt = event.prompt ?? session.prompt
            set(&session, .working, at: event.date)
        case .stop:
            set(&session, .finished, at: event.date)
            if let transcript = event.transcript { refineStop(of: session.id, transcript: transcript) }
        case .end:
            return
        }
        put(session)
    }

    /// A question or permission waits (spec CQ-1); an unknown session is not added.
    func asks(session id: String?, needsYou: Bool, at date: Date) {
        update(id) { session in
            self.set(&session, needsYou ? .needsYou : .asks, at: date)
        }
    }

    /// The question was answered: back to work.
    func answered(session id: String?, at date: Date) {
        update(id) { session in
            guard [.asks, .needsYou].contains(session.state) else { return }
            self.set(&session, .working, at: date)
        }
    }

    func remove(_ id: String) {
        sessions.removeAll { $0.id == id }
    }

    func clearFinished() {
        sessions.removeAll { $0.state == .finished }
    }

    var hasFinished: Bool { sessions.contains { $0.state == .finished } }

    // MARK: - Under the usage ring (spec CS-6, CS-7)

    /// The usage and the sessions are down under the notch without hover (spec CS-7).
    private(set) var popupShown = false
    /// The last session event or hover over the pop-up.
    private var popupActivity = Date.distantPast
    @ObservationIgnored private var popupTimer: Task<Void, Never>?
    /// Once no session runs, the pop-up goes after this long without activity (spec CS-7).
    static let popupQuietTime: TimeInterval = 10 * 60

    /// What the ring's hover lists: every session not finished, and the ones finished in the
    /// last ten minutes (spec CS-6).
    func running(now: Date = Date()) -> [ClaudeSession] {
        sessions.filter { $0.state != .finished || now.timeIntervalSince($0.since) < Self.popupQuietTime }
    }

    /// The pointer is on the pop-up: the ten minutes start again.
    func touchPopup(at date: Date = Date()) {
        guard popupShown else { return }
        popupActivity = max(popupActivity, date)
    }

    /// Its X (spec CS-7).
    func closePopup() {
        popupShown = false
        popupTimer?.cancel()
        popupTimer = nil
    }

    /// Hides the pop-up once no session works, asks or runs in the background and nothing
    /// happened for ten minutes (spec CS-7).
    func checkPopup(now: Date = Date()) {
        guard popupShown else { return }
        let busy = sessions.contains { [.working, .asks, .needsYou, .background].contains($0.state) }
        if !busy, now.timeIntervalSince(popupActivity) >= Self.popupQuietTime { closePopup() }
    }

    private func showPopup() {
        popupShown = true
        guard popupTimer == nil else { return }
        popupTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                self.checkPopup()
            }
        }
    }

    // MARK: - Private

    private func update(_ id: String?, _ change: (inout ClaudeSession) -> Void) {
        guard let id, var session = sessions.first(where: { $0.id == id }) else { return }
        change(&session)
        session.lastEvent = max(session.lastEvent, session.since)
        put(session)
    }

    private func set(_ session: inout ClaudeSession, _ state: ClaudeSession.State, at date: Date) {
        guard session.state != state else { return }
        session.state = state
        session.since = date
    }

    /// Newest activity on top.
    private func put(_ session: ClaudeSession) {
        sessions.removeAll { $0.id == session.id }
        sessions.insert(session, at: 0)
    }

    private func forgetQuiet(now: Date) {
        sessions.removeAll { now.timeIntervalSince($0.lastEvent) > Self.forgetAfter }
    }

    /// The transcript tells whether background work still runs and where it really worked (CN-3, CN-4).
    private func refineStop(of id: String, transcript: String) {
        Task { [weak self] in
            let summary = await Task.detached { ClaudeTranscript.summary(ofFileAt: transcript) }.value
            self?.update(id) { session in
                guard session.state == .finished else { return }
                if let project = summary.project { session.project = project }
                if !summary.pending.isEmpty { session.state = .background }
            }
        }
    }

    nonisolated static func projectName(_ folder: String) -> String {
        let name = (folder as NSString).lastPathComponent
        return name.isEmpty ? "Claude Code" : String(name.prefix(60))
    }
}

/// The Wings' words for the Sessions tab.
enum ClaudeSessionsWing {
    static func left(_ sessions: [ClaudeSession]) -> String {
        sessions.first.map { "\($0.project) · \($0.state.title)" } ?? "Claude Code"
    }

    static func right(_ sessions: [ClaudeSession]) -> String {
        let working = sessions.filter { $0.state == .working }.count
        let waiting = sessions.filter { [.asks, .needsYou].contains($0.state) }.count
        if sessions.isEmpty { return "No sessions" }
        return [working > 0 ? "\(working) working" : nil, waiting > 0 ? "\(waiting) waiting" : nil]
            .compactMap { $0 }.joined(separator: " · ").nonEmpty ?? "\(sessions.count) session\(sessions.count == 1 ? "" : "s")"
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
