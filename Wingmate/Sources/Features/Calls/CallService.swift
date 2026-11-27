import AppKit
import ApplicationServices
import Observation

/// Shows incoming calls in the notch (spec P-1…P-4). The call is found by watching for the
/// macOS call banner; answering and declining press that banner's buttons.
@MainActor
@Observable
final class CallService {
    private(set) var call: IncomingCall?
    /// The message field is open (spec P-3).
    var isComposing = false
    var draft = ""
    private(set) var isSending = false
    private(set) var sendError: String?
    /// The caller's Contacts card: picture, and the name when the banner only shows a number.
    private(set) var contact: CallerContact?

    private let settings: AppSettings
    @ObservationIgnored private var watch: WindowListMonitor.Token?
    @ObservationIgnored private var hasBaseline = false
    @ObservationIgnored private var lastTick = Date.distantPast
    @ObservationIgnored private var knownWindows: Set<CGWindowID> = []
    @ObservationIgnored private var isScanning = false
    /// Scans without the banner; it may flicker, so the call ends after two.
    @ObservationIgnored private var misses = 0
    /// Processes to look at for a few more ticks: banners fill in after their window appears.
    @ObservationIgnored private var watched: [pid_t: Int] = [:]
    @ObservationIgnored private var loggedOwners: Set<String> = []
    @ObservationIgnored private var loggedLabels: Set<String> = []
    @ObservationIgnored private lazy var phoneHider = PhoneAppHider(settings: settings)

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        guard watch == nil else { return }
        // Only while calls are on, or to end a shown call once they were turned off (spec RF-8).
        let gate: @MainActor () -> Bool = { [weak self] in
            guard let self else { return false }
            return self.settings.callsEnabled || self.call != nil
        }
        watch = WindowListMonitor.shared.subscribe(every: 1, isActive: gate) { [weak self] windows in self?.tick(windows) }
    }

    private func tick(_ listed: [ListedWindow]) {
        let windows = CallBannerScanner.topWindows(in: listed)
        // The windows already up at launch, or when the watch comes back after a pause, are not new.
        let now = Date()
        if CallBaseline.isStale(lastTick: lastTick, now: now) { hasBaseline = false }
        lastTick = now
        guard hasBaseline else {
            hasBaseline = true
            knownWindows = Set(windows.map(\.id))
            return
        }
        guard settings.callsEnabled, AXIsProcessTrusted() else {
            if call != nil { end() }
            return
        }
        phoneHider.update(isRinging: call != nil)
        for window in windows where Self.mayShowCalls(window.pid) {
            let isNew = !knownWindows.contains(window.id)
            // Banner hosts are watched while their window is on screen, others when one appears.
            if isNew || window.isBannerHost { watched[window.pid] = 4 }
            if isNew, loggedOwners.count < 300, loggedOwners.insert("\(window.owner) \(window.shape)").inserted {
                DiagnosticsLog.append("calls", "new top window: \(window.owner) \(window.shape)")
            }
        }
        knownWindows = Set(windows.map(\.id))

        var pids = Set(watched.keys)
        if let call { pids.insert(call.pid) }
        watched = watched.compactMapValues { $0 > 1 ? $0 - 1 : nil }
        guard !pids.isEmpty, !isScanning else { return }
        isScanning = true
        let current = call?.pid
        let candidates = Array(pids)
        Task { [weak self] in
            let result = await Task.detached { CallBannerScanner.scan(candidates, preferring: current) }.value
            self?.isScanning = false
            if result.call == nil {
                self?.logLabels(result.labels)
            } else {
                self?.logOutline(result.labels)
            }
            self?.update(result.call)
        }
    }

    /// What the watched banners offered when no call was recognised, once per set of labels.
    private func logLabels(_ labels: [String]) {
        guard !labels.isEmpty else { return }
        let signature = Array(Set(labels)).sorted().joined(separator: " | ")
        guard loggedLabels.count < 100, loggedLabels.insert(signature).inserted else { return }
        DiagnosticsLog.append("calls", "no call in banner; buttons: \(String(signature.prefix(400)))")
    }

    /// The shape of a recognised banner (roles, first letters and lengths), once per shape.
    private func logOutline(_ outline: [String]) {
        let signature = outline.joined(separator: " | ")
        guard !signature.isEmpty, loggedLabels.count < 100, loggedLabels.insert(signature).inserted else { return }
        DiagnosticsLog.append("calls", "banner outline: \(String(signature.prefix(600)))")
    }

    /// Call banners come from system agents or the phone apps, not from ordinary apps.
    private static func mayShowCalls(_ pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return true }
        return app.activationPolicy != .regular || ["com.apple.FaceTime", "com.apple.mobilephone"].contains(app.bundleIdentifier ?? "")
    }

    func update(_ found: IncomingCall?) {
        if let found {
            misses = 0
            if call == nil {
                DiagnosticsLog.append("calls", "call banner found; buttons: \(CallBannerScanner.labels(in: found.pid))")
                phoneHider.update(isRinging: true)
            }
            if call?.caller != found.caller { lookUpContact(for: found.caller) }
            if call != found { call = found }
        } else if call != nil {
            misses += 1
            if misses >= 2 { end() }
        }
    }

    private func lookUpContact(for caller: String) {
        contact = nil
        guard caller != CallMatcher.unknownCaller else { return }
        Task { [weak self] in
            let found = await Task.detached { CallMessenger.contact(for: caller) }.value
            guard let self, self.call?.caller == caller else { return }
            self.contact = found
        }
    }

    private func end() {
        call = nil
        contact = nil
        misses = 0
        isComposing = false
        draft = ""
        sendError = nil
    }

    // MARK: - Actions (spec P-2, P-3)

    func accept() {
        perform(.accept)
    }

    func decline() {
        perform(.decline)
    }

    private func perform(_ action: CallAction) {
        guard let pid = call?.pid else { return }
        Task { [weak self] in
            let done = await Task.detached { CallBannerScanner.perform(action, in: pid) }.value
            DiagnosticsLog.append("calls", "\(action): \(done ? "pressed" : "button not found")")
            if done {
                self?.end()
            } else {
                NSSound.beep()
            }
        }
    }

    func toggleComposing() {
        isComposing.toggle()
        sendError = nil
    }

    /// Texts the caller, then declines the call.
    func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let caller = call?.caller, !text.isEmpty, !isSending else { return }
        isSending = true
        sendError = nil
        Task { [weak self] in
            let failure = await Task.detached { CallMessenger.failure(sending: text, toCaller: caller) }.value
            guard let self else { return }
            self.isSending = false
            if let failure {
                DiagnosticsLog.append("calls", "text not sent: \(failure.message)")
                self.sendError = failure.message
            } else {
                self.draft = ""
                self.isComposing = false
                self.decline()
            }
        }
    }
}

/// The calls watch takes the windows on screen as known again after a gap (a pause, calls turned
/// off): they are not new calls (spec RF-8, RF-9).
enum CallBaseline {
    static let maximumGap: TimeInterval = 5

    static func isStale(lastTick: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastTick) > maximumGap
    }
}
