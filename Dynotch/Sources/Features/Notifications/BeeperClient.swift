import Foundation
import Security

/// A chat as the Beeper Desktop API returns it (only the fields used).
struct BeeperChat: Decodable, Equatable, Sendable {
    let id: String
    let title: String?
    let unreadCount: Int?
    let lastActivity: String?
}

/// A message as the Beeper Desktop API returns it (only the fields used).
struct BeeperMessage: Decodable, Equatable, Sendable {
    let id: String
    let text: String?
    let timestamp: String?
}

enum BeeperError: Error, Equatable, CustomStringConvertible {
    case noToken
    /// Beeper Desktop is not running or its API is turned off.
    case unreachable
    case unauthorized
    case chatNotFound(String)
    case failed(String)

    var description: String {
        switch self {
        case .noToken: "Add a Beeper Desktop API token in Settings › Notifications."
        case .unreachable: "Beeper Desktop API is not reachable. Is Beeper running with the API turned on?"
        case .unauthorized: "Beeper refused the token. Create a new one in Beeper › Settings › Integrations."
        case .chatNotFound(let name): "No Beeper chat found for \"\(name)\"."
        case .failed(let message): message
        }
    }
}

/// Replies to Beeper chats through the Beeper Desktop API (spec E-11).
struct BeeperClient: Sendable {
    static let baseURL = URL(string: "http://localhost:23373")

    // MARK: - Token

    /// The token lives in a file only the user can read. A keychain item made macOS ask for the
    /// password again after every update, because each build is signed anew.
    static var tokenFile: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent("Dynotch/beeper-token")
    }

    static var hasToken: Bool {
        token() != nil
    }

    static func token(file: URL = tokenFile) -> String? {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Stores the token; an empty string removes it.
    static func setToken(_ token: String, file: URL = tokenFile) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try? FileManager.default.removeItem(at: file)
            return
        }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: file.path, contents: Data(trimmed.utf8), attributes: [.posixPermissions: 0o600])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    // MARK: - API

    /// Sends `text` to the chat the notification came from, found by its title. With `quoting`,
    /// as an answer to that message when Beeper still has it (spec E-17).
    func reply(to chatName: String, text: String, quoting: String? = nil) async throws {
        guard let token = Self.token() else { throw BeeperError.noToken }
        let chats = try await searchChats(chatName, token: token)
        guard let chat = Self.bestMatch(for: chatName, in: chats) else { throw BeeperError.chatNotFound(chatName) }
        var replyTo: String?
        if let quoting, let messages = try? await recentMessages(in: chat.id, token: token) {
            replyTo = Self.message(matching: quoting, in: messages)?.id
        }
        try await send(text, to: chat.id, replyTo: replyTo, token: token)
    }

    /// The newest message whose text is the quoted line (the notification may shorten it).
    static func message(matching quote: String, in messages: [BeeperMessage]) -> BeeperMessage? {
        let wanted = quote.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !wanted.isEmpty else { return nil }
        let texts = messages.map { ($0, ($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
        return texts.last { $0.1 == wanted }?.0
            ?? texts.last { !$0.1.isEmpty && ($0.1.hasPrefix(wanted) || wanted.hasPrefix($0.1)) }?.0
    }

    private func recentMessages(in chatID: String, token: String) async throws -> [BeeperMessage] {
        struct Page: Decodable { let items: [BeeperMessage] }
        let data = try await request(path: Self.messagesPath(chatID), query: [URLQueryItem(name: "limit", value: "30")], token: token)
        // Oldest first, like the notifications.
        return ((try? JSONDecoder().decode(Page.self, from: data))?.items ?? []).sorted { ($0.timestamp ?? "") < ($1.timestamp ?? "") }
    }

    private static func messagesPath(_ chatID: String) -> String {
        "/v1/chats/" + (chatID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])) ?? chatID) + "/messages"
    }

    /// Checks the token against the API (Settings).
    func verify() async throws {
        guard let token = Self.token() else { throw BeeperError.noToken }
        _ = try await request(path: "/v1/chats", query: [URLQueryItem(name: "limit", value: "1")], token: token)
    }

    /// The chat for a notification: the one whose title is the notification's title, otherwise
    /// the one with unread messages, otherwise the first result.
    static func bestMatch(for name: String, in chats: [BeeperChat]) -> BeeperChat? {
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        return chats.first { ($0.title ?? "").lowercased() == wanted }
            ?? chats.first { ($0.unreadCount ?? 0) > 0 }
            ?? chats.first
    }

    private func searchChats(_ name: String, token: String) async throws -> [BeeperChat] {
        struct Page: Decodable { let items: [BeeperChat] }
        let data = try await request(
            path: "/v1/chats/search",
            query: [URLQueryItem(name: "query", value: name), URLQueryItem(name: "limit", value: "10")],
            token: token
        )
        return (try? JSONDecoder().decode(Page.self, from: data))?.items ?? []
    }

    private func send(_ text: String, to chatID: String, replyTo: String?, token: String) async throws {
        var body = ["text": text]
        if let replyTo { body["replyToMessageID"] = replyTo }
        _ = try await request(path: Self.messagesPath(chatID), method: "POST", body: try JSONEncoder().encode(body), token: token)
    }

    private func request(
        path: String, query: [URLQueryItem] = [], method: String = "GET", body: Data? = nil, token: String
    ) async throws -> Data {
        guard let base = Self.baseURL, var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw BeeperError.failed("Invalid URL")
        }
        components.percentEncodedPath = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw BeeperError.failed("Invalid URL") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 10
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BeeperError.unreachable
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300: return data
        case 401, 403: throw BeeperError.unauthorized
        default: throw BeeperError.failed("Beeper answered HTTP \(status)")
        }
    }
}
