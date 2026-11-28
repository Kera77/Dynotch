import Foundation

/// The pointer rests on a pop-up that goes by itself (a notification, a device, a screenshot,
/// a timed notice): it stays while the pointer is on it, and goes at the earliest 3 s after the
/// pointer left (spec E-36). Every display's notch reports where its pointer is.
@MainActor
final class PeekHover {
    static let shared = PeekHover()

    enum Kind: Hashable, CaseIterable {
        case notification, device, screenshot, notice
    }

    /// How long a pop-up stays after the pointer left it.
    static let linger: TimeInterval = 3

    private var holders: [Kind: Set<ObjectIdentifier>] = [:]
    private var leftAt: [Kind: Date] = [:]

    func set(_ kind: Kind, _ isOn: Bool, by holder: ObjectIdentifier, now: Date = Date()) {
        var current = holders[kind, default: []]
        let wasHeld = !current.isEmpty
        if isOn { current.insert(holder) } else { current.remove(holder) }
        holders[kind] = current
        if wasHeld, current.isEmpty { leftAt[kind] = now }
    }

    func isHeld(_ kind: Kind) -> Bool {
        !(holders[kind]?.isEmpty ?? true)
    }

    /// Not under the pointer, and not left less than `linger` ago.
    func mayGo(_ kind: Kind, now: Date = Date()) -> Bool {
        guard !isHeld(kind) else { return false }
        guard let left = leftAt[kind] else { return true }
        return now.timeIntervalSince(left) >= Self.linger
    }

    /// Waits the pop-up's own time, then as long as the pointer holds it, plus `linger`.
    func wait(_ kind: Kind, seconds: TimeInterval) async {
        try? await Task.sleep(for: .seconds(seconds))
        while !Task.isCancelled, !mayGo(kind) {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}

extension NotchController {
    /// Tells which timed pop-up this notch's pointer rests on (spec E-36).
    func updatePeekHover(at point: CGPoint) {
        let hover = PeekHover.shared
        let id = ObjectIdentifier(self)
        let closed = !model.isExpanded
        let onNotification = closed && notifications.peek != nil
            && (settings.noticesBeside ? wingsPeekZone.contains(point) : isOverNotificationPeek)
        hover.set(.notification, onNotification, by: id)
        hover.set(.device, closed && devices.current != nil && devicePeekZone.contains(point), by: id)
        hover.set(.screenshot, closed && screenshots.peek != nil
            && model.geometry.keepOpenZone(for: model.geometry.peekSize).contains(point), by: id)
        let timedNotice = notices.notice.map { $0.stays != nil || $0.download != nil } ?? false
        hover.set(.notice, closed && timedNotice && isOverNotice, by: id)
    }
}
