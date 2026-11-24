import SwiftUI

extension ArtworkColor.RGB {
    var color: Color { Color(red: red, green: green, blue: blue) }
}

/// The cover beside the closed notch with a ring that runs clockwise as the track plays, in the
/// cover's colour (spec MU-2, MU-3).
struct MusicCoverRing: View {
    var service: MusicService
    let glance: MusicIndicator.Glance

    static let size: CGFloat = 22
    private static let lineWidth: CGFloat = 2

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ZStack {
                Circle().stroke(Color.white.level(0.18), lineWidth: Self.lineWidth)
                Circle()
                    .trim(from: 0, to: service.progress(at: context.date))
                    .stroke(glance.tint.color, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                MusicArtwork(image: glance.artwork, cornerRadius: nil)
                    .padding(Self.lineWidth + 1.5)
                    .opacity(glance.isPlaying ? 1 : 0.55)
            }
            .frame(width: Self.size, height: Self.size)
        }
    }
}

/// The cover, or a note while it loads.
struct MusicArtwork: View {
    let image: NSImage?
    /// nil: round.
    let cornerRadius: CGFloat?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.white.level(0.12)
                    Image(systemName: "music.note").foregroundStyle(Color.white.level(0.6))
                }
            }
        }
        .clipShape(cornerRadius.map { AnyShape(RoundedRectangle(cornerRadius: $0, style: .continuous)) } ?? AnyShape(Circle()))
    }
}

/// The music player module (spec MU-5, MU-6): cover, title, position, controls, volume, output.
struct MusicFeatureView: View {
    var service: MusicService
    let isActive: Bool

    var body: some View {
        Group {
            if let playing = service.nowPlaying {
                player(playing)
            } else {
                empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { service.setVisible(isActive) }
        .onChange(of: isActive) { _, active in service.setVisible(active) }
        .onDisappear { service.setVisible(false) }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note").font(.notch(size: 18))
            Text(SpotifyClient.isRunning ? "Nothing is playing in Spotify" : "Spotify is not running")
                .font(.notch(size: 12, weight: .medium))
            Button(SpotifyClient.isRunning ? "Show Spotify" : "Open Spotify") { SpotifyClient.open() }
                .buttonStyle(.notch)
                .font(.notch(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(Theme.fill))
        }
        .foregroundStyle(Color.white.level(0.6))
    }

    private func player(_ playing: NowPlaying) -> some View {
        GeometryReader { proxy in
            let side = min(proxy.size.height - 16, proxy.size.width * 0.4)
            HStack(spacing: 16) {
                Button { SpotifyClient.open() } label: {
                    MusicArtwork(image: service.artwork, cornerRadius: AppleStyle.corner(10))
                        .frame(width: side, height: side)
                        .shadow(color: service.tint.color.opacity(0.35), radius: 12)
                }
                .buttonStyle(.notch)
                .help("Show Spotify")
                VStack(alignment: .leading, spacing: 8) {
                    titles(playing)
                    MusicProgressBar(service: service, duration: playing.duration)
                    MusicControls(service: service, playing: playing)
                    MusicVolumeRow(service: service, volume: playing.volume)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func titles(_ playing: NowPlaying) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(playing.title)
                .font(.notch(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text([playing.artist, playing.album].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.notch(size: 12))
                .foregroundStyle(Color.white.level(0.6))
                .lineLimit(1)
        }
    }
}

/// The position, with a click or drag to jump (spec MU-5).
struct MusicProgressBar: View {
    var service: MusicService
    let duration: Double
    @State private var dragged: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = dragged ?? service.position(at: context.date)
            VStack(spacing: 3) {
                GeometryReader { proxy in
                    let fraction = duration > 0 ? min(max(position / duration, 0), 1) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.level(0.15))
                        Capsule().fill(service.tint.color).frame(width: proxy.size.width * fraction)
                    }
                    .frame(height: 4)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in dragged = Self.seconds(at: value.location.x, width: proxy.size.width, duration: duration) }
                        .onEnded { value in
                            service.seek(to: Self.seconds(at: value.location.x, width: proxy.size.width, duration: duration))
                            dragged = nil
                        })
                }
                .frame(height: 12)
                HStack {
                    Text(Self.time(position))
                    Spacer()
                    Text("-" + Self.time(max(duration - position, 0)))
                }
                .font(.notch(size: 10))
                .monospacedDigit()
                .foregroundStyle(Color.white.level(0.45))
            }
        }
    }

    nonisolated static func seconds(at x: CGFloat, width: CGFloat, duration: Double) -> Double {
        guard width > 0 else { return 0 }
        return min(max(Double(x / width), 0), 1) * duration
    }

    nonisolated static func time(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct MusicControls: View {
    var service: MusicService
    let playing: NowPlaying
    /// Smaller, for the drop-down under the row.
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 12 : 18) {
            toggle("shuffle", isOn: playing.isShuffling, help: "Shuffle", action: service.toggleShuffle)
            button("backward.fill", size: compact ? 12 : 16, help: "Previous", action: service.previous)
            button(playing.isPlaying ? "pause.fill" : "play.fill", size: compact ? 16 : 22, help: playing.isPlaying ? "Pause" : "Play",
                   action: service.playPause)
            button("forward.fill", size: compact ? 12 : 16, help: "Next", action: service.next)
            toggle("repeat", isOn: playing.isRepeating, help: "Repeat", action: service.toggleRepeat)
        }
        .frame(maxWidth: .infinity)
    }

    private func button(_ symbol: String, size: CGFloat, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.notch(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .symbolReplace()
                .frame(width: size + 14, height: size + (compact ? 4 : 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .help(help)
        .accessibilityLabel(help)
    }

    private func toggle(_ symbol: String, isOn: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.notch(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? service.tint.color : Color.white.level(0.45))
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Spotify's volume and the Mac's sound output (spec MU-6).
struct MusicVolumeRow: View {
    var service: MusicService
    let volume: Int
    @State private var level: Double = 0
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill").font(.notch(size: 10)).foregroundStyle(Color.white.level(0.5))
            Slider(value: $level, in: 0...100) { editing in
                isEditing = editing
                if !editing { service.setVolume(Int(level.rounded())) }
            }
            .controlSize(.mini)
            .tint(service.tint.color)
            Image(systemName: "speaker.wave.3.fill").font(.notch(size: 10)).foregroundStyle(Color.white.level(0.5))
            MusicOutputMenu(outputs: service.outputs)
            MusicHideMenu(hiding: service.hiding, service: service)
        }
        .onAppear { level = Double(volume) }
        .onChange(of: volume) { _, new in if !isEditing { level = Double(new) } }
    }
}

/// Hiding the cover beside the notch while the music is paused (spec MU-9).
struct MusicHideMenu: View {
    @Bindable var hiding: MusicHiding
    /// Not watched: the menu must not be rebuilt as the music plays (spec N-22).
    let service: MusicService

    var body: some View {
        Menu {
            Button("Hide Now, Until It Plays") { service.hideUntilPlay() }
            Picker("Hide After a Pause", selection: $hiding.minutes) {
                ForEach(MusicHiding.choices, id: \.self) { Text(Self.title(for: $0)).tag($0) }
            }
            .pickerStyle(.menu)
        } label: {
            Image(systemName: "eye.slash")
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.level(0.7))
                .frame(width: 24, height: 22)
        }
        .menuStyle(.button)
        .buttonStyle(.notch)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Hide the cover beside the notch while paused")
        .accessibilityLabel("Hide the cover while paused")
    }

    static func title(for minutes: Int?) -> String {
        switch minutes {
        case nil: "Never"
        case 0: "Immediately"
        case 1: "After 1 minute"
        case let value?: "After \(value) minutes"
        }
    }
}

/// The player under the closed notch's row, when the cover is hovered (spec MU-2): the row with
/// the badges and counters stays above it.
struct MusicDropdown: View {
    var service: MusicService

    var body: some View {
        if let playing = service.nowPlaying {
            HStack(spacing: 12) {
                Button { SpotifyClient.open() } label: {
                    MusicArtwork(image: service.artwork, cornerRadius: AppleStyle.corner(8)).frame(width: 96, height: 96)
                }
                .buttonStyle(.notch)
                .help("Show Spotify")
                VStack(alignment: .leading, spacing: 3) {
                    Text(playing.title).font(.notch(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(playing.artist).font(.notch(size: 11)).foregroundStyle(Color.white.level(0.6)).lineLimit(1)
                    MusicProgressBar(service: service, duration: playing.duration)
                    MusicControls(service: service, playing: playing, compact: true)
                    MusicVolumeRow(service: service, volume: playing.volume)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear { service.setVisible(true) }
            .onDisappear { service.setVisible(false) }
        }
    }
}

/// Where the sound goes (spec MU-6).
struct MusicOutputMenu: View {
    var outputs: MusicOutputs

    var body: some View {
        Menu {
            ForEach(outputs.devices) { device in
                Button {
                    outputs.select(device.id)
                } label: {
                    if device.id == outputs.current {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            Image(systemName: "airplayaudio")
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.level(0.7))
                .frame(width: 24, height: 22)
        }
        .menuStyle(.button)
        .buttonStyle(.notch)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sound output")
        .accessibilityLabel("Sound output")
        .onAppear(perform: outputs.refresh)
    }
}

/// "Title — Artist, Artist" on one line. If it does not fit, it waits a second, runs through
/// from left to right until its end shows, and the announcement closes a second later (spec MU-4b).
struct MusicMarquee: View {
    let title: String
    let artist: String
    let tint: Color
    /// How long the announcement still needs, once the line is measured.
    let needs: (TimeInterval) -> Void

    @State private var offset: CGFloat = 0

    static let speed: CGFloat = 40

    /// Seconds before the end: the pause, the run, and the pause at the end.
    nonisolated static func duration(overflow: CGFloat) -> TimeInterval {
        overflow <= 0 ? 4 : 1 + Double(overflow / speed) + 1
    }

    var body: some View {
        GeometryReader { proxy in
            line
                .fixedSize()
                .background(GeometryReader { text in
                    Color.clear.onAppear { start(textWidth: text.size.width, room: proxy.size.width) }
                })
                .offset(x: offset)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                .clipped()
        }
    }

    private var line: some View {
        HStack(spacing: 6) {
            Text(title).font(.notch(size: 12, weight: .semibold)).foregroundStyle(.white)
            if !artist.isEmpty {
                Text("—").font(.notch(size: 12)).foregroundStyle(Color.white.level(0.4))
                Text(artist).font(.notch(size: 12)).foregroundStyle(tint)
            }
        }
        .lineLimit(1)
    }

    private func start(textWidth: CGFloat, room: CGFloat) {
        let overflow = textWidth - room
        needs(Self.duration(overflow: overflow))
        guard overflow > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.linear(duration: Double(overflow / Self.speed))) { offset = -overflow }
        }
    }
}
