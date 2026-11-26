import AppKit
import Observation

/// Follows the web Teams through Accessibility: its chats, the open chat's messages, replies,
/// and the meeting's toolbar (spec MT-1…MT-8).
@MainActor
@Observable
final class TeamsService {
    static let shared = TeamsService()

    enum State: Equatable {
        case off, noAccess, notFound, reading
        /// Teams is open, but in a tab behind another one (spec MT-13).
        case backgroundTab
    }

    private(set) var state: State = .off
    private(set) var snapshot: TeamsSnapshot?
    /// The Teams tab found behind another one, to move to a window of its own (spec MT-13).
    var backgroundTab: TeamsTabs.Tab?
    /// The web Teams was readable at least once since launch: its tab is shown (spec MT-3).
    private(set) var wasSeen = false
    /// When the meeting was first seen (spec MT-6).
    private(set) var meetingSince: Date?
    /// Leave was clicked once; a second click within 3 s leaves (spec MT-6).
    private(set) var confirmsLeave = false

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: "teamsEnabled"); restart() }
    }

    var muteShortcut: KeyShortcut? {
        didSet {
            defaults.set(muteShortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: "teamsMuteShortcut")
            hotkey.register(muteShortcut)
        }
    }

    var warnsWhenMuted: Bool {
        didSet { defaults.set(warnsWhenMuted, forKey: "teamsWarnMuted"); updateMicWatch() }
    }

    var meeting: TeamsMeeting? { snapshot?.meeting }

    /// The tab shows once the web Teams was read or sent a notification (spec MT-3).
    func showsTab(_ notifications: NotificationService) -> Bool {
        isEnabled && (wasSeen || notifications.recent.contains(where: TeamsTabView.isTeams))
    }

    /// The meeting beside the notch (spec MT-6).
    var indicator: (TeamsMeeting, Date)? {
        guard let meeting, let meetingSince else { return nil }
        return (meeting, meetingSince)
    }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isReading = false
    @ObservationIgnored private var lastLogged: String?
    @ObservationIgnored private var hud: HUDService?
    @ObservationIgnored private lazy var hotkey = TeamsMuteHotkey { [weak self] in self?.shortcutPressed() }
    @ObservationIgnored private let mic = TeamsMicWatcher()
    @ObservationIgnored private var lastWarning = Date.distantPast
    @ObservationIgnored private var leaveReset: Task<Void, Never>?

    private init() {
        isEnabled = defaults.object(forKey: "teamsEnabled") as? Bool ?? true
        warnsWhenMuted = defaults.object(forKey: "teamsWarnMuted") as? Bool ?? true
        muteShortcut = defaults.data(forKey: "teamsMuteShortcut").flatMap { try? JSONDecoder().decode(KeyShortcut.self, from: $0) }
    }

    func start(hud: HUDService) {
        self.hud = hud
        mic.onSpeech = { [weak self] in self?.spokeWhileMuted() }
        hotkey.register(muteShortcut)
        restart()
    }

    // MARK: - Reading

    private func restart() {
        timer?.invalidate()
        timer = nil
        guard isEnabled else {
            snapshot = nil
            setState(.off)
            updateMeeting(nil)
            return
        }
        schedule()
        refresh()
    }

    /// Every 8 s; every 2 s during a meeting, for the microphone (spec MT-6).
    private func schedule() {
        timer?.invalidate()
        let interval: TimeInterval = meetingSince == nil ? 8 : 2
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { TeamsService.shared.refresh() }
        }
    }

    func refresh() {
        guard isEnabled, !isReading else { return }
        guard AXIsProcessTrusted() else { return setState(.noAccess) }
        isReading = true
        Task {
            let read = await Task.detached { () -> TeamsSnapshot? in
                guard let page = TeamsWebReader.findPage() else { return nil }
                return TeamsWebReader.snapshot(page)
            }.value
            apply(read)
            // Not readable: perhaps in a background tab (spec MT-13).
            if read == nil { await findBackgroundTab() }
            isReading = false
        }
    }

    private func apply(_ read: TeamsSnapshot?) {
        guard isEnabled else { return }
        snapshot = read
        if let read {
            backgroundTab = nil
            wasSeen = true
            setState(.reading, detail: read.browser)
        } else {
            setState(.notFound)
        }
        updateMeeting(read?.meeting)
    }

    private func updateMeeting(_ meeting: TeamsMeeting?) {
        let wasOn = meetingSince != nil
        if meeting != nil, !wasOn {
            meetingSince = Date()
            TeamsLog.write("meeting started")
        } else if meeting == nil, wasOn {
            meetingSince = nil
            confirmsLeave = false
            TeamsLog.write("meeting ended")
        }
        if wasOn != (meetingSince != nil), isEnabled { schedule() }
        updateMicWatch()
    }

    func setState(_ new: State, detail: String = "") {
        state = new
        let line = "state: \(new)" + (detail.isEmpty ? "" : " (\(detail))")
        guard line != lastLogged else { return }
        lastLogged = line
        TeamsLog.write(line)
    }

    // MARK: - Chats (spec MT-4)

    /// Opens the chat in the background and gives its messages once the page shows them.
    func openAndRead(_ chatID: String) async -> [TeamsMessage]? {
        guard snapshot?.openID != chatID else {
            refresh()
            return snapshot?.messages
        }
        let opened = await Task.detached { () -> Bool in
            guard let page = TeamsWebReader.findPage() else { return false }
            return TeamsWebReader.open(chat: chatID, on: page)
        }.value
        guard opened else { return nil }
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(300))
            let read = await Task.detached { TeamsWebReader.findPage().flatMap(TeamsWebReader.snapshot) }.value
            if let read, read.openID == chatID, !read.messages.isEmpty {
                apply(read)
                return read.messages
            }
        }
        return nil
    }

    /// Sends a reply into the chat; true once it shows up among the chat's messages.
    func send(_ text: String, to chatID: String) async -> Bool {
        guard await openAndRead(chatID) != nil else {
            TeamsLog.write("reply: chat not opened")
            return false
        }
        let pressed = await Task.detached { () -> Bool in
            guard let page = TeamsWebReader.findPage() else { return false }
            return TeamsWebReader.send(text, on: page)
        }.value
        guard pressed else {
            TeamsLog.write("reply: not sent")
            return false
        }
        let wanted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for _ in 0..<10 {
            try? await Task.sleep(for: .milliseconds(300))
            let read = await Task.detached { TeamsWebReader.findPage().flatMap(TeamsWebReader.snapshot) }.value
            if let read, read.messages.suffix(3).contains(where: { $0.isMine && $0.text.contains(wanted.prefix(40)) }) {
                apply(read)
                TeamsLog.write("reply sent")
                return true
            }
        }
        TeamsLog.write("reply: not confirmed")
        return false
    }

    /// Brings the browser forward with the chat open (spec MT-4).
    func openInBrowser(chat id: String?) {
        Task.detached {
            guard let page = TeamsWebReader.findPage() else { return }
            if let id { _ = TeamsWebReader.open(chat: id, on: page) }
            AXUIElementPerformAction(page.window, kAXRaiseAction as CFString)
            await MainActor.run { NSRunningApplication(processIdentifier: page.pid)?.activate() }
        }
    }

    // MARK: - Meeting (spec MT-6, MT-7)

    func perform(_ control: TeamsControl) {
        if control == .leave, !confirmsLeave {
            confirmsLeave = true
            leaveReset?.cancel()
            leaveReset = Task {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { confirmsLeave = false }
            }
            return
        }
        confirmsLeave = false
        Task {
            let done = await Task.detached { () -> Bool in
                guard let page = TeamsWebReader.findPage() else { return false }
                return TeamsWebReader.press(control, on: page)
            }.value
            TeamsLog.write("\(control.rawValue): \(done ? "pressed" : "not found")")
            try? await Task.sleep(for: .milliseconds(400))
            refresh()
        }
    }

    private func shortcutPressed() {
        guard let meeting else {
            hud?.announce(symbol: "video.slash", text: "No Teams meeting")
            return
        }
        TeamsLog.write("mute shortcut")
        let willMute = !(meeting.isMuted ?? false)
        perform(.mic)
        hud?.announce(symbol: willMute ? "mic.slash.fill" : "mic.fill", text: willMute ? "Teams: muted" : "Teams: mic on")
    }

    // MARK: - Talking while muted (spec MT-8)

    private func updateMicWatch() {
        let watch = isEnabled && warnsWhenMuted && meeting?.isMuted == true
        mic.setWatching(watch)
    }

    private func spokeWhileMuted() {
        guard meeting?.isMuted == true, Date().timeIntervalSince(lastWarning) > 20 else { return }
        lastWarning = Date()
        TeamsLog.write("warned: talking while muted")
        hud?.announce(symbol: "mic.slash.fill", text: "You're muted in Teams")
    }
}

/// `teams.log`: states and kinds of actions, never names or messages (spec MT-12).
enum TeamsLog {
    static func write(_ line: String) {
        DiagnosticsLog.append("teams", line)
    }
}
