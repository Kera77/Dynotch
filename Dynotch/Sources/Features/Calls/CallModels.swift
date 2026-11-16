import Foundation

/// A ringing call, as read from the macOS call banner (spec P-1).
struct IncomingCall: Equatable, Sendable {
    /// The process that shows the banner.
    let pid: pid_t
    /// Name or number of the caller.
    var caller: String
    /// E.g. "from iPhone".
    var detail: String
}

/// What Contacts knows about the caller (spec P-1b).
struct CallerContact: Equatable, Sendable {
    var name: String?
    var number: String?
    var imageData: Data?
}

enum CallAction: Sendable {
    case accept
    case decline
}

/// Recognises the call banner's buttons and texts (spec P-1, P-2).
enum CallMatcher {
    static let unknownCaller = "Incoming call"

    /// Labels of the answer button, English and Hungarian.
    static let acceptWords = ["accept", "answer", "fogadás", "felvétel", "válaszol"]
    static let declineWords = ["decline", "reject", "elutasít"]

    static func action(forLabel label: String) -> CallAction? {
        let text = label.precomposedStringWithCanonicalMapping.lowercased()
        // "Decline" first: no accept word is part of a decline label, but be strict anyway.
        if declineWords.contains(where: text.contains) { return .decline }
        if acceptWords.contains(where: text.contains) { return .accept }
        return nil
    }

    /// At least six digits, and nothing but digits and phone punctuation.
    static func isPhoneNumber(_ text: String) -> Bool {
        let allowed = Set("+0123456789 ()-/.")
        let digits = text.filter(\.isNumber).count
        return digits >= 6 && text.allSatisfy(allowed.contains)
    }

    /// Splits the banner's texts into the caller and the line saying where the call comes from.
    static func describe(texts: [String]) -> (caller: String, detail: String) {
        var seen = Set<String>()
        let lines = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && action(forLabel: $0) == nil && !isChrome($0) && seen.insert($0).inserted }
        let detailWords = ["from ", "iphone", "facetime", "mobile", "audio", "video", "call", "hívás"]
        let detail = lines.first { line in
            !isPhoneNumber(line) && detailWords.contains(where: line.lowercased().contains)
        }
        let caller = lines.first { $0 != detail }
        return (caller ?? unknownCaller, detail ?? "")
    }

    /// Names of the banner's own parts, not of the caller: "Notification Center",
    /// "FaceTime Notification".
    static func isChrome(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered == "notification center" || lowered.hasSuffix("notification") || lowered == "facetime"
            || lowered == "értesítési központ" || lowered.hasSuffix("értesítés")
    }

    /// Up to two letters for the round picture.
    static func initials(of caller: String) -> String {
        guard !isPhoneNumber(caller) else { return "" }
        return caller.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
