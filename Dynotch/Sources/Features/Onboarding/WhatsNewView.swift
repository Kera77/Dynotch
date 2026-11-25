import AppKit
import SwiftUI

/// After an update, puts the What's new notice under the notch (spec WN-6…WN-8).
@MainActor
enum WhatsNewAnnouncer {
    static func showIfNeeded(settings: AppSettings, notices: NoticeService, alertsOn: @escaping () -> Bool) {
        let progress = WhatsNewProgress(defaults: settings.defaults)
        let current = AppInfo.version
        let tourDone = OnboardingProgress(defaults: settings.defaults).isCompleted
        guard let releases = WhatsNew.card(last: progress.lastVersion, current: current, tourDone: tourDone) else {
            // A first install gets the tour; its version counts as seen (spec WN-2).
            if !tourDone { progress.markSeen(current) }
            return
        }
        show(releases, notices: notices, alertsOn: alertsOn, progress: progress, after: 2)
    }

    /// Waits out the tour (spec WN-2); the notice itself waits for nothing else.
    private static func show(
        _ releases: [WhatsNewRelease], notices: NoticeService, alertsOn: @escaping () -> Bool,
        progress: WhatsNewProgress, after delay: TimeInterval
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            MainActor.assumeIsolated {
                if OnboardingController.isRunning {
                    show(releases, notices: notices, alertsOn: alertsOn, progress: progress, after: 2)
                    return
                }
                // The Dynotch updated alerts are off: nothing pops up, the version counts as seen (spec WN-8).
                guard alertsOn() else {
                    progress.markSeen(AppInfo.version)
                    return
                }
                DiagnosticsLog.append("onboarding", "whats new notice for \(releases.map(\.version).joined(separator: ", "))")
                notices.show(StickyNotice(
                    title: "Wingmate updated", detail: "Version \(AppInfo.version) · hover for what's new", date: Date(),
                    symbol: "sparkles", whatsNew: releases
                ))
            }
        }
    }
}

/// What's new in the open notch: per version a few lines, newest first, and Got it (spec WN-6).
struct WhatsNewPage: View {
    let releases: [WhatsNewRelease]
    let notchHeight: CGFloat
    let done: () -> Void

    static let rowHeight: CGFloat = 44
    private static let chrome: CGFloat = 104

    /// The page's height under the notch, for the panel's size (spec WN-6).
    static func height(for releases: [WhatsNewRelease]) -> CGFloat {
        let rows = releases.reduce(0) { $0 + $1.items.count }
        let headers = releases.count > 1 ? CGFloat(releases.count) * 20 : 0
        return chrome + CGFloat(rows) * rowHeight + headers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.blue)
                    .accessibilityHidden(true)
                Text("What's new in Wingmate \(releases.first?.version ?? AppInfo.version)")
                    .font(.notch(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(releases, id: \.version) { release in
                        if releases.count > 1 {
                            Text(release.version)
                                .font(.notch(size: 11, weight: .semibold))
                                .foregroundStyle(Color.white.level(0.5))
                        }
                        ForEach(release.items, id: \.self) { item in
                            OnboardingRow(symbol: item.symbol, title: item.title, text: item.text)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
            .scrollBounceBehavior(.basedOnSize)
            HStack {
                Spacer()
                Button("Got it", action: done)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, notchHeight + 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
