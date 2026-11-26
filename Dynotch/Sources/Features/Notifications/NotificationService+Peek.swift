import Foundation

/// What stands in the row under the notification hanging below the notch (spec E-28).
enum PeekSecondRow: Equatable {
    case notification(AppNotification)
    case notice(StickyNotice)
}

// MARK: - The peek and the row under it (spec E-3, E-28)

extension NotificationService {
    /// The compact row under the peek.
    nonisolated static let secondRowHeight: CGFloat = 28

    func showPeek(_ notification: AppNotification) {
        // During a Focus, or while the screen is shared, it is listed without popping up (spec E-20d, N-21).
        guard popsUp(notification), !isScreenShared else { return }
        // The pointer rests on the one beside the notch: the newer one waits (spec PV-39).
        if !peekHolders.isEmpty, peek != nil {
            heldPeek = notification
            return
        }
        peekTask?.cancel()
        heldPeek = nil
        let now = Date()
        // Beside the notch only the newest stands (spec PV-66).
        let stays = settings.noticesBeside ? nil : secondPeek.map { ($0, secondDeadline ?? now) }
        let stack = Self.stacked(
            top: settings.noticesBeside ? nil : peek.map { ($0, peekDeadline ?? now) }, second: stays,
            new: notification, now: now, duration: settings.notificationDuration
        )
        peek = stack.top.0
        peekDeadline = stack.top.1
        if secondPeek != stack.second?.0 { secondPeek = stack.second?.0 }
        secondDeadline = stack.second?.1
        runPeekTimer()
    }

    /// The new notification goes on top; a different sender's one still showing moves under it,
    /// keeping its own time; the same sender's is replaced. At most two rows (spec E-28).
    nonisolated static func stacked(
        top: (AppNotification, Date)?, second: (AppNotification, Date)?, new: AppNotification,
        now: Date, duration: TimeInterval
    ) -> (top: (AppNotification, Date), second: (AppNotification, Date)?) {
        let newTop = (new, now.addingTimeInterval(duration))
        let live = [top, second].compactMap { $0 }.filter { $0.1 > now && !sameConversation($0.0, new) }
        return (newTop, live.first)
    }

    func clearPeek() {
        peekTask?.cancel()
        peekTask = nil
        heldPeek = nil
        peekDeadline = nil
        if peek != nil { peek = nil }
        dropSecondPeek()
    }

    func dropSecondPeek() {
        secondDeadline = nil
        if secondPeek != nil { secondPeek = nil }
    }

    /// Each row goes after its own time; when the top one goes, the one under it moves up. Both
    /// stay while the pointer rests on the notification beside the notch (spec PV-39).
    private func runPeekTimer() {
        peekTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self else { return }
                guard self.peekHolders.isEmpty else { continue }
                let now = Date()
                if let deadline = self.secondDeadline, deadline <= now { self.dropSecondPeek() }
                guard let deadline = self.peekDeadline, deadline <= now else { continue }
                guard let second = self.secondPeek else {
                    self.peekTask = nil
                    self.peekDeadline = nil
                    self.peek = nil
                    return
                }
                self.peek = second
                self.peekDeadline = self.secondDeadline
                self.dropSecondPeek()
            }
        }
    }

    /// The row under the peek: an earlier notification, else the sticky notice, which so does not
    /// hide under the notification (spec E-28). None beside the notch.
    var peekSecondRow: PeekSecondRow? {
        guard peek != nil, !settings.noticesBeside else { return nil }
        if let secondPeek { return .notification(secondPeek) }
        return stickyNotice().map(PeekSecondRow.notice)
    }

    /// The notification whose card a hover opens: the one in the row under the pointer (spec E-28).
    /// `depth` is how far below the display's top edge the pointer is.
    func hoveredPeek(depth: CGFloat, in geometry: NotchGeometry) -> AppNotification? {
        guard let peek else { return nil }
        guard let row = peekSecondRow, depth > topPeekSize(in: geometry).height else { return peek }
        if case .notification(let second) = row { return second }
        return nil
    }
}

// MARK: - Holding the peek beside the notch (spec PV-39)

extension NotificationService {
    /// The pointer came onto or left the notification beside one display's notch. Leaving, the
    /// newest that came meanwhile shows; otherwise the shown one goes after its usual time.
    func holdPeek(_ held: Bool, by holder: ObjectIdentifier) {
        guard held != peekHolders.contains(holder) else { return }
        if held {
            peekHolders.insert(holder)
            return
        }
        peekHolders.remove(holder)
        guard peekHolders.isEmpty, let newer = heldPeek else { return }
        showPeek(newer)
    }
}
