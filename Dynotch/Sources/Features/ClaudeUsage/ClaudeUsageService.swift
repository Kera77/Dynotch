import AppKit
import Combine
import Security

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

    private static let refreshInterval: TimeInterval = 5 * 60
    private static let minimumInterval: TimeInterval = 60
    private static let notifiedKey = "claudeUsageNotified"
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

    /// Limits to show beside the notch, or nil when the indicator is off or hidden (spec CL-6).
    var notchLimits: [UsageLimit]? {
        guard settings.isEnabled(.claudeUsage), settings.claudeRingVisible, state == .loaded,
              !limits.isEmpty, let peak, !UsageAlerts.isDismissed(peak, marker: dismissedIndicator)
        else { return nil }
        return limits
    }

    /// Hides the notch indicator until the fullest limit reaches its next 10 % (or resets).
    func dismissIndicator() {
        guard let peak else { return }
        dismissedIndicator = UsageAlerts.dismissMarker(for: peak)
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
        guard !isRefreshing, let endpoint = Self.endpoint else { return }
        isRefreshing = true
        if limits.isEmpty { state = .loading }
        Task {
            defer { isRefreshing = false }
            // The keychain may ask the user for permission: not on the main thread.
            let credential = await Task.detached { ClaudeCredential.read() }.value
            switch credential {
            case .missing:
                state = .noCredentials
                return
            case .expired:
                state = .signedOut
                return
            case .token(let token):
                do {
                    let (data, status) = try await Self.fetch(endpoint, token: token)
                    let shape = ClaudeUsageParser.labels(of: data) + "\n" + ClaudeUsageParser.structure(of: data)
                    DiagnosticsLog.write("claude-usage", "HTTP \(status)\n" + shape)
                    switch status {
                    case 200:
                        apply(try ClaudeUsageParser.limits(from: data))
                    case 401, 403:
                        state = .signedOut
                    default:
                        state = .failed("HTTP \(status)")
                    }
                } catch {
                    state = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func apply(_ limits: [UsageLimit]) {
        self.limits = limits
        lastUpdated = Date()
        state = .loaded
        guard settings.claudeUsageAlerts else { return }

        let notified = UserDefaults.standard.dictionary(forKey: Self.notifiedKey) as? [String: Int] ?? [:]
        let result = UsageAlerts.alerts(for: limits, notified: notified)
        UserDefaults.standard.set(result.notified, forKey: Self.notifiedKey)
        for limit in result.due {
            let reset = limit.resetsAt.map { "Resets " + UsageAlerts.resetText($0, now: Date()) } ?? ""
            notify("Claude: \(limit.title) \(Int(limit.utilization.rounded()))%", "You are close to the limit. \(reset)")
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
    case token(String)
    case expired
    case missing

    static let service = "Claude Code-credentials"

    nonisolated static func read() -> ClaudeCredential {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return .missing
        }
        return parse(data, now: Date())
    }

    nonisolated static func parse(_ data: Data, now: Date) -> ClaudeCredential {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return .missing }
        if let expiresAt = (oauth["expiresAt"] as? NSNumber)?.doubleValue,
           Date(timeIntervalSince1970: expiresAt / 1000) <= now {
            return .expired
        }
        return .token(token)
    }
}
