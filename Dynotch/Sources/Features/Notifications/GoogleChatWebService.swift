import AppKit
import Combine

/// Follows the Google Chat web app (Safari, added to the Dock) through Accessibility: which
/// conversations are unread, and replies typed straight into its message box (spec GW-1…GW-15).
@MainActor
final class GoogleChatWebService: ObservableObject {
    enum State: Equatable {
        case off
        case noAccess
        case notRunning
        case notRecognized
        case reading
    }

    /// The web app can't be used for this: reply the old way (spec GW-9).
    struct Unavailable: Error {}

    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    @Published private(set) var state: State = .off
    @Published private(set) var snapshot: ChatWebSnapshot?
    /// When each conversation was last seen unread (spec GW-7).
    private(set) var lastSeenUnread: [String: Date] = [:]

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: "googleChatWebEnabled"); restart() }
    }

    /// Seconds between two reads (spec GW-6).
    @Published var interval: Int {
        didSet { defaults.set(interval, forKey: "googleChatWebInterval"); restart() }
    }

    static let intervalRange = 5...30

    /// Called with every new snapshot.
    var onSnapshot: ((ChatWebSnapshot) -> Void)?

    private let defaults: UserDefaults
    private var timer: Timer?
    private var isReading = false
    private(set) var windowTokenHint: UInt64?
    private var lastLoggedState: State?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: "googleChatWebEnabled") as? Bool ?? true
        let stored = defaults.object(forKey: "googleChatWebInterval") as? Int ?? 10
        interval = min(max(stored, Self.intervalRange.lowerBound), Self.intervalRange.upperBound)
    }

    func start() { restart() }

    func stop() {
        timer?.invalidate()
        timer = nil
        snapshot = nil
        state = .off
    }

    private func restart() {
        timer?.invalidate()
        timer = nil
        guard isEnabled else { return stop() }
        timer = RepeatingTimer.start(every: TimeInterval(interval)) { [weak self] in self?.refresh() }
        refresh()
    }

    /// The Google Chat web app, if it runs.
    nonisolated static func webAppPID() -> pid_t? {
        webApp()?.processIdentifier
    }

    /// The web app's identifier as Notification Center records it (lower case).
    nonisolated static func webAppIdentifier() -> String? {
        webApp()?.bundleIdentifier?.lowercased()
    }

    nonisolated private static func webApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            (app.bundleIdentifier ?? "").hasPrefix("com.apple.Safari.WebApp")
                && (app.localizedName ?? "").localizedCaseInsensitiveContains("chat")
        }
    }

    /// Reads the web app now (also on every Google Chat notification, spec GW-6).
    func refresh() {
        guard isEnabled, !isReading else { return }
        guard AXIsProcessTrusted() else { return setState(.noAccess) }
        guard let pid = Self.webAppPID() else {
            snapshot = nil
            return setState(.notRunning)
        }
        isReading = true
        let hint = windowTokenHint
        Task {
            let result = await Task.detached { GoogleChatWebReader.snapshot(pid: pid, windowToken: hint) }.value
            isReading = false
            apply(result)
        }
    }

    private func apply(_ result: (ChatWebSnapshot, UInt64?)?) {
        guard isEnabled else { return }
        guard let (read, token) = result else {
            snapshot = nil
            return setState(.notRecognized)
        }
        windowTokenHint = token
        let now = Date()
        for conversation in read.conversations where conversation.isUnread { lastSeenUnread[conversation.id] = now }
        snapshot = read
        setState(.reading)
        onSnapshot?(read)
    }

    private func setState(_ new: State) {
        state = new
        guard new != lastLoggedState else { return }
        lastLoggedState = new
        // The state only, never names or messages (spec GW-12, GW-13).
        DiagnosticsLog.write("google-chat-web", "state: \(new)")
    }

    // MARK: - Conversations

    /// The sidebar conversation a notification title names ("Sender (Space)" → the space), or
    /// nil when none or more than one fits.
    func conversation(forTitle title: String) -> ChatWebConversation? {
        guard let snapshot else { return nil }
        return Self.match(title, in: snapshot.conversations)
    }

    nonisolated static func match(_ title: String, in conversations: [ChatWebConversation]) -> ChatWebConversation? {
        let wanted = GoogleChatJump.conversationName(from: title)
        let fold: (String) -> String = {
            $0.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        }
        let exact = conversations.filter { fold($0.name) == fold(wanted) }
        if exact.count == 1 { return exact[0] }
        guard exact.isEmpty else { return nil }
        let loose = conversations.filter { GoogleChatJump.matches(wanted, in: [$0.name]) }
        return loose.count == 1 ? loose[0] : nil
    }

    /// Marks the conversation unread again in the web app: its options menu, then "Mark as
    /// unread" (spec GW-17). Logged without names.
    func markUnread(conversationID id: String) {
        guard state == .reading, let pid = Self.webAppPID() else { return }
        let hint = windowTokenHint
        Task {
            let opened = await Task.detached { GoogleChatWebReader.openOptions(id, pid: pid, windowToken: hint) }.value
            var marked = false
            if opened {
                try? await Task.sleep(for: .milliseconds(600))
                marked = await Task.detached { GoogleChatWebReader.pressMarkUnread(pid: pid, windowToken: hint) }.value
            }
            DiagnosticsLog.append("google-chat-web", "mark unread: options=\(opened) marked=\(marked)")
            try? await Task.sleep(for: .milliseconds(800))
            refresh()
        }
    }

    /// Brings the web app forward with the conversation open (spec GW-19).
    /// - Returns: false when the web app is not running.
    @discardableResult
    func openInApp(title: String) -> Bool {
        guard let pid = Self.webAppPID(), let app = NSRunningApplication(processIdentifier: pid) else { return false }
        app.activate()
        guard let conversation = conversation(forTitle: title) else { return true }
        let hint = windowTokenHint
        let id = conversation.id
        Task.detached { _ = GoogleChatWebReader.open(id, pid: pid, windowToken: hint) }
        return true
    }

    /// The web app can write into this conversation: it is read and the name is unambiguous (spec GW-18).
    func canWrite(title: String) -> Bool {
        state == .reading && conversation(forTitle: title) != nil
    }

    /// Opens the conversation in the web app, in the background, so it is read there too (spec GW-8).
    func markRead(title: String) {
        guard state == .reading, let conversation = conversation(forTitle: title), conversation.isUnread,
              let pid = Self.webAppPID()
        else { return }
        let hint = windowTokenHint
        let id = conversation.id
        Task {
            _ = await Task.detached { GoogleChatWebReader.open(id, pid: pid, windowToken: hint) }.value
            try? await Task.sleep(for: .milliseconds(800))
            refresh()
        }
    }
}
