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

    /// The page's height under the notch, for the panel's size (spec WN-6); a paged release
    /// is as tall as its longest section (spec WN-9).
    static func height(for releases: [WhatsNewRelease]) -> CGFloat {
        if let paged = releases.first(where: \.isPaged) {
            return chrome + WhatsNewPagedView.sectionHeader + CGFloat(paged.sections.map(\.items.count).max() ?? 0) * rowHeight
        }
        let rows = releases.reduce(0) { $0 + $1.items.count }
        let headers = releases.count > 1 ? CGFloat(releases.count) * 20 : 0
        return chrome + CGFloat(rows) * rowHeight + headers
    }

    var body: some View {
        if let paged = releases.first(where: \.isPaged) {
            WhatsNewPagedView(release: paged, notchHeight: notchHeight, done: done)
        } else {
            list
        }
    }

    private var list: some View {
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

/// A public release's news, one module per page: Back and Next step through them, Skip leaves
/// the rest, Got it on the last page (spec WN-9).
struct WhatsNewPagedView: View {
    let release: WhatsNewRelease
    let notchHeight: CGFloat
    let done: () -> Void
    @State private var page = 0

    static let sectionHeader: CGFloat = 30

    private var section: WhatsNewSection { release.sections[min(page, release.sections.count - 1)] }
    private var isLast: Bool { page >= release.sections.count - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.blue)
                    .accessibilityHidden(true)
                Text("What's new in Wingmate \(Self.shortVersion(release.version))")
                    .font(.notch(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            HStack(spacing: 7) {
                Image(systemName: section.symbol)
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                    .frame(width: 18)
                Text(section.title)
                    .font(.notch(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(page + 1) of \(release.sections.count)")
                    .font(.notch(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.level(0.5))
            }
            .frame(height: Self.sectionHeader - 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(section.items, id: \.self) { item in
                        OnboardingRow(symbol: item.symbol, title: item.title, text: item.text)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(page)
                .transition(.opacity)
            }
            .scrollIndicators(.automatic)
            .scrollBounceBehavior(.basedOnSize)
            buttons
        }
        .padding(.horizontal, 24)
        .padding(.top, notchHeight + 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            // Ignores the rest: counts as seen, like Got it (spec WN-9).
            Button("Skip") {
                DiagnosticsLog.append("onboarding", "whats new skipped at page \(page + 1) of \(release.sections.count)")
                done()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .opacity(isLast ? 0 : 1)
            .disabled(isLast)
            Spacer()
            if page > 0 {
                Button("Back") { step(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
            if isLast {
                Button("Got it", action: done)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            } else {
                Button("Next") { step(1) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
        }
    }

    private func step(_ delta: Int) {
        withAnimation(Motion.quick) { page = min(max(page + delta, 0), release.sections.count - 1) }
    }

    /// "1.8" for 1.8.0.
    nonisolated static func shortVersion(_ version: String) -> String {
        version.hasSuffix(".0") ? String(version.dropLast(2)) : version
    }
}
