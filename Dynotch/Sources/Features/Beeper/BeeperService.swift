import AppKit
import Combine

/// The Beeper tab and the unread chats (spec UM-2, UM-3, BP-1…BP-11): chats and messages from
/// the Beeper Desktop API, kept in memory only.
@MainActor
final class BeeperService: ObservableObject {
    enum State: Equatable {
        case idle
        case ready
        case noToken
        case notRunning
        case failed(String)
    }

    @Published private(set) var state = State.idle
    @Published private(set) var chats: [BeeperChatInfo] = []
    /// An unread chat picked in a badge's drop-down, to open ready to answer (spec B-10f).
    @Published var cardRequest: CardOpenRequest?
    /// The networks of the accounts in Beeper, so a quiet one can be highlighted too (spec BP-17).
    @Published private(set) var accountNetworks: [String] = []
    private var accountsLoadedAt: Date?
    @Published var selectedChatID: String?
    @Published private(set) var messages: [String: [BeeperFullMessage]] = [:]
    /// Messages I just sent that can still be taken back, until the time (spec BP-9).
    @Published private(set) var undoable: [String: Date] = [:]
    @Published private(set) var avatars: [String: NSImage] = [:]
    @Published private(set) var actionError: String?

    /// The chat list beside the conversation (spec BP-1b).
    @Published var showsChatList: Bool {
        didSet { defaults.set(showsChatList, forKey: Self.listKey) }
    }

    /// Networks taken out of Beeper's whole, each with its own badge and tab (spec BP-13).
    @Published private(set) var highlightedNetworks: [String] {
        didSet { defaults.set(highlightedNetworks, forKey: Self.highlightKey) }
    }
    /// Keep unread Beeper chats in the notch (spec UM-7).
    @Published var keepsUnread: Bool {
        didSet {
            defaults.set(keepsUnread, forKey: Self.unreadKey)
            if keepsUnread { start() }
        }
    }

    static let undoTime: TimeInterval = 5
    private static let pollInterval: TimeInterval = 20
    private static let listKey = "beeperShowsChatList"
    private static let unreadKey = "beeperKeepsUnread"
    private static let highlightKey = "beeperHighlightedNetworks"

    private let defaults: UserDefaults
    private var timer: Timer?
    private var loadingAvatars: Set<String> = []
    private var readTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsChatList = defaults.object(forKey: Self.listKey) as? Bool ?? true
        keepsUnread = defaults.object(forKey: Self.unreadKey) as? Bool ?? true
        highlightedNetworks = Self.storedHighlights(defaults)
    }

    /// Every unread, unmuted chat, highlighted networks too.
    var allUnreadChats: [BeeperChatInfo] {
        chats.filter { $0.unread > 0 && $0.isMuted != true }
    }

    /// The unread chats Beeper stands for together: the highlighted networks have their own badge
    /// and tab (spec BP-16).
    var unreadChats: [BeeperChatInfo] {
        let highlighted = Set(highlightedNetworks)
        return allUnreadChats.filter { !highlighted.contains($0.network ?? "") }
    }

    var unreadTotal: Int { unreadChats.reduce(0) { $0 + $1.unread } }

    /// One highlighted network's unread chats (spec BP-15).
    func unreadChats(network: String) -> [BeeperChatInfo] {
        allUnreadChats.filter { $0.network == network }
    }

    func unreadTotal(network: String) -> Int {
        unreadChats(network: network).reduce(0) { $0 + $1.unread }
    }

    /// The networks of Beeper's chats, and the highlighted ones even without a chat now (spec BP-13).
    var knownNetworks: [String] {
        BeeperAccounts.merged(chats: chats.compactMap(\.network), accounts: accountNetworks, highlighted: highlightedNetworks)
    }

    func setHighlighted(_ network: String, _ isOn: Bool) {
        if isOn, !highlightedNetworks.contains(network) {
            highlightedNetworks.append(network)
        } else if !isOn {
            highlightedNetworks.removeAll { $0 == network }
        }
    }

    /// The chat of that name is in a highlighted network: its notification belongs there (spec BP-16).
    func isHighlighted(chatNamed name: String) -> Bool {
        guard !highlightedNetworks.isEmpty else { return false }
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        let matching = chats.filter { $0.name.lowercased() == wanted }
        return !matching.isEmpty && matching.allSatisfy { highlightedNetworks.contains($0.network ?? "") }
    }

    /// The highlighted networks as stored, for those without the service at hand (spec BP-13).
    static func storedHighlights(_ defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: highlightKey) ?? []
    }

    /// Unread first, then the most recent (spec BP-1).
    var sortedChats: [BeeperChatInfo] {
        chats.sorted { lhs, rhs in
            if (lhs.unread > 0) != (rhs.unread > 0) { return lhs.unread > 0 }
            return (lhs.lastActivity ?? "") > (rhs.lastActivity ?? "")
        }
    }

    var selectedChat: BeeperChatInfo? {
        chats.first { $0.id == selectedChatID }
    }

    // MARK: - Loading

    func start() {
        guard timer == nil else { return }
        self.timer = RepeatingTimer.start(every: Self.pollInterval) { [weak self] in self?.refresh() }
        refresh()
    }

    func refresh() {
        guard BeeperClient.hasToken else {
            state = .noToken
            return
        }
        guard keepsUnread || selectedChatID != nil || state != .idle else { return }
        // Nothing to ask while Beeper Desktop is not running.
        guard Self.isBeeperRunning else {
            state = .notRunning
            return
        }
        Task { [weak self] in
            do {
                let found = try await BeeperAPI.chats()
                guard let self else { return }
                if found != self.chats { self.chats = found }
                self.state = .ready
                await self.loadAccountsIfNeeded()
                if let chat = self.selectedChatID { self.loadMessages(chat) }
            } catch let error as BeeperError {
                self?.state = error == .unreachable ? .notRunning : (error == .noToken ? .noToken : .failed(error.description))
            } catch {
                self?.state = .failed("\(error)")
            }
        }
    }

    /// The accounts change rarely: once, then every ten minutes (spec BP-17).
    private func loadAccountsIfNeeded() async {
        if let loaded = accountsLoadedAt, Date().timeIntervalSince(loaded) < 600 { return }
        accountsLoadedAt = Date()
        guard let networks = try? await BeeperAPI.accountNetworks(), !networks.isEmpty else { return }
        DiagnosticsLog.append("beeper", "accounts: \(networks.count) networks")
        if networks != accountNetworks { accountNetworks = networks }
    }

    func loadMessages(_ chatID: String) {
        Task { [weak self] in
            guard let found = try? await BeeperAPI.messages(in: chatID), let self else { return }
            if self.messages[chatID] != found { self.messages[chatID] = found }
        }
    }

    /// Shows a chat. It stays unread until the reply field is clicked (spec UM-3b).
    func open(_ chatID: String) {
        selectedChatID = chatID
        loadMessages(chatID)
        readTask?.cancel()
        readTask = nil
    }

    /// The tab or the notch went away: no reading in the background.
    func stopReading() {
        readTask?.cancel()
        readTask = nil
    }

    func markRead(_ chatID: String) {
        guard chats.first(where: { $0.id == chatID })?.unread ?? 0 > 0 else { return }
        let last = messages[chatID]?.last?.id
        Task { [weak self] in
            do {
                try await BeeperAPI.markRead(chatID, through: last)
                self?.refresh()
            } catch {
                self?.report(error)
            }
        }
    }

    // MARK: - Actions, always on the user's own action (spec BP-10)

    func send(_ text: String, to chatID: String, replyTo: String? = nil, file: URL? = nil) async -> Bool {
        do {
            let upload = try await file.asyncMap(BeeperAPI.upload)
            let pending = try await BeeperAPI.send(text, to: chatID, replyTo: replyTo, upload: upload)
            if let pending { undoable[pending] = Date().addingTimeInterval(Self.undoTime) }
            actionError = nil
            DiagnosticsLog.append("beeper", "sent\(file == nil ? "" : " with a file")")
            try? await Task.sleep(for: .milliseconds(800))
            loadMessages(chatID)
            markRead(chatID)
            return true
        } catch {
            report(error)
            return false
        }
    }

    /// "Undo" within five seconds of sending (spec BP-9).
    func undo(_ messageID: String, in chatID: String) {
        undoable[messageID] = nil
        perform(chatID) { try await BeeperAPI.delete(messageID, in: chatID) }
    }

    func canUndo(_ message: BeeperFullMessage) -> Bool {
        guard message.mine else { return false }
        if let until = undoable[message.id] { return until > Date() }
        // The sent message may come back under its final id: the newest of mine, just sent.
        guard let sent = message.date else { return false }
        return Date().timeIntervalSince(sent) < Self.undoTime && undoable.values.contains { $0 > Date() }
    }

    func delete(_ messageID: String, in chatID: String) {
        perform(chatID) { try await BeeperAPI.delete(messageID, in: chatID) }
    }

    func edit(_ messageID: String, in chatID: String, text: String) {
        perform(chatID) { try await BeeperAPI.edit(messageID, in: chatID, text: text) }
    }

    func react(_ key: String, to message: BeeperFullMessage, in chatID: String) {
        let mine = message.reactions?.contains { $0.reactionKey == key && $0.participantID == myID(in: chatID) } ?? false
        perform(chatID) { try await BeeperAPI.react(key, to: message.id, in: chatID, remove: mine) }
    }

    func remind(_ chatID: String, at date: Date?, cancelOnReply: Bool) {
        Task { [weak self] in
            do {
                try await BeeperAPI.setReminder(chatID, at: date, cancelOnReply: cancelOnReply)
                self?.refresh()
            } catch {
                self?.report(error)
            }
        }
    }

    func openInBeeper(_ chatID: String, messageID: String? = nil, draft: String? = nil) {
        Task { [weak self] in
            do {
                try await BeeperAPI.focus(chatID: chatID, messageID: messageID, draft: draft)
            } catch {
                self?.report(error)
            }
        }
    }

    /// My own id in a chat: the sender of my messages there.
    private func myID(in chatID: String) -> String? {
        messages[chatID]?.first { $0.mine }?.senderID
    }

    private func perform(_ chatID: String, _ action: @escaping @Sendable () async throws -> Void) {
        Task { [weak self] in
            do {
                try await action()
                try? await Task.sleep(for: .milliseconds(500))
                self?.loadMessages(chatID)
            } catch {
                self?.report(error)
            }
        }
    }

    private func report(_ error: Error) {
        actionError = (error as? BeeperError)?.description ?? "\(error)"
        DiagnosticsLog.append("beeper", "action failed: \((error as? BeeperError).map { "\($0)" } ?? "error")")
    }

    static var isBeeperRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { ($0.bundleIdentifier ?? "").lowercased().contains("beeper") }
    }

    /// Pictures kept in memory at most (spec BP-3).
    static let avatarLimit = 200

    // MARK: - Pictures (spec BP-3)

    func avatar(_ address: String?) -> NSImage? {
        guard let address, !address.isEmpty else { return nil }
        if let image = avatars[address] { return image }
        guard loadingAvatars.insert(address).inserted else { return nil }
        Task { [weak self] in
            let url = try? await BeeperAPI.download(address)
            let image = url.flatMap(Self.image(at:))
            guard let self else { return }
            guard let image else {
                // Tried again on a later look, not never.
                self.loadingAvatars.remove(address)
                return
            }
            if self.avatars.count >= Self.avatarLimit { self.avatars.removeAll(keepingCapacity: true) }
            self.avatars[address] = image
        }
        return nil
    }
}

extension BeeperService {
    /// A local file (also a percent-encoded or bare path) or a web address.
    nonisolated static func image(at url: URL) -> NSImage? {
        if url.isFileURL || url.scheme == nil {
            let path = url.isFileURL ? url.path(percentEncoded: false) : url.absoluteString
            return NSImage(contentsOfFile: path)
        }
        return (try? Data(contentsOf: url)).flatMap(NSImage.init(data:))
    }
}

extension Optional {
    /// Maps with an async throwing function.
    func asyncMap<T>(_ transform: (Wrapped) async throws -> T) async rethrows -> T? {
        guard let value = self else { return nil }
        return try await transform(value)
    }
}
