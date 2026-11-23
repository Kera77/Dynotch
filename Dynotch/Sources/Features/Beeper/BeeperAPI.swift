import Foundation

// MARK: - Models (spec BP-1…BP-11)

/// A chat in the Beeper Desktop API, with the fields the Beeper tab uses.
struct BeeperChatInfo: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let accountID: String?
    let network: String?
    let title: String?
    let type: String?
    let unreadCount: Int?
    let isMuted: Bool?
    let isArchived: Bool?
    let lastActivity: String?
    let imgURL: String?
    let participants: BeeperParticipants?
    let reminder: BeeperReminder?
    /// The newest message, for the list.
    let preview: BeeperPreview?

    var name: String { title?.isEmpty == false ? title ?? "Chat" : "Chat" }
    var unread: Int { unreadCount ?? 0 }
    var isGroup: Bool { type == "group" }

    /// The chat's picture; a one-to-one chat often has none of its own, then it is the other
    /// person's (spec BP-3).
    var pictureURL: String? {
        if let imgURL, !imgURL.isEmpty { return imgURL }
        guard !isGroup else { return nil }
        return participants?.items?.first { $0.isSelf != true && $0.imgURL?.isEmpty == false }?.imgURL
    }
}

struct BeeperParticipants: Decodable, Equatable, Sendable {
    let items: [BeeperParticipant]?
}

struct BeeperParticipant: Decodable, Equatable, Sendable {
    let id: String?
    let fullName: String?
    let imgURL: String?
    let isSelf: Bool?
}

struct BeeperPreview: Decodable, Equatable, Sendable {
    let text: String?
    let senderName: String?
    let timestamp: String?
    let isSender: Bool?
}

struct BeeperReminder: Decodable, Equatable, Sendable {
    let remindAt: String?
}

struct BeeperAttachment: Decodable, Equatable, Sendable {
    let type: String?
    let id: String?
    let fileName: String?
    let fileSize: Int?
    let mimeType: String?
    let duration: Double?
    let srcURL: String?
    let posterImg: String?
    let isGif: Bool?
    let isVoiceNote: Bool?
    let transcription: String?
}

struct BeeperReaction: Decodable, Equatable, Sendable {
    let id: String?
    let participantID: String?
    let reactionKey: String?
}

/// A message with everything the conversation view shows.
struct BeeperFullMessage: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let chatID: String?
    let senderID: String?
    let senderName: String?
    let text: String?
    let timestamp: String?
    let sortKey: String?
    let type: String?
    let isSender: Bool?
    let isUnread: Bool?
    let isDeleted: Bool?
    let linkedMessageID: String?
    let attachments: [BeeperAttachment]?
    let reactions: [BeeperReaction]?

    var date: Date? { timestamp.flatMap(BeeperAPI.date(from:)) }
    var mine: Bool { isSender ?? false }
}

// MARK: - Calls

enum BeeperAPI {
    static func date(from text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    static func chatPath(_ chatID: String) -> String {
        "/v1/chats/" + escaped(chatID)
    }

    static func token() throws -> String {
        guard let token = BeeperClient.token() else { throw BeeperError.noToken }
        return token
    }

    /// The most recently active chats (spec BP-1).
    static func chats(limit: Int = 60) async throws -> [BeeperChatInfo] {
        struct Page: Decodable { let items: [BeeperChatInfo] }
        let data = try await BeeperClient().request(
            path: "/v1/chats", query: [URLQueryItem(name: "limit", value: "\(limit)")], token: token()
        )
        return try JSONDecoder().decode(Page.self, from: data).items.filter { $0.isArchived != true }
    }

    /// The networks of the accounts connected in Beeper, chats or not (spec BP-17).
    static func accountNetworks() async throws -> [String] {
        let data = try await BeeperClient().request(path: "/v1/accounts", token: token())
        return BeeperAccounts.networks(from: data)
    }

    /// A chat's latest messages, oldest first.
    static func messages(in chatID: String, limit: Int = 40) async throws -> [BeeperFullMessage] {
        struct Page: Decodable { let items: [BeeperFullMessage] }
        let data = try await BeeperClient().request(
            path: BeeperClient.messagesPath(chatID), query: [URLQueryItem(name: "limit", value: "\(limit)")], token: token()
        )
        return try JSONDecoder().decode(Page.self, from: data).items
            .filter { $0.isDeleted != true && $0.type != "REACTION" }
            .sorted { ($0.sortKey ?? $0.timestamp ?? "") < ($1.sortKey ?? $1.timestamp ?? "") }
    }

    /// Sends text (and one uploaded file), as an answer to a message if given; only ever on the
    /// user's own action (spec BP-10). Returns the pending message's id.
    @discardableResult
    static func send(_ text: String, to chatID: String, replyTo: String? = nil, upload: Upload? = nil) async throws -> String? {
        var body: [String: Any] = [:]
        if !text.isEmpty { body["text"] = text }
        if let replyTo { body["replyToMessageID"] = replyTo }
        if let upload {
            body["attachment"] = [
                "uploadID": upload.uploadID, "type": upload.kind, "fileName": upload.fileName, "mimeType": upload.mimeType
            ]
        }
        let data = try await BeeperClient().request(
            path: BeeperClient.messagesPath(chatID), method: "POST", body: try JSONSerialization.data(withJSONObject: body), token: token()
        )
        struct Sent: Decodable { let pendingMessageID: String? }
        return (try? JSONDecoder().decode(Sent.self, from: data))?.pendingMessageID
    }

    /// Marks the chat read up to a message (spec UM-3).
    static func markRead(_ chatID: String, through messageID: String?) async throws {
        let body = messageID.map { ["messageID": $0] } ?? [:]
        _ = try await BeeperClient().request(
            path: chatPath(chatID) + "/read", method: "POST", body: try JSONEncoder().encode(body), token: token()
        )
    }

    /// Adds or removes a reaction (spec BP-4).
    static func react(_ key: String, to messageID: String, in chatID: String, remove: Bool) async throws {
        let path = chatPath(chatID) + "/messages/" + escaped(messageID) + "/reactions"
        if remove {
            _ = try await BeeperClient().request(path: path + "/" + escaped(key), method: "DELETE", token: token())
        } else {
            _ = try await BeeperClient().request(
                path: path, method: "POST", body: try JSONEncoder().encode(["reactionKey": key]), token: token()
            )
        }
    }

    /// Opens Beeper on the chat (and message), with a draft (spec BP-5).
    static func focus(chatID: String, messageID: String? = nil, draft: String? = nil) async throws {
        var body = ["chatID": chatID]
        if let messageID { body["messageID"] = messageID }
        if let draft, !draft.isEmpty { body["draftText"] = draft }
        _ = try await BeeperClient().request(path: "/v1/focus", method: "POST", body: try JSONEncoder().encode(body), token: token())
    }

    /// Sets or removes the chat's reminder (spec BP-6).
    static func setReminder(_ chatID: String, at date: Date?, cancelOnReply: Bool) async throws {
        guard let date else {
            _ = try await BeeperClient().request(path: chatPath(chatID) + "/reminders", method: "DELETE", token: token())
            return
        }
        let reminder: [String: Any] = ["remindAt": ISO8601DateFormatter().string(from: date), "dismissOnIncomingMessage": cancelOnReply]
        _ = try await BeeperClient().request(
            path: chatPath(chatID) + "/reminders", method: "POST",
            body: try JSONSerialization.data(withJSONObject: ["reminder": reminder]), token: token()
        )
    }

    /// Deletes (the "Undo" of) or edits a message of mine (spec BP-9).
    static func delete(_ messageID: String, in chatID: String) async throws {
        _ = try await BeeperClient().request(path: chatPath(chatID) + "/messages/" + escaped(messageID), method: "DELETE", token: token())
    }

    static func edit(_ messageID: String, in chatID: String, text: String) async throws {
        _ = try await BeeperClient().request(
            path: chatPath(chatID) + "/messages/" + escaped(messageID), method: "PUT",
            body: try JSONEncoder().encode(["text": text]), token: token()
        )
    }

    struct Upload: Sendable {
        let uploadID: String
        let fileName: String
        let mimeType: String
        /// "image", "video", "audio", "gif" or "file".
        let kind: String
    }

    /// Uploads a file for sending (spec BP-7).
    static func upload(_ url: URL) async throws -> Upload {
        let boundary = "dynotch-" + UUID().uuidString
        let fileData = try Data(contentsOf: url)
        let mime = MIMEType.of(url)
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(url.lastPathComponent)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mime)\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let data = try await BeeperClient().request(
            path: "/v1/assets/upload", method: "POST", body: body, token: token(), contentType: "multipart/form-data; boundary=\(boundary)"
        )
        struct Uploaded: Decodable {
            let uploadID: String?
            let error: String?
        }
        let uploaded = try JSONDecoder().decode(Uploaded.self, from: data)
        guard let id = uploaded.uploadID else { throw BeeperError.failed(uploaded.error ?? "Upload failed") }
        return Upload(uploadID: id, fileName: url.lastPathComponent, mimeType: mime, kind: MIMEType.kind(of: mime))
    }

    /// A local file for an mxc:// address (avatars, images).
    static func download(_ address: String) async throws -> URL? {
        if address.hasPrefix("file://") { return URL(string: address) }
        guard address.hasPrefix("mxc://") || address.hasPrefix("localmxc://") else { return URL(string: address) }
        let data = try await BeeperClient().request(
            path: "/v1/assets/download", method: "POST", body: try JSONEncoder().encode(["url": address]), token: token()
        )
        struct Downloaded: Decodable { let srcURL: String? }
        return (try JSONDecoder().decode(Downloaded.self, from: data)).srcURL.flatMap(URL.init(string:))
    }

    private static func escaped(_ part: String) -> String {
        part.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])) ?? part
    }
}

enum MIMEType {
    private static let byExtension: [String: String] = [
        "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "heic": "image/heic",
        "mp4": "video/mp4", "m4v": "video/mp4", "mov": "video/quicktime", "mp3": "audio/mpeg", "m4a": "audio/mp4",
        "pdf": "application/pdf", "txt": "text/plain", "zip": "application/zip"
    ]

    static func of(_ url: URL) -> String {
        byExtension[url.pathExtension.lowercased()] ?? "application/octet-stream"
    }

    static func kind(of mime: String) -> String {
        if mime == "image/gif" { return "gif" }
        if mime.hasPrefix("image/") { return "image" }
        if mime.hasPrefix("video/") { return "video" }
        if mime.hasPrefix("audio/") { return "audio" }
        return "file"
    }
}

/// The accounts list of the Beeper Desktop API: a plain array, or one under "items" (spec BP-17).
enum BeeperAccounts {
    private struct Account: Decodable { let network: String? }
    private struct Page: Decodable { let items: [Account] }

    static func networks(from data: Data) -> [String] {
        let decoder = JSONDecoder()
        let accounts = (try? decoder.decode([Account].self, from: data)) ?? (try? decoder.decode(Page.self, from: data).items) ?? []
        var seen = Set<String>()
        return accounts.compactMap { $0.network?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// One entry per network, sorted: the chats' spelling wins over the accounts' ("Google Chat"
    /// and "googlechat" are one), as chats are matched by it (spec BP-13, BP-17).
    static func merged(chats: [String], accounts: [String], highlighted: [String]) -> [String] {
        func key(_ name: String) -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }
        var byKey: [String: String] = [:]
        for name in highlighted + chats + accounts where !name.isEmpty && byKey[key(name)] == nil {
            byKey[key(name)] = name
        }
        return byKey.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
