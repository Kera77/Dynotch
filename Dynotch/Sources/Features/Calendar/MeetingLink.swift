import Foundation

/// Finds an online meeting link (Zoom, Google Meet, Teams, Webex) in an event's fields.
enum MeetingLink {
    /// - Parameters:
    ///   - url: the event's URL field.
    ///   - texts: location, notes etc., searched in order.
    static func find(url: URL?, texts: [String?]) -> URL? {
        if let url, let meeting = meetingURL(from: url) {
            return meeting
        }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            for candidate in links(in: text) {
                if let meeting = meetingURL(from: candidate) {
                    return meeting
                }
            }
        }
        return nil
    }

    static func meetingURL(from url: URL) -> URL? {
        let unwrapped = unwrapSafeLink(url)
        return isMeeting(unwrapped) ? unwrapped : nil
    }

    static func isMeeting(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "zoommtg" || scheme == "msteams" { return true }
        guard scheme == "https" || scheme == "http", let host = url.host?.lowercased() else { return false }
        let path = url.path.lowercased()

        if host == "zoom.us" || host.hasSuffix(".zoom.us") {
            return path.hasPrefix("/j/") || path.hasPrefix("/my/") || path.hasPrefix("/w/")
        }
        if host == "meet.google.com" {
            return path.range(of: #"^/[a-z]{3}-[a-z]{4}-[a-z]{3}"#, options: .regularExpression) != nil
        }
        if host == "teams.microsoft.com" {
            return path.contains("/l/meetup-join/") || path.contains("/meet/")
        }
        if host == "teams.live.com" {
            return path.hasPrefix("/meet/")
        }
        if host.hasSuffix(".webex.com") {
            return path.contains("/meet/") || path.contains("/j.php") || path.contains("/join/")
        }
        return false
    }

    /// Outlook "Safe Links" wrap the real URL in a `url` query parameter.
    private static func unwrapSafeLink(_ url: URL) -> URL {
        guard let host = url.host?.lowercased(), host.hasSuffix("safelinks.protection.outlook.com"),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let inner = items.first(where: { $0.name == "url" })?.value,
              let innerURL = URL(string: inner)
        else { return url }
        return innerURL
    }

    private static func links(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap(\.url)
    }
}
