import AppKit
import Observation

/// Polls the Claude subscription usage with Claude Code's login and the accounts added in
/// Settings (spec CL-1…CL-15).
@MainActor
@Observable
final class ClaudeUsageService {
    enum State: Equatable, Sendable {
        case idle
        case loading
        case loaded
        /// No Claude Code login in the keychain (or access was refused).
        case noCredentials
        /// The token expired or was rejected; Claude Code renews it when it is used.
        case signedOut
        case failed(String)
    }

    /// Claude Code's login first, then the accounts added in Settings (spec CL-8).
    var accounts: [ClaudeAccount] = [.claudeCode]
    var usage: [String: AccountUsage] = [:]
    /// The account whose session grew last (spec CL-10).
    var activeID = ClaudeAccount.claudeCodeID
    /// The account picked by hand; nil is Auto (spec CL-11).
    var selection: String? {
        didSet { settings.defaults.set(selection, forKey: Self.selectionKey) }
    }
    /// A sign-in in progress or its error, for Settings.
    var signInMessage: String?
    var isSigningIn = false

    /// ChatGPT's limits, from Codex's logs (spec AI-6).
    private(set) var gptLimits: [UsageLimit] = []
    private(set) var gptUpdated: Date?
    /// "limit key|10 % step" of the fullest limit when its notch indicator was hidden (spec CL-6).
    private var dismissedIndicator: String? {
        didSet { settings.defaults.set(dismissedIndicator, forKey: Self.dismissedKey) }
    }

    let settings: AppSettings
    let notify: (String, String) -> Void
    @ObservationIgnored private var timer: Poller?
    @ObservationIgnored private var settingsObserver: ChangeObservation?
    @ObservationIgnored private var isRefreshing = false
    /// Token read from Claude Code's keychain item, with its expiry.
    @ObservationIgnored private var cachedToken: (token: String, expires: Date?)?
    /// Tokens of the added accounts, read from Wingmate's keychain item once.
    @ObservationIgnored var storedTokens: [String: StoredClaudeToken] = [:]

    private static let refreshInterval: TimeInterval = 5 * 60
    private static let minimumInterval: TimeInterval = 60
    /// A session that grew within this time counts as being used (spec CL-12).
    private static let consumingWindow: TimeInterval = 12 * 60
    static let alertStateKey = "claudeUsageAlertState"
    private static let dismissedKey = "claudeIndicatorDismissed"
    static let accountsKey = "claudeUsageAccounts"
    private static let selectionKey = "claudeUsageAccount"
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")

    init(settings: AppSettings, notify: @escaping (String, String) -> Void) {
        self.settings = settings
        self.notify = notify
        dismissedIndicator = settings.defaults.string(forKey: Self.dismissedKey)
        let saved = settings.defaults.data(forKey: Self.accountsKey)
            .flatMap { try? JSONDecoder().decode([ClaudeAccount].self, from: $0) } ?? []
        let claudeCode = saved.first(where: \.isClaudeCode) ?? .claudeCode
        accounts = [claudeCode] + saved.filter { !$0.isClaudeCode }
        selection = settings.defaults.string(forKey: Self.selectionKey).flatMap { id in
            accounts.contains { $0.id == id } ? id : nil
        }
    }

    // MARK: - The shown account

    var hasSeveralAccounts: Bool { accounts.count > 1 }

    /// The picked account, otherwise the one in use (spec CL-10, CL-11).
    var shownID: String { selection ?? activeID }

    var shownAccount: ClaudeAccount { accounts.first { $0.id == shownID } ?? accounts[0] }

    private var shown: AccountUsage { usage[shownID] ?? AccountUsage() }

    var state: State { shown.state }
    var limits: [UsageLimit] { shown.limits }
    var lastUpdated: Date? { shown.lastUpdated }

    /// Its session grew within the last refreshes (spec CL-12).
    func isConsuming(_ id: String, now: Date = Date()) -> Bool {
        usage[id]?.lastGrowth.map { now.timeIntervalSince($0) < Self.consumingWindow } ?? false
    }

    func select(_ id: String?) {
        selection = id.flatMap { id in accounts.contains { $0.id == id } ? id : nil }
    }

    /// The fullest limit.
    var peak: UsageLimit? {
        limits.max { $0.utilization < $1.utilization }
    }

    /// The session (5 hour) limit.
    var session: UsageLimit? { shown.session }

    /// Every account's session, named when there are several (spec CL-13).
    private var sessions: [UsageLimit] {
        accounts.compactMap { account in
            guard let entry = usage[account.id], entry.state == .loaded, var session = entry.session else { return nil }
            if hasSeveralAccounts {
                session = UsageLimit(
                    id: account.id + "|" + session.id, title: session.title, utilization: session.utilization,
                    resetsAt: session.resetsAt, account: account.name
                )
            }
            return session
        }
    }

    /// Claude's sessions or ChatGPT's fullest limit, whichever is nearest its limit (spec AI-6, CL-13).
    private var nearest: UsageLimit? {
        (sessions + [gptLimits.max { $0.utilization < $1.utilization }].compactMap { $0 })
            .max { $0.utilization < $1.utilization }
    }

    /// What the notch shows (spec CL-6): only sessions, only from 70 %, and not while hidden with
    /// the X. With several accounts the hover lists every running session by name (spec CL-13).
    var notchLimits: [UsageLimit]? {
        guard settings.isEnabled(.claudeUsage), settings.claudeRingVisible, let nearest else { return nil }
        // Pinned with the button in the AI Usage view: always shown (spec CL-6b).
        if !settings.claudeSessionPinned {
            guard nearest.utilization >= UsageAlerts.threshold,
                  !UsageAlerts.isDismissed(nearest, marker: dismissedIndicator)
            else { return nil }
        }
        guard hasSeveralAccounts else { return [nearest] }
        let others = sessions.filter { $0.id != nearest.id && $0.utilization > 0 }
            .sorted { $0.utilization > $1.utilization }
        return [nearest] + others
    }

    /// While Claude Code sessions dropped the usage down (spec CS-7) the ring shows below 70 %
    /// and after its X too; without usage data it shows empty, for the sessions.
    func notchLimits(sessionsPopup: Bool) -> [UsageLimit]? {
        if let limits = notchLimits { return limits }
        guard sessionsPopup, settings.isEnabled(.claudeUsage), settings.claudeRingVisible else { return nil }
        return nearest.map { [$0] } ?? []
    }

    var isSessionPinned: Bool { settings.claudeSessionPinned }

    /// Shows or hides the session beside the notch regardless of the 70 % threshold.
    func toggleSessionPinned() {
        settings.claudeSessionPinned.toggle()
    }

    /// Hides the notch indicator until the nearest limit reaches its next 10 % (or resets).
    func dismissIndicator() {
        settings.claudeSessionPinned = false
        guard let nearest else { return }
        dismissedIndicator = UsageAlerts.dismissMarker(for: nearest)
    }

    /// The limit shown by the menu bar ring: the session, otherwise the fullest one.
    var primary: UsageLimit? {
        limits.first { $0.title.hasPrefix("Session") } ?? limits.max { $0.utilization < $1.utilization }
    }

    var summary: String {
        let text = limits.map { "\($0.title) \(Int($0.utilization.rounded()))%" }.joined(separator: " · ")
        return hasSeveralAccounts && !text.isEmpty ? shownAccount.name + " · " + text : text
    }

    // MARK: - Polling

    func start() {
        settingsObserver = observeChanges { [settings] in _ = settings.isEnabled(.claudeUsage) } onChange: { [weak self] in
            self?.applyEnabled()
        }
        applyEnabled()
    }

    private func applyEnabled() {
        let enabled = settings.isEnabled(.claudeUsage)
        if enabled, timer == nil {
            let settings = settings
            self.timer = Poller.start(
                every: Self.refreshInterval, isActive: { settings.isEnabled(.claudeUsage) }, action: { [weak self] in self?.refresh() }
            )
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
        for account in accounts where usage[account.id]?.limits.isEmpty ?? true {
            usage[account.id, default: AccountUsage()].state = .loading
        }
        let ids = accounts.map(\.id)
        Task {
            defer { isRefreshing = false }
            for id in ids {
                await refresh(id, endpoint: endpoint)
            }
        }
    }

    private func refresh(_ id: String, endpoint: URL) async {
        let token: String
        if id == ClaudeAccount.claudeCodeID {
            switch await credential() {
            case .missing:
                usage[id, default: AccountUsage()].state = .noCredentials
                return
            case .expired:
                usage[id, default: AccountUsage()].state = .signedOut
                return
            case .token(let value, _):
                token = value
            }
        } else {
            guard let value = await accountToken(id) else {
                usage[id, default: AccountUsage()].state = .signedOut
                return
            }
            token = value
        }
        do {
            let (data, status) = try await Self.fetch(endpoint, token: token)
            try handle(data: data, status: status, for: id)
        } catch {
            usage[id, default: AccountUsage()].state = .failed(error.localizedDescription)
        }
    }

    /// ChatGPT's limits from the newest Codex log (spec AI-6).
    func refreshChatGPT() {
        Task { [weak self] in
            let found = await Task.detached { CodexUsage.read() }.value
            if self?.gptLimits != found { self?.gptLimits = found }
            self?.gptUpdated = Date()
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

    private func handle(data: Data, status: Int, for id: String) throws {
        let shape = ClaudeUsageParser.labels(of: data) + "\n" + ClaudeUsageParser.structure(of: data)
        let source = id == ClaudeAccount.claudeCodeID ? "Claude Code" : "added account"
        DiagnosticsLog.write("claude-usage", "HTTP \(status) (\(source))\n" + shape)
        switch status {
        case 200:
            apply(try ClaudeUsageParser.limits(from: data), for: id)
        case 401, 403:
            // Claude Code may have renewed the token meanwhile: read it again next time.
            if id == ClaudeAccount.claudeCodeID { cachedToken = nil } else { storedTokens[id] = nil }
            usage[id, default: AccountUsage()].state = .signedOut
        default:
            usage[id, default: AccountUsage()].state = .failed("HTTP \(status)")
        }
    }

    func apply(_ limits: [UsageLimit], for id: String, now: Date = Date()) {
        var entry = usage[id] ?? AccountUsage()
        let before = entry.session?.utilization
        entry.limits = limits
        entry.lastUpdated = now
        entry.state = .loaded
        // Its session grew: this account is being used (spec CL-10).
        if let before, let after = entry.session?.utilization, after > before {
            entry.lastGrowth = now
            activeID = id
        }
        usage[id] = entry
        alert(limits, for: id, now: now)
    }

    nonisolated private static func fetch(_ url: URL, token: String) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Wingmate", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
