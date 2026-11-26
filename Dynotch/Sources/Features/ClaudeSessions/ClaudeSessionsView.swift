import SwiftUI

/// Claude Code's sessions, newest activity on top, as the AI module's Sessions tab (spec CS-1…CS-4).
struct ClaudeSessionsView: View {
    var service: ClaudeSessionService
    /// Brings the session's app (and project window) forward and closes the notch (spec CS-2).
    let open: (ClaudeSession) -> Void

    @State private var hooksInstalled = ClaudeQuestionHook.isInstalled()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Claude Code sessions")
                    .font(.notch(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if service.hasFinished {
                    Button("Clear finished") { withAnimation(.snappy) { service.clearFinished() } }
                        .buttonStyle(.notch)
                        .font(.notch(size: 11))
                        .foregroundStyle(Color.white.level(0.6))
                }
                MergedTabsPicker()
            }
            if service.sessions.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(service.sessions) { session in
                            ClaudeSessionRow(session: session)
                                .onTapGesture { open(session) }
                                .contextMenu {
                                    Button("Remove") { service.remove(session.id) }
                                }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.notch(size: 22))
                .foregroundStyle(Color.white.level(0.4))
            Text("No Claude Code sessions yet")
                .font(.notch(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text(hooksInstalled
                ? "They show up here as soon as one starts in Terminal, VS Code or the Claude app."
                : "Wingmate learns about sessions through Claude Code's hooks.")
                .font(.notch(size: 11))
                .foregroundStyle(Color.white.level(0.55))
                .multilineTextAlignment(.center)
            if !hooksInstalled {
                Button("Turn on") {
                    try? ClaudeQuestionHook.setInstalled(true)
                    hooksInstalled = ClaudeQuestionHook.isInstalled()
                }
                .buttonStyle(.notch)
                .font(.notch(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.blue))
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClaudeSessionRow: View {
    let session: ClaudeSession

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.project)
                        .font(.notch(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    ClaudeSessionStateCapsule(state: session.state)
                    Spacer(minLength: 4)
                    TimelineView(.everyMinute) { context in
                        Text(Self.elapsed(since: session.since, now: context.date))
                            .font(.notch(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(Color.white.level(0.5))
                    }
                }
                if let prompt = session.prompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.notch(size: 11))
                        .foregroundStyle(Color.white.level(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.fill))
        .contentShape(Rectangle())
    }

    @ViewBuilder private var icon: some View {
        if let app = session.app, let image = BadgeIconCache.appIcon(bundleID: app) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "terminal")
                .font(.notch(size: 14))
                .foregroundStyle(Color.white.level(0.6))
        }
    }

    /// "now", "12 min", "2 h 5 min".
    static func elapsed(since: Date, now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(since) / 60))
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes) min" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
    }
}

private struct ClaudeSessionStateCapsule: View {
    let state: ClaudeSession.State

    var body: some View {
        HStack(spacing: 3) {
            switch state {
            case .finished:
                Image(systemName: "checkmark").font(.notch(size: 8, weight: .bold))
            case .working:
                Image(systemName: "ellipsis").font(.notch(size: 9, weight: .bold))
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            default:
                EmptyView()
            }
            Text(state.title)
                .font(.notch(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(color)
        .background(Capsule().fill(color.opacity(0.18)))
        .fixedSize()
    }

    private var color: Color {
        switch state {
        case .working, .asks, .needsYou: .orange
        case .finished: .green
        case .ready, .background: Color.white.level(0.6)
        }
    }
}
