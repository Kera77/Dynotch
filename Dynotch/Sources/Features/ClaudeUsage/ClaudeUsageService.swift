import AppKit
import Combine

/// Polls the Claude subscription usage with Claude Code's login (spec CL-1…CL-7).
@MainActor
final class ClaudeUsageService: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        /// No Claude Code login in the keychain (or access was refused).
        case noCredentials
        /// The token expired or was rejected; Claude Code renews it when it is used.
        case signedOut
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var limits: [UsageLimit] = []
    /// ChatGPT's limits, from Codex's logs (spec AI-6).
    @Published private(set) var gptLimits: [UsageLimit] = []
    @Published private(set) var lastUpdated: Date?
    /// "limit key|10 % step" of the fullest limit when its notch indicator was hidden (spec CL-6).
    @Published private var dismissedIndicator: String? {
        didSet { UserDefaults.standard.set(dismissedIndicator, forKey: Self.dismissedKey) }
    }

    private let settings: AppSettings
    private let notify: (String, String) -> Void
    private var timer: Timer?
    private var settingsObserver: AnyCancellable?
    private var isRefreshing = false
    /// Token read from Claude Code's keychain item, with its expiry.
    private var cachedToken: (token: String, expires: Date?)?

    private static let refreshInterval: TimeInterval = 5 * 60
    private static let minimumInterval: TimeInterval = 60
    private static let alertStateKey = "claudeUsageAlertState"
    private static let dismissedKey = "claudeIndicatorDismissed"
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")

    init(settings: AppSettings, notify: @escaping (String, String) -> Void) {
        self.settings = settings
        self.notify = notify
        dismissedIndicator = UserDefaults.standard.string(forKey: Self.dismissedKey)
    }

    /// The fullest limit.
    var peak: UsageLimit? {
        limits.max { $0.utilization < $1.utilization }
    }

    /// The session (5 hour) limit.
    var session: UsageLimit? {
        limits.first { $0.title.hasPrefix("Session") }
    }

    /// What the notch shows (spec CL-6): only the session limit, only from 70 %, and not while
    /// hidden with the X.
    var notchLimits: [UsageLimit]? {
        guard settings.isEnabled(.claudeUsage), settings.claudeRingVisible else { return nil }
        // Claude's session or ChatGPT's fullest limit, whichever is nearer its limit (spec AI-6).
        let candidates = [state == .loaded ? session : nil, gptLimits.max { $0.utilization < $1.utilization }].compactMap { $0 }
        guard let nearest = candidates.max(by: { $0.utilization < $1.utilization }) else { return nil }
        // Pinned with the button in the AI Usage view: always shown (spec CL-6b).
        if settings.claudeSessionPinned { return [nearest] }
        guard nearest.utilization >= UsageAlerts.threshold,
              !UsageAlerts.isDismissed(nearest, marker: dismissedIndicator)
        else { return nil }
        return [nearest]
    }

    var isSessionPinned: Bool { settings.claudeSessionPinned }

    /// Shows or hides the session beside the notch regardless of the 70 % threshold.
    func toggleSessionPinned() {
        settings.claudeSessionPinned.toggle()
    }

    /// Hides the notch indicator until the session reaches its next 10 % (or resets).
    func dismissIndicator() {
        settings.claudeSessionPinned = false
        guard let session else { return }
        dismissedIndicator = UsageAlerts.dismissMarker(for: session)
    }

    /// The limit shown by the menu bar ring: the session, otherwise the fullest one.
    var primary: UsageLimit? {
        limits.first { $0.title.hasPrefix("Session") } ?? limits.max { $0.utilization < $1.utilization }
    }

    var summary: String {
        limits.map { "\($0.title) \(Int($0.utilization.rounded()))%" }.joined(separator: " · ")
    }

    func start() {
        settingsObserver = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.applyEnabled() }
            }
        }
        applyEnabled()
    }

    private func applyEnabled() {
        let enabled = settings.isEnabled(.claudeUsage)
        if enabled, timer == nil {
            let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
            refresh()
        } else if !enabled, let timer {
            timer.invalidate()
            self.timer = nil
        }
    }

    /// Refreshes unless it did within the last minute (opening the view calls this).
    func refreshIfStale() {
        guard let lastUpdated, Date().timeIntervalSince(lastUpdated) < Self.minimumInterval else {
            refresh()
            return
        }
    }

    func refresh() {
        refreshChatGPT()
        guard !isRefreshing, let endpoint = Self.endpoint else { return }
        isRefreshing = true
        if limits.isEmpty { state = .loading }
        Task {
            defer { isRefreshing = false }
            switch await credential() {
            case .missing:
                state = .noCredentials
            case .expired:
                state = .signedOut
            case .token(let token, _):
                do {
                    let (data, status) = try await Self.fetch(endpoint, token: token)
                    try handle(data: data, status: status)
                } catch {
                    state = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// ChatGPT's limits from the newest Codex log (spec AI-6).
    func refreshChatGPT() {
        Task { [weak self] in
            let found = await Task.detached { CodexUsage.read() }.value
            if self?.gptLimits != found { self?.gptLimits = found }
        }
    }

    /// The cached token; read from the keychain only when there is none, or it expired or was refused.
    private func credential() async -> ClaudeCredential {
        if let cached = cachedToken, cached.expires.map({ $0 > Date() }) ?? true {
            return .token(cached.token, expires: cached.expires)
        }
        let credential = await Task.detached { ClaudeCredential.read() }.value
        if case .token(let token, let expires) = credential {
            cachedToken = (token, expires)
        }
        return credential
    }

    private func handle(data: Data, status: Int) throws {
        let shape = ClaudeUsageParser.labels(of: data) + "\n" + ClaudeUsageParser.structure(of: data)
        DiagnosticsLog.write("claude-usage", "HTTP \(status)\n" + shape)
        switch status {
        case 200:
            apply(try ClaudeUsageParser.limits(from: data))
        case 401, 403:
            // Claude Code may have renewed the token meanwhile: read it again next time.
            cachedToken = nil
            state = .signedOut
        default:
            state = .failed("HTTP \(status)")
        }
    }

    private func apply(_ limits: [UsageLimit]) {
        self.limits = limits
        lastUpdated = Date()
        state = .loaded

        let stored = (UserDefaults.standard.data(forKey: Self.alertStateKey))
            .flatMap { try? JSONDecoder().decode([String: UsageAlertState].self, from: $0) } ?? [:]
        let result = UsageAlerts.evaluate(limits, state: stored, now: Date())
        if let data = try? JSONEncoder().encode(result.state) {
            UserDefaults.standard.set(data, forKey: Self.alertStateKey)
        }
        guard settings.claudeUsageAlerts else { return }

        // The session started over (spec CL-5b).
        for limit in result.reset where limit.title.hasPrefix("Session") {
            notify("AI session reset", "\(limit.title) is at \(Int(limit.utilization.rounded()))% again.")
        }
        // Only when a new 10 % step is reached, never again for the same step (spec CL-5).
        for limit in result.due {
            let reset = limit.resetsAt.map { "Resets " + UsageAlerts.resetText($0, now: Date()) } ?? ""
            let message = limit.utilization >= 100 ? "Limit reached." : "You are close to the limit."
            notify("AI usage: \(limit.title) \(Int(limit.utilization.rounded()))%", "\(message) \(reset)")
        }
    }

    /// Puts the service into a loaded state without the keychain or the network (tests, previews).
    func setLoadedState(_ limits: [UsageLimit], updated: Date = Date()) {
        self.limits = limits
        lastUpdated = updated
        state = .loaded
    }

    nonisolated private static func fetch(_ url: URL, token: String) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Dynotch", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

}

/// Claude Code's login, read from the keychain item it stores (spec CL-1).
enum ClaudeCredential: Sendable {
    case token(String, expires: Date?)
    case expired
    case missing

    static let service = "Claude Code-credentials"

    /// Read with `/usr/bin/security`, the tool Claude Code itself stores the item with, so the
    /// item's access list allows it and macOS does not ask for the password. (Reading it through
    /// the keychain API asked again every time Claude Code renewed its token.)
    nonisolated static func read() -> ClaudeCredential {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return .missing
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return .missing }
        let trimmed = String(bytes: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return parse(Data(trimmed.utf8), now: Date())
    }

    nonisolated static func parse(_ data: Data, now: Date) -> ClaudeCredential {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return .missing }
        let expires = ((oauth["expiresAt"] as? NSNumber)?.doubleValue).map { Date(timeIntervalSince1970: $0 / 1000) }
        if let expires, expires <= now {
            return .expired
        }
        return .token(token, expires: expires)
    }
}
