import Foundation

/// Typed emoticons become emoji, as in chat apps: ":D" → 😄 (spec E-18). Only words that are an
/// emoticon on their own change, so links ("https://") and times ("12:30") stay as they are.
enum Emoticons {
    static let table: [String: String] = [
        ":)": "🙂", ":-)": "🙂", ":D": "😄", ":-D": "😄", "xD": "😆", "XD": "😆",
        ":(": "🙁", ":-(": "🙁", ":'(": "😢", ";)": "😉", ";-)": "😉",
        ":P": "😛", ":p": "😛", ":-P": "😛", ":O": "😮", ":o": "😮", ":*": "😘",
        "<3": "❤️", ":|": "😐", "B-)": "😎", "^^": "😊", ":/": "😕"
    ]

    /// - Parameter includingLast: also the word at the very end (when sending); while typing a
    ///   word changes only once a space follows it.
    static func replace(in text: String, includingLast: Bool) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\S+"#) else { return text }
        let source = text as NSString
        var result = text as NSString
        // Backwards, so earlier ranges stay valid.
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed() {
            let word = source.substring(with: match.range)
            guard let emoji = table[word] else { continue }
            let isLast = NSMaxRange(match.range) == source.length
            guard includingLast || !isLast else { continue }
            result = result.replacingCharacters(in: match.range, with: emoji) as NSString
        }
        return result as String
    }
}
