import AppKit
import SwiftUI

/// Shows What's new once after an update, on a card like the tour's (spec WN-1…WN-5).
@MainActor
final class WhatsNewController {
    private let settings: AppSettings
    private let progress: WhatsNewProgress
    private let notchModels: () -> [NotchViewModel]
    private var panel: CardPanel?
    private var keyMonitor: Any?
    /// Kept alive while it waits and shows.
    private static var current: WhatsNewController?

    init(settings: AppSettings, notchModels: @escaping () -> [NotchViewModel]) {
        self.settings = settings
        self.progress = WhatsNewProgress(defaults: settings.defaults)
        self.notchModels = notchModels
    }

    func showIfNeeded() {
        let current = AppInfo.version
        let tourDone = OnboardingProgress(defaults: settings.defaults).isCompleted
        let due = WhatsNew.due(last: progress.lastVersion, current: current, tourDone: tourDone)
        progress.markSeen(current)
        guard !due.isEmpty else { return }
        Self.current = self
        showWhenClear(due, after: 2)
    }

    /// Waits out screen sharing, full screen, Mission Control and the tour (spec WN-2).
    private func showWhenClear(_ releases: [WhatsNewRelease], after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let busy = OnboardingController.isRunning || self.notchModels().contains {
                    $0.isScreenShared || $0.isHiddenForFullScreen || $0.isHiddenForMissionControl
                }
                if busy { self.showWhenClear(releases, after: 1) } else { self.show(releases) }
            }
        }
    }

    private func show(_ releases: [WhatsNewRelease]) {
        DiagnosticsLog.append("onboarding", "whats new shown for \(releases.map(\.version).joined(separator: ", "))")
        let view = WhatsNewView(
            releases: releases, design: settings.design,
            onSize: { [weak self] in self?.panel?.fit($0) }, onDone: { [weak self] in self?.close() }
        )
        panel = CardPanel(rootView: view)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let handled = MainActor.assumeIsolated {
                guard event.window === self.panel, event.keyCode == 53 else { return false }
                self.close()
                return true
            }
            return handled ? nil : event
        }
    }

    private func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel?.dismiss()
        panel = nil
        Self.current = nil
    }
}

/// The What's new card: per version a few lines, newest first, and Got it (spec WN-1).
struct WhatsNewView: View {
    let releases: [WhatsNewRelease]
    let design: NotchDesign
    let onSize: (CGSize) -> Void
    let onDone: () -> Void

    var body: some View {
        CardContainer(design: design, onSize: onSize) {
            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Theme.blue)
                        .accessibilityHidden(true)
                    Text("What's new in Wingmate \(releases.first?.version ?? AppInfo.version)")
                        .font(.title3.weight(.semibold))
                }
                FittingScroll(maxHeight: CardPanel.maxHeight - 170) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(releases, id: \.version) { release in
                            if releases.count > 1 {
                                Text(release.version).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            ForEach(release.items, id: \.self) { item in
                                OnboardingRow(symbol: item.symbol, title: item.title, text: item.text)
                            }
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Got it", action: onDone).keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 14)
            .frame(width: 440)
        }
    }
}
