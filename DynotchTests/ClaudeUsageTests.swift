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

    private func limit(_ value: Double, reset: Date? = Date(timeIntervalSince1970: 1_000_000), id: String = "session") -> UsageLimit {
        UsageLimit(id: id, title: "Session (5 hr)", utilization: value, resetsAt: reset)
    }

    /// Spec CL-5: from 70 %, again at every further 10 %, once per period; a moving reset time
    /// does not start a new period (it used to, so "limit reached" came every hour).
    @Test func alertsOnlyWhenANewStepIsReached() {
        var state: [String: UsageAlertState] = [:]
        let now = Date(timeIntervalSince1970: 900_000)
        var resetTime = 1_000_000.0
        for (value, expected) in [(65.0, 0), (71.0, 1), (78.0, 0), (80.0, 1), (95.0, 1), (99.0, 0), (100.0, 1), (100.0, 0), (100.0, 0)] {
            resetTime += 3600 // the reset time moves on every look
            let result = UsageAlerts.evaluate([limit(value, reset: Date(timeIntervalSince1970: resetTime))], state: state, now: now)
            #expect(result.due.count == expected, "at \(value)%")
            #expect(result.reset.isEmpty, "at \(value)%")
            state = result.state
        }
    }

    /// Spec CL-5b: the session reset is noticed when its reset time passes or usage drops.
    @Test func sessionResetIsDetected() {
        let first = UsageAlerts.evaluate([limit(85)], state: [:], now: Date(timeIntervalSince1970: 900_000))
        #expect(first.reset.isEmpty)
        #expect(first.due.count == 1)

        let afterResetTime = UsageAlerts.evaluate(
            [limit(3, reset: Date(timeIntervalSince1970: 1_018_000))], state: first.state, now: Date(timeIntervalSince1970: 1_000_100)
        )
        #expect(afterResetTime.reset.count == 1)
        #expect(afterResetTime.state["session"]?.bucket == 0)

        let dropped = UsageAlerts.evaluate([limit(40)], state: first.state, now: Date(timeIntervalSince1970: 900_100))
        #expect(dropped.reset.count == 1)

        // New period: 70 % warns again.
        let again = UsageAlerts.evaluate([limit(72)], state: afterResetTime.state, now: Date(timeIntervalSince1970: 1_000_200))
        #expect(again.due.count == 1)
    }

    @Test func credentialParsing() {
        let now = Date(timeIntervalSince1970: 1_000)
        let valid = #"{"claudeAiOauth":{"accessToken":"abc","expiresAt":2000000}}"#
        let expired = #"{"claudeAiOauth":{"accessToken":"abc","expiresAt":500000}}"#
        guard case .token(let token, let expires) = ClaudeCredential.parse(Data(valid.utf8), now: now) else {
            Issue.record("expected a token")
            return
        }
        #expect(token == "abc")
        #expect(expires == Date(timeIntervalSince1970: 2_000))
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
        let marker = UsageAlerts.dismissMarker(for: limit(72))
        #expect(UsageAlerts.isDismissed(limit(72, reset: Date(timeIntervalSince1970: 1_003_600)), marker: marker))
        #expect(UsageAlerts.isDismissed(limit(79.9), marker: marker))
        #expect(!UsageAlerts.isDismissed(limit(80), marker: marker))
        #expect(!UsageAlerts.isDismissed(limit(5), marker: marker))
        #expect(!UsageAlerts.isDismissed(limit(72, id: "weekly"), marker: marker))
        #expect(!UsageAlerts.isDismissed(limit(72), marker: nil))
    }

    @Test func hoverText() {
        let limit = UsageLimit(id: "five_hour", title: "Session", utilization: 72.4, resetsAt: nil)
        #expect(NotchIndicatorView.usageText(for: limit, now: Date()) == "72% used · 28% left")
    }

    /// Spec CL-6: only the session limit, only from 70 %.
    @Test @MainActor func notchShowsOnlyTheSessionFromSeventyPercent() {
        let defaults = UserDefaults(suiteName: "DynotchTests-\(UUID().uuidString)") ?? .standard
        let service = ClaudeUsageService(settings: AppSettings(defaults: defaults)) { _, _ in }
        let weekly = UsageLimit(id: "weekly", title: "Weekly (7 day)", utilization: 95, resetsAt: nil)
        service.setLoadedState([UsageLimit(id: "session", title: "Session (5 hr)", utilization: 60, resetsAt: nil), weekly])
        #expect(service.notchLimits == nil)
        service.setLoadedState([UsageLimit(id: "session", title: "Session (5 hr)", utilization: 74, resetsAt: nil), weekly])
        #expect(service.notchLimits?.map(\.id) == ["session"])
    }
}
