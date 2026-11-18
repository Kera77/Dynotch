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

/// The small panel shown on hover when "preview on hover" is on (spec PV-1): the current
/// feature's icon, name and one line about it.
struct FeaturePreviewView: View {
    let feature: FeatureID
    let preview: FeaturePreview
    let notchHeight: CGFloat
    /// Shown when a click opens the whole panel.
    let hint: String?

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 10) {
                Image(systemName: feature.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(preview.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let hint {
                    Text(hint)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
        }
        .contentShape(Rectangle())
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
            detail = "Hover longer or click to open"
        }
        return FeaturePreview(title: feature.title, detail: detail)
    }
}
