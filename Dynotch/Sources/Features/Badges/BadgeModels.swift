import CoreGraphics
import Foundation

/// What stands for an app beside the notch (spec B-3).
enum BadgeIcon: Codable, Equatable, Sendable {
    /// The app's own icon.
    case app
    /// An SF Symbol, or `BadgePreset.claudeSymbol`.
    case symbol(String)
    /// An image the user chose; the file name inside the badge icon folder.
    case custom(String)
}

/// An app whose unread count is shown beside the notch (spec B-1).
struct BadgeApp: Codable, Identifiable, Equatable, Sendable {
    let bundleID: String
    var name: String
    var isEnabled: Bool
    var icon: BadgeIcon

    var id: String { bundleID }
}

/// The built-in icons to choose from (spec B-3).
struct BadgePreset: Identifiable, Equatable, Sendable {
    let symbol: String
    let title: String

    var id: String { symbol }

    /// Drawn by `BrandGlyphShape`; not an SF Symbol.
    static let claudeSymbol = BrandGlyph.claude.rawValue

    /// The symbol shown in menus, where only SF Symbols can be used.
    var menuSymbol: String { BrandGlyph(rawValue: symbol)?.menuSymbol ?? symbol }

    static let all: [BadgePreset] = [
        BadgePreset(symbol: "bubble.left.fill", title: "Chat"),
        BadgePreset(symbol: "envelope.fill", title: "Mail"),
        BadgePreset(symbol: "bell.fill", title: "Bell"),
        BadgePreset(symbol: "phone.fill", title: "Phone"),
        BadgePreset(symbol: "video.fill", title: "Video"),
        BadgePreset(symbol: "calendar", title: "Calendar"),
        BadgePreset(symbol: "checkmark.circle.fill", title: "Tasks"),
        BadgePreset(symbol: "person.2.fill", title: "People"),
        BadgePreset(symbol: "globe", title: "Web"),
        BadgePreset(symbol: "chevron.left.forwardslash.chevron.right", title: "Code"),
        BadgePreset(symbol: "music.note", title: "Music"),
        BadgePreset(symbol: "star.fill", title: "Star"),
        BadgePreset(symbol: claudeSymbol, title: "Claude"),
        BadgePreset(symbol: BrandGlyph.beeper.rawValue, title: "Beeper"),
        BadgePreset(symbol: BrandGlyph.googleChat.rawValue, title: "Google Chat"),
        BadgePreset(symbol: BrandGlyph.gmail.rawValue, title: "Gmail")
    ]

    private static let chatWords = [
        "beeper", "slack", "whatsapp", "telegram", "discord", "teams", "signal", "messenger", "messages", "ichat", "chat"
    ]
    private static let mailWords = ["mail", "outlook", "spark", "airmail", "mimestream"]

    /// The icon a newly added app starts with: a glyph for well-known kinds, else its own icon.
    static func suggestedIcon(bundleID: String, name: String) -> BadgeIcon {
        let words = (bundleID + " " + name).lowercased()
        if words.contains("claude") || words.contains("anthropic") { return .symbol(claudeSymbol) }
        if words.contains("beeper") { return .symbol(BrandGlyph.beeper.rawValue) }
        if words.contains("google chat") { return .symbol(BrandGlyph.googleChat.rawValue) }
        if words.contains("gmail") { return .symbol(BrandGlyph.gmail.rawValue) }
        if mailWords.contains(where: words.contains) { return .symbol("envelope.fill") }
        if chatWords.contains(where: words.contains) { return .symbol("bubble.left.fill") }
        return .app
    }
}

/// An app with unread notifications, as drawn beside the notch (spec B-4).
struct BadgeItem: Identifiable, Equatable, Sendable {
    static let iconSize: CGFloat = 16
    static let gap: CGFloat = 3
    static let characterWidth: CGFloat = 7

    let app: BadgeApp
    /// The Dock badge's text, usually a number.
    let label: String
    /// When the last new notification arrived; the icon pulses for a while after it.
    let pulseStart: Date?

    var id: String { app.bundleID }

    var text: String { BadgeTracker.displayText(label) }

    /// Width of the icon with its number.
    var width: CGFloat { Self.width(text: text) }

    static func width(text: String) -> CGFloat {
        iconSize + gap + CGFloat(max(text.count, 1)) * characterWidth
    }
}

/// Decides when a badge counts as new (spec B-5).
enum BadgeTracker {
    /// How long an icon pulses after a new notification.
    static let pulseDuration: TimeInterval = 300

    static func count(_ label: String) -> Int? {
        Int(label.trimmingCharacters(in: .whitespaces))
    }

    /// At most three characters: "7", "42", "99+".
    static func displayText(_ label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        if let count = count(trimmed) { return count > 99 ? "99+" : String(count) }
        return String(trimmed.prefix(3))
    }

    /// A badge appeared, or its number grew.
    static func isNew(previous: String?, current: String) -> Bool {
        guard !current.isEmpty else { return false }
        guard let previous, !previous.isEmpty else { return true }
        if let old = count(previous), let new = count(current) { return new > old }
        return previous != current
    }

    /// The pulse start of every app after a new reading: restarted by a new notification, dropped
    /// when the badge is gone.
    static func pulses(
        _ pulses: [String: Date], previous: [String: String], current: [String: String], now: Date
    ) -> [String: Date] {
        var result: [String: Date] = [:]
        for (id, label) in current where !label.isEmpty {
            if isNew(previous: previous[id], current: label) {
                result[id] = now
            } else if let start = pulses[id], isPulsing(since: start, now: now) {
                result[id] = start
            }
        }
        return result
    }

    /// Apps added before the brand marks existed got a generic glyph; they get their own mark.
    static func upgradedIcon(for app: BadgeApp) -> BadgeIcon {
        let generic: [BadgeIcon] = [.symbol("bubble.left.fill"), .symbol("envelope.fill")]
        guard generic.contains(app.icon),
              case .symbol(let name) = BadgePreset.suggestedIcon(bundleID: app.bundleID, name: app.name),
              BrandGlyph(rawValue: name) != nil
        else { return app.icon }
        return .symbol(name)
    }

    static func isPulsing(since start: Date?, now: Date) -> Bool {
        guard let start else { return false }
        let elapsed = now.timeIntervalSince(start)
        return elapsed >= 0 && elapsed < pulseDuration
    }
}

/// Dragging a badge to a new place among badges of different widths (spec B-7).
enum BadgeReorder {
    /// Where the dragged badge lands: as many places from the left as there are other badges
    /// whose centre is left of its centre.
    static func targetIndex(widths: [CGFloat], from: Int, offset: CGFloat, spacing: CGFloat) -> Int {
        guard widths.indices.contains(from) else { return from }
        func center(_ index: Int) -> CGFloat {
            widths.prefix(index).reduce(0, +) + CGFloat(index) * spacing + widths[index] / 2
        }
        let dragged = center(from) + offset
        return widths.indices.filter { $0 != from && center($0) < dragged }.count
    }

    /// How far a badge moves aside while another one is dragged over its place.
    static func shift(of index: Int, from: Int, target: Int, draggedWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let step = draggedWidth + spacing
        if target > from, index > from, index <= target { return -step }
        if target < from, index >= target, index < from { return step }
        return 0
    }

    /// `ids` with one moved to `index`.
    static func moved(_ ids: [String], id: String, to index: Int) -> [String] {
        var result = ids
        guard let from = result.firstIndex(of: id) else { return ids }
        result.remove(at: from)
        result.insert(id, at: min(max(index, 0), result.count))
        return result
    }
}
