import SwiftUI

/// The running Claude Code sessions under the usage limits in the ring's hover (spec CS-6):
/// project, state and how long, at most four, then "+N more".
struct UsageSessionRows: View {
    let sessions: [ClaudeSession]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.white.level(0.12))
                .frame(height: 0.75)
                .padding(.bottom, 4)
            ForEach(sessions.prefix(IndicatorLayout.sessionRows)) { session in
                HStack(spacing: 6) {
                    Image(systemName: "terminal")
                        .font(.notch(size: 10))
                        .foregroundStyle(Color.white.level(0.55))
                    Text(session.project)
                        .font(.notch(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    ClaudeSessionStateCapsule(state: session.state)
                    Spacer(minLength: 8)
                    Text(ClaudeSessionRow.elapsed(since: session.since, now: now))
                        .font(.notch(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.level(0.5))
                }
                .frame(height: IndicatorLayout.sessionRowHeight)
            }
            if sessions.count > IndicatorLayout.sessionRows {
                Text("+\(sessions.count - IndicatorLayout.sessionRows) more")
                    .font(.notch(size: 11))
                    .foregroundStyle(Color.white.level(0.5))
                    .frame(height: IndicatorLayout.sessionRowHeight)
            }
        }
    }
}

extension IndicatorLayout {
    /// The running sessions under the usage limits (spec CS-6): at most this many rows.
    static let sessionRows = 4
    static let sessionRowHeight: CGFloat = 20

    /// The limits, then the sessions (spec CL-6, CS-6).
    static func usageLabelHeight(_ limits: [UsageLimit], _ sessions: [ClaudeSession]) -> CGFloat {
        CGFloat(limits.isEmpty ? 4 : 12 + limits.count * 20) + sessionRowsHeight(sessions)
    }

    static func sessionRowsHeight(_ sessions: [ClaudeSession]) -> CGFloat {
        guard !sessions.isEmpty else { return 0 }
        let more = sessions.count > sessionRows ? 1 : 0
        return 8 + CGFloat(min(sessions.count, sessionRows) + more) * sessionRowHeight
    }
}

extension NotchIndicatorView {
    /// Every usage limit: used, left, and when it resets (spec CL-6).
    /// The running Claude Code sessions under them (spec CS-6).
    func usageLabel(for limits: [UsageLimit], sessions: [ClaudeSession], now: Date) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(limits) { limit in
                    HStack(spacing: 6) {
                        Text(limit.account.map { "\($0) · \(limit.title)" } ?? limit.title)
                            .font(.notch(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(Self.usageText(for: limit, now: now))
                            .font(.notch(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(Self.color(for: limit.level))
                            .lineLimit(1)
                    }
                    .frame(height: 16)
                }
                if !sessions.isEmpty {
                    UsageSessionRows(sessions: sessions, now: now)
                        .padding(.top, limits.isEmpty ? 0 : 4)
                }
            }
            dismissButton(
                for: .usage(limits),
                help: usagePopup ? "Hide until the next session starts" : "Hide until usage reaches the next 10%"
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    static func usageText(for limit: UsageLimit, now: Date) -> String {
        let used = Int(limit.utilization.rounded())
        let reset = limit.resetsAt.map { " · resets " + UsageAlerts.resetText($0, now: now) } ?? ""
        return "\(used)% used · \(100 - used)% left\(reset)"
    }

}
