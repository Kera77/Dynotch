import AppKit

extension NoticeService {
    // MARK: - Answers from the notch (spec CQ-5, CQ-6)

    /// A question with buttons, unless its app is already in front: then Claude Code asks there.
    func showQuestion(_ question: StickyNotice) {
        var question = question
        // A plain question of the same app does not cover the one that waits for buttons.
        if question.reply == nil, let shown = notice, shown.reply != nil, shown.appIdentifier == question.appIdentifier {
            return
        }
        if let reply = question.reply {
            if let app = question.appIdentifier, NSWorkspace.shared.frontmostApplication?.bundleIdentifier == app {
                reply.send(choice: nil)
                question.reply = nil
            } else {
                waitingReplies[reply.replyPath] = reply
                watchActivation()
                replyExpiry?.cancel()
                replyExpiry = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(ClaudeReplyRequest.waits))
                    guard !Task.isCancelled else { return }
                    self?.withdrawButtons(pass: true)
                }
            }
        }
        show(question)
    }

    /// A button of the top notice: the answer goes to Claude Code and the notice goes.
    func answer(_ choice: String) {
        guard let shown = notice, let reply = shown.reply, waitingReplies.removeValue(forKey: reply.replyPath) != nil else { return }
        reply.send(choice: choice)
        remove(shown)
    }

    /// The buttons go and the notice stays a plain question (its app came forward, or time ran out).
    func withdrawButtons(pass: Bool) {
        guard let shown = notice, let reply = shown.reply else { return }
        if pass, waitingReplies.removeValue(forKey: reply.replyPath) != nil { reply.send(choice: nil) }
        var plain = shown
        plain.reply = nil
        notice = plain
    }

    /// Hooks whose notice is gone (X, swipe, covered) ask in Claude Code as usual.
    func settleReplies() {
        let shown = Set([notice?.reply?.replyPath, second?.reply?.replyPath].compactMap { $0 })
        for (path, reply) in waitingReplies where !shown.contains(path) {
            waitingReplies[path] = nil
            reply.send(choice: nil)
        }
        if waitingReplies.isEmpty { replyExpiry?.cancel() }
    }

    /// The app Claude Code runs in came forward: it asks there (spec CQ-6).
    func watchActivation() {
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                guard let self, let app, self.notice?.reply != nil, self.notice?.appIdentifier == app else { return }
                self.withdrawButtons(pass: true)
            }
        }
    }
}
