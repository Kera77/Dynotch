import Foundation
import Security

/// A chat as the Beeper Desktop API returns it (only the fields used).
struct BeeperChat: Decodable, Equatable, Sendable {
    let id: String
    let title: String?
    let unreadCount: Int?
    let lastActivity: String?
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

    // MARK: - Token (Dynotch's own keychain item, so no password prompt)

    private static let tokenService = "com.peterkereki.Dynotch.beeper-token"

    static var hasToken: Bool {
        token() != nil
    }

    static func token() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(bytes: data, encoding: .utf8)
    }

    /// Stores the token; an empty string removes it.
    static func setToken(_ token: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: tokenService]
        SecItemDelete(base as CFDictionary)
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var item = base
        item[kSecValueData as String] = Data(trimmed.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }

    // MARK: - API

    /// Sends `text` to the chat the notification came from, found by its title.
    func reply(to chatName: String, text: String) async throws {
        guard let token = Self.token() else { throw BeeperError.noToken }
        let chats = try await searchChats(chatName, token: token)
        guard let chat = Self.bestMatch(for: chatName, in: chats) else { throw BeeperError.chatNotFound(chatName) }
        try await send(text, to: chat.id, token: token)
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

    private func send(_ text: String, to chatID: String, token: String) async throws {
        let path = "/v1/chats/" + (chatID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])) ?? chatID)
            + "/messages"
        _ = try await request(path: path, method: "POST", body: try JSONEncoder().encode(["text": text]), token: token)
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
