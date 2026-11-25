import CryptoKit
import Foundation
import Network
import Security

/// One Claude subscription whose usage is shown (spec CL-8). The first is always Claude Code's login.
struct ClaudeAccount: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var name: String

    static let claudeCodeID = "claude-code"
    static let claudeCode = ClaudeAccount(id: claudeCodeID, name: "Claude Code")

    var isClaudeCode: Bool { id == Self.claudeCodeID }
}

/// Usage of one account (spec CL-9, CL-10).
struct AccountUsage: Equatable, Sendable {
    var state: ClaudeUsageService.State = .idle
    var limits: [UsageLimit] = []
    var lastUpdated: Date?
    /// Last time its session grew between two refreshes.
    var lastGrowth: Date?

    var session: UsageLimit? { limits.first { $0.title.hasPrefix("Session") } }
}

/// A token from Dynotch's own sign-in, kept and renewed by Dynotch (spec CL-8).
struct StoredClaudeToken: Codable, Equatable, Sendable {
    var access: String
    var refresh: String
    var expiresAt: Date
}

/// Dynotch's own keychain item per added account. Never Claude Code's or the desktop app's item.
enum ClaudeAccountKeychain {
    static let service = "Dynotch Claude account"

    nonisolated static func read(_ id: String) -> StoredClaudeToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: id, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredClaudeToken.self, from: data)
    }

    @discardableResult
    nonisolated static func write(_ token: StoredClaudeToken, for id: String) -> Bool {
        guard let data = try? JSONEncoder().encode(token) else { return false }
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id
        ]
        if SecItemUpdate(match as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecSuccess { return true }
        var add = match
        add[kSecValueData as String] = data
        add[kSecAttrLabel as String] = service
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    nonisolated static func delete(_ id: String) {
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id
        ]
        SecItemDelete(match as CFDictionary)
    }
}

/// claude.ai sign-in, the one `claude /login` uses: PKCE with a `localhost` callback (spec CL-8).
enum ClaudeOAuth {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct SignIn: Sendable {
        let token: StoredClaudeToken
        let suggestedName: String
    }

    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let authorizeURL = "https://claude.com/cai/oauth/authorize"
    static let tokenURL = "https://platform.claude.com/v1/oauth/token"
    static let successURL = "https://platform.claude.com/oauth/code/success?app=claude-code"
    /// Only what reading the usage needs.
    static let scope = "user:profile user:inference"

    /// Opens the browser and waits (up to 5 minutes) for the owner to sign in.
    static func signIn(open: @MainActor (URL) -> Void) async throws -> SignIn {
        let server = try await CallbackServer.start()
        defer { server.stop() }
        let verifier = randomString()
        let state = randomString()
        let redirect = "http://localhost:\(server.port)/callback"
        guard let url = authorizationURL(challenge: challenge(for: verifier), state: state, redirect: redirect) else {
            throw Failure(message: "Couldn't build the sign-in link.")
        }
        await open(url)
        let callback = try await server.waitForCallback(timeout: 300)
        guard callback.state == state else { throw Failure(message: "The sign-in answer didn't match. Try again.") }
        let body: [String: Any] = [
            "grant_type": "authorization_code", "code": callback.code, "redirect_uri": redirect,
            "client_id": clientID, "code_verifier": verifier, "state": state
        ]
        let json = try await post(body)
        guard let token = token(from: json) else { throw Failure(message: "The sign-in returned no token.") }
        return SignIn(token: token, suggestedName: suggestedName(from: json))
    }

    /// A new access token with the refresh token; nil when the sign-in was revoked.
    static func refresh(_ token: StoredClaudeToken) async throws -> StoredClaudeToken? {
        let body: [String: Any] = [
            "grant_type": "refresh_token", "refresh_token": token.refresh, "client_id": clientID, "scope": scope
        ]
        do {
            let json = try await post(body)
            guard var renewed = Self.token(from: json) else { return nil }
            if renewed.refresh.isEmpty { renewed.refresh = token.refresh }
            return renewed
        } catch let failure as Failure where failure.message.hasPrefix("HTTP 4") {
            return nil
        }
    }

    static func authorizationURL(challenge: String, state: String, redirect: String) -> URL? {
        var components = URLComponents(string: authorizeURL)
        components?.queryItems = [
            URLQueryItem(name: "code", value: "true"), URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"), URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "scope", value: scope), URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"), URLQueryItem(name: "state", value: state)
        ]
        return components?.url
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func token(from json: [String: Any], now: Date = Date()) -> StoredClaudeToken? {
        guard let access = json["access_token"] as? String, !access.isEmpty else { return nil }
        let expiresIn = (json["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        return StoredClaudeToken(
            access: access, refresh: json["refresh_token"] as? String ?? "", expiresAt: now.addingTimeInterval(expiresIn)
        )
    }

    /// The organisation's name, or the part of the e-mail before the @ for a personal one.
    static func suggestedName(from json: [String: Any]) -> String {
        let organization = (json["organization"] as? [String: Any])?["name"] as? String ?? ""
        if !organization.isEmpty, !organization.contains("@"), !organization.hasSuffix("'s Organization") {
            return organization
        }
        let email = (json["account"] as? [String: Any])?["email_address"] as? String ?? ""
        let local = email.split(separator: "@").first.map(String.init) ?? ""
        return local.isEmpty ? "Account" : local
    }

    private static func post(_ body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: tokenURL) else { throw Failure(message: "Bad token address.") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Dynotch", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        DiagnosticsLog.write("claude-usage", "account token HTTP \(status)")
        guard status == 200 else { throw Failure(message: "HTTP \(status)") }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure(message: "Unreadable token answer.")
        }
        return json
    }

    private static func randomString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// A one-shot HTTP listener on the loopback interface that catches the sign-in's redirect.
private final class CallbackServer: @unchecked Sendable {
    struct Callback: Sendable {
        let code: String
        let state: String
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "dynotch.claude-oauth")
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Callback, Error>?
    private var finished = false
    private var pending: Result<Callback, Error>?
    private(set) var port: UInt16 = 0

    private init(listener: NWListener) {
        self.listener = listener
    }

    static func start() async throws -> CallbackServer {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        let server = CallbackServer(listener: try NWListener(using: parameters, on: .any))
        try await withCheckedThrowingContinuation { (ready: CheckedContinuation<Void, Error>) in
            let once = OnceFlag()
            server.listener.stateUpdateHandler = { [weak server] state in
                switch state {
                case .ready:
                    server?.port = server?.listener.port?.rawValue ?? 0
                    if once.claim() { ready.resume() }
                case .failed(let error):
                    if once.claim() { ready.resume(throwing: error) }
                default: break
                }
            }
            server.listener.newConnectionHandler = { [weak server] connection in server?.handle(connection) }
            server.listener.start(queue: server.queue)
        }
        return server
    }

    func waitForCallback(timeout: TimeInterval) async throws -> Callback {
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finish(.failure(ClaudeOAuth.Failure(message: "The sign-in timed out.")))
        }
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let pending {
                self.pending = nil
                lock.unlock()
                continuation.resume(with: pending)
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }

    func stop() {
        listener.cancel()
        finish(.failure(CancellationError()))
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            let request = data.flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
            let target = request.split(separator: "\r\n").first?.split(separator: " ").dropFirst().first.map(String.init) ?? ""
            let items = URLComponents(string: "http://localhost" + target)?.queryItems ?? []
            let value = { (name: String) in items.first { $0.name == name }?.value }
            let response: String
            if target.hasPrefix("/callback"), let code = value("code") {
                response = "HTTP/1.1 302 Found\r\nLocation: \(ClaudeOAuth.successURL)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                self?.finish(.success(Callback(code: code, state: value("state") ?? "")))
            } else {
                response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                if target.hasPrefix("/callback") {
                    self?.finish(.failure(ClaudeOAuth.Failure(message: "The sign-in was cancelled.")))
                }
            }
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
        }
    }

    /// The first result wins; one that arrives before anyone waits is kept for the wait.
    private func finish(_ result: Result<Callback, Error>) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        guard let continuation else {
            pending = result
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}

/// Lets a continuation resume only once from a callback that may fire several times.
private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
