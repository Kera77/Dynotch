import AppKit
import ApplicationServices
import Combine

/// Shows incoming calls in the notch (spec P-1…P-4). The call is found by watching for the
/// macOS call banner; answering and declining press that banner's buttons.
@MainActor
final class CallService: ObservableObject {
    @Published private(set) var call: IncomingCall?
    /// The message field is open (spec P-3).
    @Published var isComposing = false
    @Published var draft = ""
    @Published private(set) var isSending = false
    @Published private(set) var sendError: String?

    private let settings: AppSettings
    private var timer: Timer?
    private var knownWindows: Set<CGWindowID> = []
    private var isScanning = false
    /// Scans without the banner; it may flicker, so the call ends after two.
    private var misses = 0
    /// Processes to look at for a few more ticks: banners fill in after their window appears.
    private var watched: [pid_t: Int] = [:]
    private var loggedOwners: Set<String> = []
    private var loggedLabels: Set<String> = []

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        guard timer == nil else { return }
        knownWindows = Set(CallBannerScanner.topWindows().map(\.id))
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard settings.callsEnabled, AXIsProcessTrusted() else {
            if call != nil { end() }
            return
        }
        let windows = CallBannerScanner.topWindows()
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
            self?.logLabels(result.labels)
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
            }
            if call != found { call = found }
        } else if call != nil {
            misses += 1
            if misses >= 2 { end() }
        }
    }

    private func end() {
        call = nil
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
                self.sendError = failure.message
            } else {
                self.draft = ""
                self.isComposing = false
                self.decline()
            }
        }
    }
}
