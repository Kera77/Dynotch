import SwiftUI

/// The running Claude Code sessions under the usage limits in the ring's hover (spec CS-6):
/// project, state and how long, at most four, then "+N more".
struct UsageSessionRows: View {
    /// The app the session runs in, else the terminal mark (spec CS-12).
    @ViewBuilder
    private func icon(_ session: ClaudeSession) -> some View {
        if let app = session.app, let image = BadgeIconCache.appIcon(bundleID: app) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "terminal")
                .font(.notch(size: 10))
                .foregroundStyle(Color.white.level(0.55))
        }
    }

    let sessions: [ClaudeSession]
    let now: Date
    /// A click brings the session's app forward with the project's window (spec CS-10).
    var open: (ClaudeSession) -> Void = { _ in }
    /// Resting on a row opens its details; leaving folds them (spec CS-13).
    var expand: (String?) -> Void = { _ in }

    @State private var hovered: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.white.level(0.12))
                .frame(height: 0.75)
                .padding(.bottom, 4)
            ForEach(sessions.prefix(IndicatorLayout.sessionRows)) { session in
                HStack(alignment: .top, spacing: 6) {
                    icon(session)
                        .frame(width: 14, height: 14)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
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
                        .frame(height: 18)
                        // The step, the answer or the task (spec CS-11); hovered, all of them (spec CS-13).
                        if session.isExpanded {
                            ForEach(session.expandedLines, id: \.title) { line in
                                expandedLine(line)
                            }
                        } else if let detail = session.detail {
                            Text(detail)
                                .font(.notch(size: 11))
                                .foregroundStyle(Color.white.level(0.55))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(height: 15)
                        }
                    }
                }
                .frame(height: IndicatorLayout.sessionRowHeight(session), alignment: .top)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                        .fill(hovered == session.id ? Theme.fill : .clear)
                )
                .padding(.horizontal, -4)
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside { hovered = session.id } else if hovered == session.id { hovered = nil }
                }
                .onTapGesture { open(session) }
                .help(session.app == nil ? "" : "Show this session")
                .accessibilityAddTraits(.isButton)
            }
            .task(id: hovered) { await settleExpansion() }
            .onDisappear { if sessions.contains(where: \.isExpanded) { expand(nil) } }
            if sessions.count > IndicatorLayout.sessionRows {
                Text("+\(sessions.count - IndicatorLayout.sessionRows) more")
                    .font(.notch(size: 11))
                    .foregroundStyle(Color.white.level(0.5))
                    .frame(height: IndicatorLayout.sessionRowHeight)
            }
        }
    }
}

extension UsageSessionRows {
    /// A short rest opens the hovered row; moving off folds it after a moment (spec CS-13).
    func settleExpansion() async {
        let expanded = sessions.first(where: \.isExpanded)?.id
        guard hovered != expanded else { return }
        try? await Task.sleep(for: .milliseconds(hovered == nil ? 250 : 400))
        guard !Task.isCancelled else { return }
        expand(hovered)
    }

    func expandedLine(_ line: ClaudeSession.DetailLine) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(line.title)
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.level(0.45))
                .frame(width: 44, alignment: .leading)
            Text(line.text)
                .font(.notch(size: 11))
                .foregroundStyle(Color.white.level(0.7))
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(height: IndicatorLayout.sessionLineHeight, alignment: .top)
    }
}

extension ClaudeSession {
    /// One labelled line of a hovered session (spec CS-13).
    struct DetailLine: Equatable {
        let title: String
        let text: String
    }

    /// The task, the step running now, the last answer and the app (spec CS-13).
    var expandedLines: [DetailLine] {
        let parts: [(String, String?)] = [
            ("Task", prompt), ("Now", state == .working || state == .background ? activity : nil), ("Answer", answer)
        ]
        let lines = parts.compactMap { title, text in
            text.flatMap { $0.isEmpty ? nil : DetailLine(title: title, text: $0) }
        }
        return lines.isEmpty ? [DetailLine(title: "State", text: state.title)] : lines
    }
}

extension IndicatorLayout {
    /// A hovered session's labelled line: up to two lines of text (spec CS-13).
    static let sessionLineHeight: CGFloat = 29

    /// The running sessions under the usage limits (spec CS-6): at most this many rows.
    static let sessionRows = 4
    static let sessionRowHeight: CGFloat = 20
    /// With the step, answer or task under it: two lines (spec CS-11).
    static let sessionDetailRowHeight: CGFloat = 36

    static func sessionRowHeight(_ session: ClaudeSession) -> CGFloat {
        if session.isExpanded { return 21 + CGFloat(session.expandedLines.count) * sessionLineHeight }
        return session.detail == nil ? sessionRowHeight : sessionDetailRowHeight
    }

    /// The limits, then the sessions (spec CL-6, CS-6).
    static func usageLabelHeight(_ limits: [UsageLimit], _ sessions: [ClaudeSession]) -> CGFloat {
        CGFloat(limits.isEmpty ? 4 : 12 + limits.count * 20) + sessionRowsHeight(sessions)
    }

    static func sessionRowsHeight(_ sessions: [ClaudeSession]) -> CGFloat {
        guard !sessions.isEmpty else { return 0 }
        let more = sessions.count > sessionRows ? 1 : 0
        return 8 + sessions.prefix(sessionRows).reduce(0) { $0 + sessionRowHeight($1) } + CGFloat(more) * sessionRowHeight
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
                    UsageSessionRows(sessions: sessions, now: now, open: openSession, expand: expandSession)
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
