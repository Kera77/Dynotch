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

    /// Found as a running process without a hook event yet (spec CS-9).
    var pid: pid_t? { id.hasPrefix(Self.foundPrefix) ? pid_t(id.dropFirst(Self.foundPrefix.count)) : nil }
    static let foundPrefix = "pid:"
}

@MainActor
@Observable
final class ClaudeSessionService {
    private(set) var sessions: [ClaudeSession] = []
    /// A quiet session goes after this long (spec CS-3).
    static let forgetAfter: TimeInterval = 12 * 3600

    func handle(_ event: ClaudeSessionEvent) {
        forgetQuiet(now: event.date)
        // A new session drops the usage down with the sessions (spec CS-7), unless turned off (CS-8).
        // A session found running before is not new: its hook row takes its place (spec CS-9).
        let isKnown = sessions.contains { $0.id == event.sessionID }
        let found = isKnown ? nil : sessions.first { $0.pid != nil && $0.app == event.app && $0.project == Self.projectName(event.folder) }
        if let found { sessions.removeAll { $0.id == found.id } }
        if [.start, .prompt].contains(event.kind), !isKnown, found == nil, popupEnabled() {
            showPopup(at: event.date)
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
        // A removed running process stays away while it runs (spec CS-9).
        if let pid = sessions.first(where: { $0.id == id })?.pid { hiddenPIDs.insert(pid) }
        sessions.removeAll { $0.id == id }
    }

    // MARK: - Running on the Mac (spec CS-9)

    @ObservationIgnored private var hiddenPIDs: Set<pid_t> = []
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    static let scanInterval: Duration = .seconds(10)

    /// Looks for Claude Code processes every few seconds, in every app.
    func startScanning() {
        guard scanTask == nil else { return }
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                let found = await Task.detached(priority: .utility) { ClaudeProcessScan.running() }.value
                guard let self, !Task.isCancelled else { return }
                self.merge(found)
                try? await Task.sleep(for: Self.scanInterval)
            }
        }
    }

    /// Running processes without a hook row are listed as Ready with their app; a hook row with
    /// the same app and project stands for one of them; an ended process's row goes (spec CS-9).
    func merge(_ found: [ClaudeProcessScan.Found]) {
        let alive = Set(found.map(\.pid))
        hiddenPIDs.formIntersection(alive)
        var next = sessions.filter { session in session.pid.map(alive.contains) ?? true }
        var claimed: [String: Int] = [:]
        for session in next where session.pid == nil { claimed[Self.key(session.app, session.project), default: 0] += 1 }
        for process in found.sorted(by: { $0.started < $1.started }) where !hiddenPIDs.contains(process.pid) {
            let project = Self.projectName(process.folder)
            let id = ClaudeSession.foundPrefix + String(process.pid)
            let key = Self.key(process.app, project)
            if let count = claimed[key], count > 0 {
                claimed[key] = count - 1
                next.removeAll { $0.id == id }
            } else if !next.contains(where: { $0.id == id }) {
                next.append(ClaudeSession(
                    id: id, project: project, app: process.app, state: .ready,
                    since: process.started, lastEvent: process.started
                ))
            }
        }
        if next != sessions { sessions = next }
    }

    private static func key(_ app: String?, _ project: String) -> String { (app ?? "-") + "|" + project }

    func clearFinished() {
        sessions.removeAll { $0.state == .finished }
    }

    var hasFinished: Bool { sessions.contains { $0.state == .finished } }

    // MARK: - Under the usage ring (spec CS-6, CS-7)

    /// The usage and the sessions are down under the notch without hover (spec CS-7).
    private(set) var popupShown = false
    /// When it dropped down, or the last hover over it.
    private var popupActivity = Date.distantPast
    @ObservationIgnored private var popupTimer: Task<Void, Never>?
    /// The pop-up goes this long after it dropped down or the pointer left it (spec CS-7).
    static let popupTime: TimeInterval = 6
    /// Finished sessions stay listed this long (spec CS-6).
    static let finishedListTime: TimeInterval = 10 * 60
    /// Turned off in the settings (spec CS-8).
    var popupEnabled: () -> Bool = { ClaudeSessionSettings.shared.dropsDown }

    /// What the ring's hover lists: every session not finished, and the ones finished in the
    /// last ten minutes (spec CS-6).
    func running(now: Date = Date()) -> [ClaudeSession] {
        sessions.filter { $0.state != .finished || now.timeIntervalSince($0.since) < Self.finishedListTime }
    }

    /// The pointer is on the pop-up: it stays.
    func touchPopup(at date: Date = Date()) {
        guard popupShown else { return }
        popupActivity = max(popupActivity, date)
    }

    /// Its X or a flick up (spec CS-7).
    func closePopup() {
        popupShown = false
        popupTimer?.cancel()
        popupTimer = nil
    }

    /// Hides the pop-up a few seconds after it dropped down, or after the pointer left it (spec CS-7).
    func checkPopup(now: Date = Date()) {
        guard popupShown else { return }
        if now.timeIntervalSince(popupActivity) >= Self.popupTime { closePopup() }
    }

    private func showPopup(at date: Date) {
        popupShown = true
        popupActivity = max(popupActivity, date)
        guard popupTimer == nil else { return }
        popupTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
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
        sessions.removeAll { $0.pid == nil && now.timeIntervalSince($0.lastEvent) > Self.forgetAfter }
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
