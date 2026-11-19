import SwiftUI

/// What the preview says about a feature (spec PV-1).
struct FeaturePreview: Equatable, Sendable {
    let title: String
    let detail: String

    /// The first line of a text, shortened; `fallback` if there is none.
    static func line(of text: String, fallback: String, last: Bool = false) -> String {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard let line = last ? lines.last : lines.first else { return fallback }
        return line.count > 70 ? String(line.prefix(70)) + "…" : line
    }
}

/// DyNotch Wings (spec PV-4, PV-7, PV-8): the notch widened to both sides at its own height.
/// Only a click on the notch itself opens the panel; the sides' buttons do their own thing.
/// Each side is measured at its natural width so the notch grows as far as the wider one needs.
struct WingsView<Left: View, Right: View>: View {
    let notchWidth: CGFloat
    let openFully: () -> Void
    let measured: (CGFloat) -> Void
    @ViewBuilder let left: Left
    @ViewBuilder let right: Right

    @State private var leftWidth: CGFloat = 0
    @State private var rightWidth: CGFloat = 0

    static var padding: CGFloat { 14 }

    var body: some View {
        GeometryReader { proxy in
            let side = max((proxy.size.width - notchWidth) / 2, 0)
            HStack(spacing: 0) {
                left
                    .lineLimit(1)
                    .padding(.horizontal, Self.padding)
                    .frame(width: side, alignment: .leading)
                    .clipped()
                Color.clear
                    .frame(width: notchWidth)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: openFully)
                right
                    .lineLimit(1)
                    .padding(.horizontal, Self.padding)
                    .frame(width: side, alignment: .trailing)
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(alignment: .leading) {
            // The natural widths, never shown.
            ZStack {
                left.lineLimit(1).fixedSize().readWidth($leftWidth)
                right.lineLimit(1).fixedSize().readWidth($rightWidth)
            }
            .hidden()
            .allowsHitTesting(false)
        }
        .onChange(of: max(leftWidth, rightWidth), initial: true) { _, width in
            measured(width + 2 * Self.padding)
        }
    }
}

extension NotchView {
    /// One line about the current feature (spec PV-1).
    var featurePreview: FeaturePreview {
        let feature = model.currentFeature
        let detail: String
        switch feature {
        case .calendar:
            let next = calendar.events(on: Date()).first { $0.end > Date() }
            detail = next.map { "\($0.start.formatted(date: .omitted, time: .shortened)) · \($0.title)" } ?? "Nothing more today"
        case .notifications:
            let count = notifications.recent.count
            let latest = notifications.recent.first.map { notifications.content(for: $0).sender }
            detail = latest.map { "\(count) · latest from \($0)" } ?? "No new notifications"
        case .calculator:
            detail = FeaturePreview.line(of: calculator.text, fallback: "Empty", last: true)
        case .notes:
            detail = FeaturePreview.line(of: notes.text, fallback: "Empty note")
        case .reminders:
            detail = reminders.open.isEmpty ? "Nothing open" : "\(reminders.open.count) open · \(reminders.open[0].title)"
        case .claudeUsage:
            detail = claudeUsage.limits.isEmpty ? "No usage loaded" : claudeUsage.summary
        case .claudeChat:
            let lastMessage = chat.selected?.messages.last?.text ?? ""
            detail = chat.isWorking ? "Working…" : FeaturePreview.line(of: lastMessage, fallback: "Ask Claude anything")
        case .battery:
            let lowest = battery.devices.min { $0.level < $1.level }
            detail = lowest.map { "\(battery.devices.count) devices · lowest: \($0.name) \($0.level)%" } ?? "No device found"
        case .clipboard:
            detail = FeaturePreview.line(of: clipboard.history.first?.text ?? "", fallback: "Nothing copied yet")
        case .tray:
            let count = tray.trayFiles.count
            detail = count == 0 ? "Drop files on the notch" : "\(count) file\(count == 1 ? "" : "s") in the tray"
        case .music:
            detail = music.nowPlaying.map { "\($0.title) · \($0.artist)" } ?? "Nothing playing in Spotify"
        case .stats:
            detail = "CPU \(StatsFormat.percent(stats.snapshot.cpu)) · ↓ \(StatsFormat.rate(stats.snapshot.download))"
        case .home, .info:
            detail = "Click or swipe down to open"
        }
        return FeaturePreview(title: feature.title, detail: detail)
    }
}
