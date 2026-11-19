import SwiftUI

// MARK: - DyNotch Wings content, devices and media (spec PV-9)

extension NotchView {
    // MARK: Batteries

    @ViewBuilder var batteryWingLeft: some View {
        if let mac = battery.devices.first(where: { $0.kind == .mac }) {
            HStack(spacing: 6) {
                WingSymbol("laptopcomputer")
                WingText("\(mac.level)%", bold: true)
            }
        } else {
            WingLabel(symbol: "battery.100percent", text: "Batteries")
        }
    }

    var batteryWingRight: some View {
        HStack(spacing: 10) {
            ForEach(battery.devices.filter { $0.kind != .mac }.prefix(4)) { device in
                HStack(spacing: 4) {
                    WingSymbol(device.kind.symbols.first ?? "battery.50percent")
                    WingText("\(device.level)%").foregroundStyle(device.isLow ? .red : .white)
                }
                .help(device.name)
            }
        }
    }

    // MARK: Tray

    var trayWingLeft: some View {
        let files = tray.trayFiles
        return HStack(spacing: 4) {
            if files.isEmpty {
                // The same capsule as AirDrop at the right (spec PV-36).
                WingButton(title: "Drop files on the notch", symbol: "tray", help: "Drop files on the notch to keep them in the tray") {}
                    .allowsHitTesting(false)
            }
            ForEach(files.prefix(4), id: \.item.id) { file in
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                    .resizable()
                    .frame(width: 18, height: 18)
            }
            if files.count > 4 { WingText("+\(files.count - 4)", dim: true) }
        }
    }

    /// AirDrop for the tray's files: a click sends them all, files dropped on it go too.
    var trayWingRight: some View {
        WingButton(title: "AirDrop", symbol: "dot.radiowaves.left.and.right", help: "Send the tray's files with AirDrop") {
            let urls = tray.trayFiles.map(\.url)
            if !urls.isEmpty { sendWithAirDrop(urls) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            sendWithAirDrop(urls)
            return true
        }
    }

    // MARK: Music

    @ViewBuilder var musicWingLeft: some View {
        if let playing = music.nowPlaying {
            HStack(spacing: 6) {
                if let artwork = music.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                WingText(playing.title, bold: true)
                WingText(playing.artist, dim: true)
            }
        } else {
            WingLabel(symbol: "music.note", text: "Nothing playing")
        }
    }

    @ViewBuilder var musicWingRight: some View {
        if let playing = music.nowPlaying {
            HStack(spacing: 8) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    StatsBar(fraction: music.progress(at: context.date), color: .white).frame(width: 70)
                }
                WingButton(title: nil, symbol: playing.isPlaying ? "pause.fill" : "play.fill", help: playing.isPlaying ? "Pause" : "Play") {
                    music.playPause()
                }
                WingButton(title: nil, symbol: "forward.fill", help: "Next") { music.next() }
            }
        }
    }
}

// MARK: - Pieces

struct WingText: View {
    let text: String
    var bold = false
    var dim = false

    init(_ text: String, bold: Bool = false, dim: Bool = false) {
        self.text = text
        self.bold = bold
        self.dim = dim
    }

    var body: some View {
        Text(text)
            .font(.notch(size: 12, weight: bold ? .semibold : .regular))
            .foregroundStyle(dim ? Color.white.level(0.6) : .white)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

struct WingSymbol: View {
    let name: String

    init(_ name: String) { self.name = name }

    var body: some View {
        Image(systemName: name)
            .font(.notch(size: 12, weight: .semibold))
            .foregroundStyle(.white)
    }
}

/// A module's icon and a line, the plain wing.
struct WingLabel: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            WingSymbol(symbol)
            WingText(text, bold: true)
        }
    }
}

/// An app's icon with its count.
struct WingCount<Icon: View>: View {
    let count: Int
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(spacing: 3) {
            icon
            Text(count > 99 ? "99+" : "\(count)")
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.level(0.8))
                .monospacedDigit()
        }
    }
}

/// A button in a wing: it does its own thing and never opens the panel (spec PV-7).
struct WingButton: View {
    let title: String?
    let symbol: String?
    var help = ""
    var prominent = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol) }
                if let title { Text(title) }
            }
            .font(.notch(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, title == nil ? 4 : 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(prominent ? Color.green.opacity(isHovered ? 0.9 : 0.75) : Color.white.level(isHovered ? 0.2 : 0.12)))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
    }
}

enum WingFormat {
    /// "in 25 min", "in 2 h", "now".
    static func countdown(to start: Date, end: Date, now: Date) -> String {
        if start <= now { return end > now ? "now" : "" }
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes < 60 ? "in \(minutes) min" : "in \(minutes / 60) h"
    }

    /// The day of a date beside "now": nil today, "Tomorrow", the weekday within a week,
    /// otherwise "Nov 28" (spec PV-25, PV-33).
    static func day(of date: Date, now: Date, calendar: Calendar = .current) -> String? {
        if calendar.isDate(date, inSameDayAs: now) { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        if days == 1 { return "Tomorrow" }
        if days == -1 { return "Yesterday" }
        if days > 1, days < 7 { return date.formatted(.dateTime.weekday(.wide)) }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func color(_ level: UsageLevel) -> Color {
        switch level {
        case .normal: .white
        case .high: .orange
        case .critical: .red
        }
    }
}
