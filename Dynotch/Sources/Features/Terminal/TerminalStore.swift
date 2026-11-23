import AppKit
import Combine
import SwiftTerm

/// The Terminal module's shells. They live on while the notch is closed, switches modules or
/// moves to another display (spec TE-1…TE-4). Nothing typed or shown is logged (spec TE-8).
@MainActor
final class TerminalStore: ObservableObject {
    static let shared = TerminalStore()

    static let maxTabs = 8
    static let fontSizes: ClosedRange<CGFloat> = 9...24
    static let defaultFontSize: CGFloat = 12
    /// How long after the last key the notch stays open with the pointer outside (spec TE-9).
    static let typingHold: TimeInterval = 10

    @Published private(set) var sessions: [TerminalSession] = []
    @Published var selectedID: UUID?
    @Published private(set) var fontSize: CGFloat {
        didSet { defaults.set(Double(fontSize), forKey: Self.fontKey) }
    }

    private static let fontKey = "terminalFontSize"
    private let defaults: UserDefaults
    private var lastInputAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = (defaults.object(forKey: Self.fontKey) as? Double).map { CGFloat($0) } ?? Self.defaultFontSize
        fontSize = min(max(stored, Self.fontSizes.lowerBound), Self.fontSizes.upperBound)
    }

    var selected: TerminalSession? {
        sessions.first { $0.id == selectedID } ?? sessions.last
    }

    /// The shell shown, started when there is none (spec TE-3).
    func current() -> TerminalSession? {
        selected ?? newSession()
    }

    @discardableResult
    func newSession() -> TerminalSession? {
        guard sessions.count < Self.maxTabs else { return nil }
        let session = TerminalSession(fontSize: fontSize) { [weak self] session, code in self?.ended(session, exitCode: code) }
        session.onInput = { [weak self] in self?.lastInputAt = Date() }
        sessions.append(session)
        selectedID = session.id
        DiagnosticsLog.append("terminal", "tab started (\(sessions.count) open)")
        return session
    }

    func close(_ session: TerminalSession) {
        session.terminate()
        remove(session)
    }

    func closeSelected() {
        if let selected { close(selected) }
    }

    /// ⌘1…⌘9 picks a tab.
    func select(index: Int) {
        guard sessions.indices.contains(index) else { return }
        selectedID = sessions[index].id
    }

    /// ⌘⇧[ and ⌘⇧] step through the tabs.
    func step(by offset: Int) {
        guard let selected, let index = sessions.firstIndex(where: { $0.id == selected.id }), !sessions.isEmpty else { return }
        select(index: (index + offset + sessions.count) % sessions.count)
    }

    /// ⌘+ ⌘− change the size, ⌘0 (nil) resets it (spec TE-2).
    func setFontSize(_ size: CGFloat?) {
        let next = min(max(size ?? Self.defaultFontSize, Self.fontSizes.lowerBound), Self.fontSizes.upperBound)
        guard next != fontSize else { return }
        fontSize = next
        sessions.forEach { $0.setFontSize(next) }
    }

    /// A key went into a shell a moment ago: the notch stays open (spec TE-9).
    var typedRecently: Bool {
        lastInputAt.map { Date().timeIntervalSince($0) < Self.typingHold } ?? false
    }

    private func ended(_ session: TerminalSession, exitCode: Int32?) {
        DiagnosticsLog.append("terminal", "tab ended, exit \(exitCode.map(String.init) ?? "signal")")
        remove(session)
    }

    private func remove(_ session: TerminalSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions.remove(at: index)
        if selectedID == session.id {
            selectedID = sessions.isEmpty ? nil : sessions[min(index, sessions.count - 1)].id
        }
    }
}
