@testable import Dynotch
import Foundation
import Testing

struct ClaudeUsageTests {
    private let response = """
    {
      "five_hour": {"utilization": 69.0, "resets_at": "2026-11-16T14:30:00.123+00:00"},
      "seven_day": {"utilization": 51, "resets_at": "2026-11-17T09:00:00Z"},
      "seven_day_oauth_apps": null,
      "seven_day_opus": {"utilization": 12.5, "resets_at": null},
      "seven_day_fable": {"utilization": 79, "resets_at": "2026-11-17T09:00:00Z"},
      "extra_usage": {"is_enabled": false}
    }
    """

    @Test func parsesLimitsInDisplayOrder() throws {
        let limits = try ClaudeUsageParser.limits(from: Data(response.utf8))
        #expect(limits.map(\.id) == ["five_hour", "seven_day", "seven_day_fable", "seven_day_opus"])
        #expect(limits.map(\.title) == ["Munkamenet (5 óra)", "Heti (7 nap)", "Fable limit", "Opus limit"])
        #expect(limits[0].utilization == 69)
        #expect(limits[0].resetsAt != nil)
        #expect(limits[1].resetsAt == ClaudeUsageParser.date(from: "2026-11-17T09:00:00Z"))
        #expect(limits[3].resetsAt == nil)
    }

    @Test func rejectsNonObjects() {
        #expect(throws: (any Error).self) { try ClaudeUsageParser.limits(from: Data("[1,2]".utf8)) }
    }

    @Test func levels() {
        #expect(UsageLevel(utilization: 69.9) == .normal)
        #expect(UsageLevel(utilization: 70) == .high)
        #expect(UsageLevel(utilization: 90) == .critical)
    }

    /// Spec CL-5: from 70 %, again at every further 10 %, once per reset period.
    @Test func alertsAtEveryTenPercentFromSeventy() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        func limit(_ value: Double, reset: Date? = reset) -> UsageLimit {
            UsageLimit(id: "five_hour", title: "Munkamenet", utilization: value, resetsAt: reset)
        }
        var notified: [String: Int] = [:]
        for (value, expected) in [(65.0, 0), (71.0, 1), (78.0, 0), (80.0, 1), (95.0, 1), (99.0, 0), (100.0, 1), (100.0, 0)] {
            let result = UsageAlerts.alerts(for: [limit(value)], notified: notified)
            #expect(result.due.count == expected, "at \(value)%")
            notified = result.notified
        }
        // A new period (new reset time) starts over.
        let next = UsageAlerts.alerts(for: [limit(72, reset: Date(timeIntervalSince1970: 2_000_000))], notified: notified)
        #expect(next.due.count == 1)
    }

    @Test func credentialParsing() {
        let now = Date(timeIntervalSince1970: 1_000)
        let valid = #"{"claudeAiOauth":{"accessToken":"abc","expiresAt":2000000}}"#
        let expired = #"{"claudeAiOauth":{"accessToken":"abc","expiresAt":500000}}"#
        guard case .token(let token) = ClaudeCredential.parse(Data(valid.utf8), now: now) else {
            Issue.record("expected a token")
            return
        }
        #expect(token == "abc")
        guard case .expired = ClaudeCredential.parse(Data(expired.utf8), now: now) else {
            Issue.record("expected expired")
            return
        }
        guard case .missing = ClaudeCredential.parse(Data("{}".utf8), now: now) else {
            Issue.record("expected missing")
            return
        }
    }

    @Test func resetTexts() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = Date()
        #expect(UsageAlerts.resetText(now.addingTimeInterval(60), now: now, calendar: calendar).hasPrefix("ma ")
            || UsageAlerts.resetText(now.addingTimeInterval(60), now: now, calendar: calendar).hasPrefix("holnap "))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        #expect(UsageAlerts.resetText(tomorrow, now: now, calendar: calendar).hasPrefix("holnap "))
    }
}
