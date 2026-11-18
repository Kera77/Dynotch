import AppKit
import Combine
import CoreAudio
import SwiftUI

/// What the closed notch shows of the music: the cover with its colour (spec MU-2, MU-3).
/// Its own object, so the whole notch is not redrawn as the position moves.
@MainActor
final class MusicIndicator: ObservableObject {
    struct Glance: Equatable {
        let trackID: String
        let title: String
        let artist: String
        let isPlaying: Bool
        let artwork: NSImage?
        let tint: ArtworkColor.RGB
    }

    @Published fileprivate(set) var glance: Glance?
    /// A new track's name is written under the notch for a moment (spec MU-4).
    @Published fileprivate(set) var isAnnouncing = false
}

/// Spotify in the notch (spec MU-1…MU-7): reads what plays when Spotify says it changed, and
/// every few seconds while the module is on; sends the controls back.
@MainActor
final class MusicService: ObservableObject {
    @Published private(set) var nowPlaying: NowPlaying?
    /// When `nowPlaying.position` was read; the position runs on from there while playing.
    @Published private(set) var readAt = Date()
    @Published private(set) var artwork: NSImage?
    @Published private(set) var tint = ArtworkColor.fallback
    @Published private(set) var outputs: [SoundOutputs.Device] = []
    @Published private(set) var currentOutput: AudioDeviceID?
    let indicator = MusicIndicator()

    private let settings: AppSettings
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var settingsObserver: AnyCancellable?
    private var announceTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var artworkTrack: String?
    private var hasRead = false

    private static let pollInterval: TimeInterval = 3
    private static let announceDuration: TimeInterval = 4

    init(settings: AppSettings) {
        self.settings = settings
    }

    var isOn: Bool { settings.isEnabled(.music) }

    func start() {
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: SpotifyClient.changeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == SpotifyClient.bundleID else { return }
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        settingsObserver = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.applyEnabled() } }
        }
        applyEnabled()
    }

    private func applyEnabled() {
        if isOn, timer == nil {
            let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
            refresh()
        } else if !isOn, timer != nil {
            timer?.invalidate()
            timer = nil
            apply(nil)
        }
        updateGlance()
    }

    func refresh() {
        guard isOn else { return }
        Task { [weak self] in
            let playing = await SpotifyClient.read()
            self?.apply(playing)
        }
    }

    /// Where the track is now: it runs on from the last reading while playing.
    func position(at date: Date) -> Double {
        guard let nowPlaying else { return 0 }
        guard nowPlaying.isPlaying else { return nowPlaying.position }
        return min(nowPlaying.position + date.timeIntervalSince(readAt), nowPlaying.duration)
    }

    func progress(at date: Date) -> Double {
        guard let duration = nowPlaying?.duration, duration > 0 else { return 0 }
        return min(max(position(at: date) / duration, 0), 1)
    }

    private func apply(_ playing: NowPlaying?) {
        let previous = nowPlaying
        nowPlaying = playing
        readAt = Date()
        if playing?.trackID != artworkTrack { loadArtwork(for: playing) }
        if let playing, playing.isPlaying, hasRead, playing.trackID != previous?.trackID { announce() }
        hasRead = true
        updateGlance()
    }

    private func updateGlance() {
        // The cover can be turned off (spec MU-8).
        let glance = settings.showsNowPlaying ? nowPlaying.map {
            MusicIndicator.Glance(
                trackID: $0.trackID, title: $0.title, artist: $0.artist, isPlaying: $0.isPlaying, artwork: artwork, tint: tint
            )
        } : nil
        if indicator.glance != glance { indicator.glance = glance }
        if glance == nil, indicator.isAnnouncing { indicator.isAnnouncing = false }
    }

    private func announce() {
        announceTask?.cancel()
        indicator.isAnnouncing = true
        announceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.announceDuration))
            guard !Task.isCancelled else { return }
            self?.indicator.isAnnouncing = false
        }
    }

    private func loadArtwork(for playing: NowPlaying?) {
        artworkTask?.cancel()
        artworkTrack = playing?.trackID
        guard let url = playing?.artworkURL, let track = playing?.trackID else {
            artwork = nil
            tint = ArtworkColor.fallback
            return
        }
        artworkTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url), !Task.isCancelled,
                  let self, self.artworkTrack == track, let image = NSImage(data: data)
            else { return }
            self.artwork = image
            self.tint = ArtworkColor.dominant(of: image)
            self.updateGlance()
        }
    }
}

// MARK: - Controls (spec MU-5, MU-6)

extension MusicService {
    func playPause() {
        if var playing = nowPlaying {
            playing.position = position(at: Date())
            playing.state = playing.isPlaying ? .paused : .playing
            nowPlaying = playing
            readAt = Date()
            updateGlance()
        }
        send(.playPause)
    }

    func next() { send(.next) }
    func previous() { send(.previous) }

    func seek(to seconds: Double) {
        nowPlaying?.position = seconds
        readAt = Date()
        send(.seek(seconds))
    }

    func toggleShuffle() {
        guard let isOn = nowPlaying?.isShuffling else { return }
        nowPlaying?.isShuffling = !isOn
        send(.shuffle(!isOn))
    }

    func toggleRepeat() {
        guard let isOn = nowPlaying?.isRepeating else { return }
        nowPlaying?.isRepeating = !isOn
        send(.repeating(!isOn))
    }

    func setVolume(_ level: Int) {
        nowPlaying?.volume = level
        send(.volume(level))
    }

    private func send(_ command: SpotifyClient.Command) {
        Task { [weak self] in
            await SpotifyClient.send(command)
            // Spotify needs a moment before it reports the new state.
            try? await Task.sleep(for: .milliseconds(300))
            self?.refresh()
        }
    }

    func refreshOutputs() {
        outputs = SoundOutputs.list()
        currentOutput = SoundOutputs.current
    }

    func selectOutput(_ id: AudioDeviceID) {
        SoundOutputs.select(id)
        refreshOutputs()
    }
}
