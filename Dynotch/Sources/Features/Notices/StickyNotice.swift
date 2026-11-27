import Foundation

/// A message that stays under the closed notch until it is swiped away (spec CN-1).
struct StickyNotice: Equatable, Sendable {
    let title: String
    let detail: String
    let date: Date
    /// Hovering it opens the Claude chat (spec CC-5).
    var opensChat = false
    /// Claude Code waits for an answer: the notice goes when it is answered (spec CQ-1).
    var isQuestion = false
    /// The app Claude Code runs in (Terminal, VS Code…), brought forward on hover (spec CQ-3).
    var appIdentifier: String?
    /// An SF Symbol instead of Claude's mark, e.g. for Dynotch's own update (spec U-5).
    var symbol: String?
    /// An app's icon instead of Claude's mark, e.g. ChatGPT's (spec CN-8).
    var iconApp: String?
    /// Who it is from, when the icon does not tell (e.g. the chat's service).
    var sourceName: String?
    /// A finished download: a download icon and a green tick, gone after 3 s (spec PV-57).
    var download: URL?
    /// A click opens this module, e.g. the Tools after a timer (spec TM-5, WX-7).
    var opens: FeatureID?
    /// Goes by itself after this many seconds (spec TM-5, WX-7).
    var stays: TimeInterval?
    /// After an update: hovering opens What's new in the notch; only its Got it removes it (spec WN-6, WN-7).
    var whatsNew: [WhatsNewRelease]?
    /// Counts down to an action, e.g. Spencer's switch; Cancel in place of the X (spec SL-4).
    var countdown: DateInterval?
    /// Claude Code waits for an answer from the notch's buttons (spec CQ-5).
    var reply: ClaudeReplyRequest?

    /// A download in `~/Downloads` finished (spec PV-57).
    static func downloaded(_ file: URL) -> StickyNotice {
        StickyNotice(
            title: "Downloaded", detail: String(file.lastPathComponent.prefix(60)), date: Date(),
            symbol: "arrow.down.circle.fill", sourceName: "Downloads", download: file
        )
    }

    /// The chat in the notch answered (spec CC-5).
    static func answered(by service: String, in chat: String) -> StickyNotice {
        StickyNotice(title: "\(service) answered", detail: chat, date: Date(), opensChat: true, sourceName: service)
    }

    /// Who it is from, written beside its icon in the Wings (spec PV-37).
    var source: String {
        if let sourceName { return sourceName }
        if symbol != nil { return "Wingmate" }
        if iconApp == "com.openai.codex" { return "ChatGPT" }
        return "Claude"
    }
}
