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
        #expect(limits.map(\.title) == ["Session (5 hr)", "Weekly (7 day)", "Fable limit", "Opus limit"])
        #expect(limits[0].utilization == 69)
        #expect(limits[0].resetsAt != nil)
        #expect(limits[1].resetsAt == ClaudeUsageParser.date(from: "2026-11-17T09:00:00Z"))
        #expect(limits[3].resetsAt == nil)
    }

    @Test func parsesTheLimitsList() throws {
        let json = """
        {
          "five_hour": {"utilization": 10, "resets_at": "2026-11-16T14:30:00Z"},
          "limits": [
            {"group": "weekly", "is_active": false, "kind": "weekly_all", "percent": 51, "resets_at": "2026-11-17T09:00:00Z",
             "scope": null, "severity": "normal"},
            {"group": "weekly", "is_active": false, "kind": "weekly_scoped", "percent": 79,
             "resets_at": "2026-11-17T09:00:00Z", "scope": null, "severity": "warning"},
            {"group": "session", "is_active": true, "kind": "session", "percent": 69, "resets_at": "2026-11-16T14:30:00Z",
             "scope": null, "severity": "warning"}
          ]
        }
        """
        let limits = try ClaudeUsageParser.limits(from: Data(json.utf8))
        #expect(limits.map(\.title) == ["Session (5 hr)", "Weekly (7 day)", "Fable limit"])
        #expect(limits.map(\.utilization) == [69, 51, 79])
        #expect(limits[2].resetsAt == ClaudeUsageParser.date(from: "2026-11-17T09:00:00Z"))
    }

    @Test func limitTitles() {
        #expect(ClaudeUsageParser.title(kind: "five_hour", group: "") == "Session (5 hr)")
        #expect(ClaudeUsageParser.title(kind: "seven_day", group: "all") == "Weekly (7 day)")
        #expect(ClaudeUsageParser.title(kind: "session", group: "session") == "Session (5 hr)")
        #expect(ClaudeUsageParser.title(kind: "weekly_all", group: "weekly") == "Weekly (7 day)")
        #expect(ClaudeUsageParser.title(kind: "weekly_scoped", group: "weekly") == "Fable limit")
        #expect(ClaudeUsageParser.title(kind: "weekly_scoped", group: "weekly", scope: "claude_opus") == "Claude Opus limit")
        #expect(ClaudeUsageParser.title(kind: "seven_day_model", group: "fable") == "Fable limit")
        #expect(ClaudeUsageParser.title(kind: "model_weekly", group: "claude_opus") == "Claude Opus limit")
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
            UsageLimit(id: "five_hour", title: "Session", utilization: value, resetsAt: reset)
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
        #expect(UsageAlerts.resetText(now.addingTimeInterval(60), now: now, calendar: calendar).hasPrefix("today ")
            || UsageAlerts.resetText(now.addingTimeInterval(60), now: now, calendar: calendar).hasPrefix("tomorrow "))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        #expect(UsageAlerts.resetText(tomorrow, now: now, calendar: calendar).hasPrefix("tomorrow "))
    }

    /// Spec CL-6: hidden with the X until the fullest limit reaches its next 10 % or resets.
    @Test func dismissLastsUntilTheNextTenPercent() {
        let reset = Date(timeIntervalSince1970: 1_000_000)
        func limit(_ value: Double, reset: Date = reset) -> UsageLimit {
            UsageLimit(id: "five_hour", title: "Session", utilization: value, resetsAt: reset)
        }
        let marker = UsageAlerts.dismissMarker(for: limit(72))
        #expect(UsageAlerts.isDismissed(limit(72), marker: marker))
        #expect(UsageAlerts.isDismissed(limit(79.9), marker: marker))
        #expect(!UsageAlerts.isDismissed(limit(80), marker: marker))
        #expect(!UsageAlerts.isDismissed(limit(73, reset: Date(timeIntervalSince1970: 2_000_000)), marker: marker))
        #expect(!UsageAlerts.isDismissed(limit(72), marker: nil))
    }

    @Test func hoverText() {
        let limit = UsageLimit(id: "five_hour", title: "Session", utilization: 72.4, resetsAt: nil)
        #expect(NotchIndicatorView.usageText(for: limit, now: Date()) == "72% used · 28% left")
    }
}
