import SwiftUI

/// The AI Usage, AI and Batteries tiles (spec HT-14).
struct AITileContent: View {
    let tile: HomeTile
    let services: HomeTileServices
    let size: TileSize

    @Environment(\.openTilePart) private var openPart

    var body: some View {
        switch tile {
        case .fiveHour: ring(services.usage.session, title: "5-hour")
        case .weekly: ring(Self.weekly(in: services.usage.limits), title: "Weekly")
        case .limits: limits
        case .chat: chat
        case .ask:
            QuickFieldTile(title: "Ask \(services.chat.provider.title)", placeholder: "Ask anything…") { question in
                services.chat.draft = question
                services.chat.send()
                openPart(.ask, .claudeChat)
            }
        case .batteryMac: macBattery
        default: devices
        }
    }

    /// The weekly limit among the usage limits (its id starts with "seven_day").
    nonisolated static func weekly(in limits: [UsageLimit]) -> UsageLimit? {
        limits.first { $0.id == "seven_day" } ?? limits.first { $0.id.hasPrefix("seven_day") }
    }

    private func ring(_ limit: UsageLimit?, title: String) -> some View {
        let share = (limit?.utilization ?? 0) / 100
        return HStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(max(share, 0), 1))
                    .stroke(StatsSlot.color(for: share), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 34, height: 34)
            TileValueView(
                title: title, value: limit.map { "\(Int($0.utilization.rounded()))%" } ?? "—",
                detail: limit?.resetsAt.map { "Resets " + Self.resetText($0) }
            )
        }
    }

    private var limits: some View {
        VStack(alignment: .leading, spacing: 6) {
            bar(services.usage.session, title: "5-hour")
            bar(Self.weekly(in: services.usage.limits), title: "Weekly")
        }
    }

    private func bar(_ limit: UsageLimit?, title: String) -> some View {
        let share = (limit?.utilization ?? 0) / 100
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.notch(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(limit.map { "\(Int($0.utilization.rounded()))%" } ?? "—").font(.notch(size: 11, weight: .semibold)).monospacedDigit()
            }
            StatsBar(fraction: share, color: StatsSlot.color(for: share))
            if let reset = limit?.resetsAt {
                Text("Resets " + Self.resetText(reset)).font(.notch(size: 9)).foregroundStyle(.secondary)
            }
        }
    }

    static func resetText(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.weekday().hour().minute())
    }

    private var chat: some View {
        let selected = services.chat.selected
        let last = selected?.messages.last?.text ?? ""
        return VStack(alignment: .leading, spacing: 2) {
            Text(selected?.title ?? "AI").font(.notch(size: 11, weight: .semibold)).lineLimit(1)
            Text(services.chat.isWorking ? "Working…" : FeaturePreview.line(of: last, fallback: "Ask anything"))
                .font(.notch(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var macBattery: some View {
        let mac = services.battery.devices.first { $0.kind == .mac }
        return TileValueView(
            title: "Mac", value: mac.map { "\($0.level)%" } ?? "—",
            detail: mac.map { $0.isCharging ? "Charging" : "On battery" } ?? "No battery",
            color: (mac?.isLow ?? false) ? Theme.red : .white
        )
    }

    private var devices: some View {
        let devices = services.battery.devices.filter { $0.kind != .mac }.prefix(4)
        return VStack(alignment: .leading, spacing: 3) {
            if devices.isEmpty {
                TileEmptyView(title: "Devices", text: "No device found")
            }
            ForEach(Array(devices)) { device in
                TileRow(text: device.name, note: "\(device.level)%") {
                    BatteryDeviceIcon(kind: device.kind, size: 11, color: device.isLow ? Theme.red : .white)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// The Tray and Music tiles (spec HT-14).
struct MediaTileContent: View {
    let tile: HomeTile
    let services: HomeTileServices
    let size: TileSize

    var body: some View {
        if tile.feature == .tray {
            trayFiles
        } else if let playing = services.music.nowPlaying {
            nowPlaying(playing)
        } else {
            TileEmptyView(title: "Music", text: "Nothing playing")
        }
    }

    private var trayFiles: some View {
        let files = services.tray.trayFiles
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Array(files.prefix(size.columns == 1 ? 1 : 4).enumerated()), id: \.offset) { _, file in
                    Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
            }
            TileValueView(
                title: "Tray", value: "\(files.count)",
                detail: files.isEmpty ? "Drop files on the notch" : files.count == 1 ? "file" : "files"
            )
        }
    }

    @ViewBuilder
    private func nowPlaying(_ playing: NowPlaying) -> some View {
        let music = services.music
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 4) {
                MusicArtwork(image: music.artwork, cornerRadius: Theme.Radius.medium).frame(width: 44, height: 44)
                Text(playing.title).font(.notch(size: 11, weight: .semibold)).lineLimit(1)
            }
        case .wide:
            HStack(spacing: 8) {
                MusicArtwork(image: music.artwork, cornerRadius: Theme.Radius.medium).frame(width: 52, height: 52)
                titles(playing)
                Spacer(minLength: 2)
                controls(playing)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                MusicArtwork(image: music.artwork, cornerRadius: Theme.Radius.large).frame(width: 92, height: 92)
                titles(playing)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    StatsBar(fraction: music.progress(at: context.date), color: .white)
                }
                controls(playing)
            }
        }
    }

    private func titles(_ playing: NowPlaying) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(playing.title).font(.notch(size: 12, weight: .semibold)).lineLimit(1)
            Text(playing.artist).font(.notch(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private func controls(_ playing: NowPlaying) -> some View {
        HStack(spacing: 6) {
            TileButton(symbol: playing.isPlaying ? "pause.fill" : "play.fill", help: playing.isPlaying ? "Pause" : "Play") {
                services.music.playPause()
            }
            TileButton(symbol: "forward.fill", help: "Next") { services.music.next() }
        }
    }
}
