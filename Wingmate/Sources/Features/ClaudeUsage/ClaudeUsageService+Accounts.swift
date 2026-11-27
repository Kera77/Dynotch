import AppKit

/// Added accounts, their tokens and per-account alerts (spec CL-8, CL-9, CL-14).
extension ClaudeUsageService {
    /// An added account's token, renewed by Wingmate shortly before it expires (spec CL-8, CL-9).
    func accountToken(_ id: String) async -> String? {
        if storedTokens[id] == nil {
            storedTokens[id] = await Task.detached { ClaudeAccountKeychain.read(id) }.value
        }
        guard let token = storedTokens[id] else { return nil }
        if token.expiresAt.timeIntervalSinceNow > 5 * 60 { return token.access }
        let renewed: StoredClaudeToken
        do {
            guard let value = try await ClaudeOAuth.refresh(token) else {
                // Revoked: "Signed out" until the owner signs in again (spec CL-9).
                storedTokens[id] = nil
                return nil
            }
            renewed = value
        } catch {
            // A network error: try again at the next refresh.
            return nil
        }
        storedTokens[id] = renewed
        await Task.detached { ClaudeAccountKeychain.write(renewed, for: id) }.value
        return renewed.access
    }

    /// Alerts counted per account, named when there are several (spec CL-5, CL-5b, CL-14).
    func alert(_ limits: [UsageLimit], for id: String, now: Date) {
        let key = id == ClaudeAccount.claudeCodeID ? Self.alertStateKey : Self.alertStateKey + "." + id
        let stored = (settings.defaults.data(forKey: key))
            .flatMap { try? JSONDecoder().decode([String: UsageAlertState].self, from: $0) } ?? [:]
        let result = UsageAlerts.evaluate(limits, state: stored, now: now)
        if let data = try? JSONEncoder().encode(result.state) {
            settings.defaults.set(data, forKey: key)
        }
        guard settings.claudeUsageAlerts else { return }
        let prefix = hasSeveralAccounts ? (accounts.first { $0.id == id }?.name ?? "") + " · " : ""

        // The session started over (spec CL-5b).
        for limit in result.reset where limit.title.hasPrefix("Session") {
            notify("AI session reset", "\(prefix)\(limit.title) is at \(Int(limit.utilization.rounded()))% again.")
        }
        // Only when a new 10 % step is reached, never again for the same step (spec CL-5).
        for limit in result.due {
            let reset = limit.resetsAt.map { "Resets " + UsageAlerts.resetText($0, now: now) } ?? ""
            let message = limit.utilization >= 100 ? "Limit reached." : "You are close to the limit."
            notify("AI usage: \(prefix)\(limit.title) \(Int(limit.utilization.rounded()))%", "\(message) \(reset)")
        }
    }

    // MARK: - Accounts (spec CL-8)

    /// Signs in to claude.ai in the browser and adds the account, or renews `id`'s sign-in.
    func signIn(replacing id: String? = nil) {
        guard !isSigningIn else { return }
        isSigningIn = true
        signInMessage = "Finish signing in in your browser…"
        Task {
            defer { isSigningIn = false }
            do {
                let result = try await ClaudeOAuth.signIn { NSWorkspace.shared.open($0) }
                let accountID = id ?? UUID().uuidString
                guard await Task.detached(operation: { ClaudeAccountKeychain.write(result.token, for: accountID) }).value else {
                    signInMessage = "Couldn't save the sign-in in the keychain."
                    return
                }
                storedTokens[accountID] = result.token
                if id == nil {
                    accounts.append(ClaudeAccount(id: accountID, name: uniqueName(result.suggestedName)))
                    saveAccounts()
                }
                signInMessage = nil
                refresh()
            } catch is CancellationError {
                signInMessage = nil
            } catch {
                signInMessage = "Sign-in failed: \(error.localizedDescription)"
            }
        }
    }

    func rename(_ id: String, to name: String) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        accounts[index].name = trimmed.isEmpty ? (accounts[index].isClaudeCode ? "Claude Code" : "Account") : trimmed
        saveAccounts()
    }

    /// Removes an added account and its token; Claude Code's login stays.
    func remove(_ id: String) {
        guard id != ClaudeAccount.claudeCodeID else { return }
        accounts.removeAll { $0.id == id }
        usage[id] = nil
        storedTokens[id] = nil
        if selection == id { selection = nil }
        if activeID == id { activeID = ClaudeAccount.claudeCodeID }
        settings.defaults.removeObject(forKey: Self.alertStateKey + "." + id)
        saveAccounts()
        Task.detached { ClaudeAccountKeychain.delete(id) }
    }

    func uniqueName(_ name: String) -> String {
        var candidate = name
        var number = 2
        while accounts.contains(where: { $0.name == candidate }) {
            candidate = "\(name) \(number)"
            number += 1
        }
        return candidate
    }

    func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            settings.defaults.set(data, forKey: Self.accountsKey)
        }
    }

    // MARK: - Tests

    /// Puts the service into a loaded state without the keychain or the network (tests, previews).
    func setLoadedState(_ limits: [UsageLimit], updated: Date = Date()) {
        usage[shownID] = AccountUsage(state: .loaded, limits: limits, lastUpdated: updated)
    }

    /// Adds an account and its usage without signing in (tests).
    func setLoadedState(_ limits: [UsageLimit], account: ClaudeAccount, previous: [UsageLimit]? = nil) {
        if !accounts.contains(where: { $0.id == account.id }) { accounts.append(account) }
        if let previous { usage[account.id] = AccountUsage(state: .loaded, limits: previous, lastUpdated: Date()) }
        apply(limits, for: account.id)
    }
}

/// Claude Code's login, read from the keychain item it stores (spec CL-1).
enum ClaudeCredential: Sendable {
    case token(String, expires: Date?)
    case expired
    case missing

    static let service = "Claude Code-credentials"

    /// Read with `/usr/bin/security`, the tool Claude Code itself stores the item with, so the
    /// item's access list allows it and macOS does not ask for the password. (Reading it through
    /// the keychain API asked again every time Claude Code renewed its token.)
    nonisolated static func read() -> ClaudeCredential {
        // A long limit: macOS may ask the owner about the keychain item first.
        guard let result = ProcessRunner.run("/usr/bin/security", ["find-generic-password", "-s", service, "-w"], timeout: 120),
              result.succeeded
        else { return .missing }
        let data = result.output
        let trimmed = String(bytes: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return parse(Data(trimmed.utf8), now: Date())
    }

    nonisolated static func parse(_ data: Data, now: Date) -> ClaudeCredential {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return .missing }
        let expires = ((oauth["expiresAt"] as? NSNumber)?.doubleValue).map { Date(timeIntervalSince1970: $0 / 1000) }
        if let expires, expires <= now {
            return .expired
        }
        return .token(token, expires: expires)
    }
}
