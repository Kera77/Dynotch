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

/// Wingmate Wings (spec PV-4, PV-7, PV-24): the notch widened to both sides at its own height.
/// Only a click on the notch itself opens the panel; the sides' buttons do their own thing.
/// Each side is measured at its natural width and gets only that much room.
struct WingsView<Left: View, Right: View>: View {
    let notchWidth: CGFloat
    /// The sides' share of the room beside the notch, while the panel grows or shrinks.
    let sides: WingsSides
    let openFully: () -> Void
    let measured: (WingsSides) -> Void
    /// What the wings show (the module): changed, the sides are measured afresh (spec PV-51).
    var identity: String = ""
    @ViewBuilder let left: Left
    @ViewBuilder let right: Right

    @State private var leftWidth: CGFloat = 0
    @State private var rightWidth: CGFloat = 0
    /// Both sides slide out of the notch as it widens (spec PV-11).
    @Environment(\.wingsSpread) private var spread

    static var padding: CGFloat { WingsLayout.padding }

    var body: some View {
        GeometryReader { proxy in
            let room = max(proxy.size.width - notchWidth, 0)
            let total = max(sides.left + sides.right, 1)
            let leftSide = room * sides.left / total
            let rightSide = room - leftSide
            HStack(spacing: 0) {
                left
                    // A new module's sides start fresh (their running text too), spec PV-56.
                    .id(identity)
                    .lineLimit(1)
                    .padding(.horizontal, Self.padding)
                    .frame(width: leftSide, alignment: .trailing)
                    .clipped()
                    .wingSpread(spread, towardsNotch: leftSide / 2)
                Color.clear
                    .frame(width: notchWidth)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: openFully)
                right
                    .id(identity)
                    .lineLimit(1)
                    .padding(.horizontal, Self.padding)
                    .frame(width: rightSide, alignment: .leading)
                    .clipped()
                    .wingSpread(spread, towardsNotch: -rightSide / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(alignment: .leading) {
            // The natural widths, never shown.
            ZStack {
                left.lineLimit(1).fixedSize().readWidth($leftWidth)
                right.lineLimit(1).fixedSize().readWidth($rightWidth)
            }
            // A new module's content is measured as new, never as the last one's leftovers.
            .id(identity)
            .hidden()
            .allowsHitTesting(false)
        }
        .onChange(of: WingsSides(left: leftWidth, right: rightWidth), initial: true) { _, natural in
            report(natural)
        }
        // Once the new module is laid out, its widths count even if they equal the last ones.
        // Again once the swipe's motion has settled: a side measured mid-move (or before its
        // text loaded) never stays empty (spec PV-56).
        .task(id: identity) {
            for wait in [60, 350, 900] {
                try? await Task.sleep(for: .milliseconds(wait))
                guard !Task.isCancelled else { return }
                report(WingsSides(left: leftWidth, right: rightWidth))
            }
        }
    }

    private func report(_ natural: WingsSides) {
        measured(WingsSides(left: natural.left + 2 * Self.padding, right: natural.right + 2 * Self.padding))
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
        case .terminal:
            detail = TerminalStore.shared.selected.map { "\($0.title) · \(TerminalWing.tabs(TerminalStore.shared.sessions.count))" }
                ?? "Click or swipe down to open"
        case .tools:
            let clock = ToolsService.shared.glance?.clock
            detail = clock.map { "\($0.tab.title) · \(ClockText.text($0.seconds(at: Date())))" } ?? "Timer, stopwatch, pomodoro, toggles"
        case .weather:
            let forecast = WeatherService.shared.forecast
            detail = forecast.map { "\(WeatherService.degrees($0.now.temperature)) · \(WeatherCode.text($0.now.code))" }
                ?? "No weather loaded"
        case .claudeSessions:
            detail = ClaudeSessionsWing.right(notices.sessions.sessions)
        case .home, .info:
            detail = "Click or swipe down to open"
        }
        return FeaturePreview(title: feature.title, detail: detail)
    }
}
