import SwiftUI

/// Usage like Claude's own usage screen (spec CL-3).
struct ClaudeUsageView: View {
    @ObservedObject var service: ClaudeUsageService
    let isActive: Bool

    static let blue = Color(red: 0.04, green: 0.52, blue: 1)

    var body: some View {
        Group {
            switch service.state {
            case .loaded:
                list
            case .idle, .loading:
                message("Loading usage…", showsProgress: true)
            case .noCredentials:
                message("No Claude Code login found, or keychain access was denied.\n"
                    + "Sign in to Claude Code, then refresh.", showsRetry: true)
            case .signedOut:
                message("The Claude Code token expired. Use Claude Code once (it renews it), then refresh.",
                        showsRetry: true)
            case .failed(let error):
                message("Couldn't load usage: \(error)", showsRetry: true)
            }
        }
        .onAppear { if isActive { service.refreshIfStale() } }
        .onChange(of: isActive) { _, active in
            if active { service.refreshIfStale() }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("USAGE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45))
                Spacer()
                if let updated = service.lastUpdated {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                Button(action: service.refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(service.limits) { UsageRow(limit: $0) }
                }
            }
            .scrollIndicators(.never)
        }
    }

    private func message(_ text: String, showsProgress: Bool = false, showsRetry: Bool = false) -> some View {
        VStack(spacing: 10) {
            if showsProgress { ProgressView().controlSize(.small) }
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if showsRetry {
                Button("Refresh", action: service.refresh)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct UsageRow: View {
    let limit: UsageLimit

    private var color: Color {
        switch limit.level {
        case .normal: ClaudeUsageView.blue
        case .high: Color(red: 1, green: 0.62, blue: 0.1)
        case .critical: Color(red: 1, green: 0.3, blue: 0.3)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(limit.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(limit.utilization.rounded()))%")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(limit.level == .normal ? Color.white : color)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * limit.utilization / 100)
                }
            }
            .frame(height: 6)
            if let reset = limit.resetsAt {
                Text("Resets \(UsageAlerts.resetText(reset, now: Date()))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
    }
}

/// Claude usage in the notch.
struct ClaudeUsageFeatureView: View {
    @ObservedObject var service: ClaudeUsageService
    let isActive: Bool

    var body: some View {
        ClaudeUsageView(service: service, isActive: isActive)
            .padding(.top, 6)
    }
}

/// Content of the Claude usage menu bar panel.
struct ClaudeUsageMenuBarView: View {
    @ObservedObject var service: ClaudeUsageService
    @ObservedObject var state: MenuBarPanelState

    var body: some View {
        ClaudeUsageView(service: service, isActive: true)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .popoverChrome(arrowX: state.arrowX)
    }
}
