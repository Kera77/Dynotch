import Foundation

/// One chat of the web Teams' chat list (spec MT-3).
struct TeamsChat: Equatable, Sendable, Identifiable {
    /// The thread id the page names the chat by ("19:…@thread.v2", "48:notes").
    let id: String
    var name: String
    var preview = ""
    var time = ""
    var isUnread = false
    /// Someone @mentioned the owner (spec MT-3).
    var isMention = false
}

/// A message of the chat open in the web Teams (spec MT-4).
struct TeamsMessage: Equatable, Sendable, Identifiable {
    let id: String
    var sender: String?
    var text: String
    var isMine = false
}

/// A control of the meeting's toolbar (spec MT-6).
enum TeamsControl: String, CaseIterable, Sendable {
    case mic, camera, hand, share, leave

    var help: String {
        switch self {
        case .mic: "Microphone"
        case .camera: "Camera"
        case .hand: "Raise or lower your hand"
        case .share: "Share"
        case .leave: "Leave the meeting"
        }
    }
}

/// The meeting going on in the web Teams (spec MT-6).
struct TeamsMeeting: Equatable, Sendable {
    var title: String
    /// Nil when the toolbar does not say.
    var isMuted: Bool?
    var isCameraOn: Bool?
    var isHandRaised = false
    var controls: Set<TeamsControl> = []
}

/// What the web Teams shows (spec MT-1).
struct TeamsSnapshot: Equatable, Sendable {
    var chats: [TeamsChat] = []
    /// The open chat's id, from its header.
    var openID: String?
    var messages: [TeamsMessage] = []
    var meeting: TeamsMeeting?
    /// The browser the page was found in, for the log.
    var browser = ""

    /// Unread first, @mentions before the others, then the list's order (spec MT-3).
    var unread: [TeamsChat] {
        let unread = chats.filter(\.isUnread)
        return unread.filter(\.isMention) + unread.filter { !$0.isMention }
    }
}

/// The pure rules of reading the web Teams (tested).
enum TeamsPage {
    static let hosts = ["teams.live.com", "teams.microsoft.com", "teams.cloud.microsoft"]

    private static let titlePrefix = "title-chat-list-item_"
    private static let previewPrefix = "message-preview-chat-list-item_"
    private static let timePrefix = "time-chat-list-item_"
    static let headerPrefix = "chat-header-"
    static let composerPrefix = "new-message-"
    static let ownMessageClass = "fui-ChatMyMessage__body"

    enum Part: Equatable {
        case title(String), preview(String), time(String), header(String)
        case author(String), body(String), content(String)
    }

    /// What a DOM id marks on the page; nil for anything else.
    static func part(ofDOM id: String) -> Part? {
        if id.hasPrefix(titlePrefix) { return .title(String(id.dropFirst(titlePrefix.count))) }
        if id.hasPrefix(previewPrefix) { return .preview(String(id.dropFirst(previewPrefix.count))) }
        if id.hasPrefix(timePrefix) { return .time(String(id.dropFirst(timePrefix.count))) }
        // "chat-header-19:…": the chat's thread id has a colon.
        if id.hasPrefix(headerPrefix), id.dropFirst(headerPrefix.count).contains(":") {
            return .header(String(id.dropFirst(headerPrefix.count)))
        }
        for (prefix, make) in [("author-", Part.author), ("message-body-", Part.body), ("content-", Part.content)] {
            let rest = id.dropFirst(prefix.count)
            if id.hasPrefix(prefix), !rest.isEmpty, rest.allSatisfy(\.isNumber) { return make(String(rest)) }
        }
        return nil
    }

    /// A browser window showing Teams: its title names Teams or its host (Ardia: "Profile — teams.live.com").
    static func isTeamsWindow(title: String) -> Bool {
        let lowered = title.lowercased()
        return lowered.contains("microsoft teams") || hosts.contains { lowered.contains($0) }
    }

    static func isTeamsHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// The chat list item's spoken label carries "Unread message" for an unread chat.
    static func isUnread(label: String) -> Bool {
        let lowered = label.lowercased()
        return lowered.contains("unread") || lowered.contains("olvasatlan")
    }

    static func isMention(label: String) -> Bool {
        let lowered = label.lowercased()
        return lowered.contains("at mention") || lowered.contains("mentioned") || lowered.contains("említ")
    }

    /// The meeting's name from the page's title: "Meeting with Anna | Microsoft Teams" → "Meeting with Anna".
    static func meetingTitle(fromPageTitle title: String) -> String {
        let parts = title.components(separatedBy: " | ").filter { !$0.localizedCaseInsensitiveContains("microsoft teams") }
        let name = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "Teams meeting" : name
    }

    /// Which toolbar control a button is, from its DOM id or its label; nil for other buttons.
    static func control(domID: String, label: String) -> TeamsControl? {
        let id = domID.lowercased()
        let text = label.lowercased()
        if id.hasPrefix("hangup") || text.hasPrefix("leave") || text.hasPrefix("hang up") { return .leave }
        if id == "microphone-button" || text.hasPrefix("mute") || text.hasPrefix("unmute") || text.hasPrefix("mic") {
            return .mic
        }
        if id == "video-button" || text.contains("camera") { return .camera }
        if id.contains("raisehand") || id.contains("raise-hand") || text.hasPrefix("raise") || text.hasPrefix("lower") {
            return .hand
        }
        if id == "share-button" || text.hasPrefix("share") || text.hasPrefix("stop sharing") { return .share }
        return nil
    }

    /// The microphone is muted: the button offers "Unmute"; a toggle that is on means a live mic.
    static func isMuted(label: String, toggleValue: Int?) -> Bool? {
        let text = label.lowercased()
        if text.hasPrefix("unmute") || text.contains("mic is off") || text.contains("muted") { return true }
        if text.hasPrefix("mute") { return false }
        return toggleValue.map { $0 == 0 }
    }

    /// The camera is on: the button offers to turn it off.
    static func isCameraOn(label: String, toggleValue: Int?) -> Bool? {
        let text = label.lowercased()
        if text.contains("turn camera off") || text.contains("turn off camera") { return true }
        if text.contains("turn camera on") || text.contains("turn on camera") { return false }
        return toggleValue.map { $0 == 1 }
    }

    /// The hand is up: the button offers to lower it.
    static func isHandRaised(label: String, toggleValue: Int?) -> Bool {
        label.lowercased().hasPrefix("lower") || toggleValue == 1
    }
}
