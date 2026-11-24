import AppKit
import CoreAudio
import SwiftUI

/// What the closed notch shows of the music: the cover with its colour (spec MU-2, MU-3).
/// Its own object, so the whole notch is not redrawn as the position moves.
@MainActor
@Observable
final class MusicIndicator {
    struct Glance: Equatable {
        let trackID: String
        let title: String
        let artist: String
        let isPlaying: Bool
        let artwork: NSImage?
        let tint: ArtworkColor.RGB
    }

    fileprivate(set) var glance: Glance?
    /// A new track's name is written under the notch for a moment (spec MU-4).
    fileprivate(set) var isAnnouncing = false
}

/// Spotify in the notch (spec MU-1…MU-7): reads what plays when Spotify says it changed, and
/// every few seconds while the module is on; sends the controls back.
@MainActor
@Observable
final class MusicService {
    private(set) var nowPlaying: NowPlaying?
    /// When `nowPlaying.position` was read; the position runs on from there while playing.
    private(set) var readAt = Date()
    private(set) var artwork: NSImage?
    private(set) var tint = ArtworkColor.fallback
    /// The sound outputs and the pause hiding, each its own object: their menus are not rebuilt
    /// as the music plays, so they stay open (spec N-22).
    let outputs = MusicOutputs()
    let hiding = MusicHiding()
    let indicator = MusicIndicator()
    /// Hidden by hand until the music plays again (spec MU-9).
    private(set) var isHiddenUntilPlay = false
    @ObservationIgnored private var pausedSince: Date?

    private let settings: AppSettings
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isVisible = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var settingsObserver: ChangeObservation?
    @ObservationIgnored private var hidingObserver: ChangeObservation?
    @ObservationIgnored private var announceTask: Task<Void, Never>?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var artworkTrack: String?
    @ObservationIgnored private var hasRead = false

    /// Spotify announces play, pause and track changes itself; the script only fills the gaps:
    /// often while the player is on screen (seeking), rarely otherwise.
    private static let pollInterval: TimeInterval = 3
    private static let backgroundPollInterval: TimeInterval = 30
    private static let announceDuration: TimeInterval = 4

    init(settings: AppSettings) {
        self.settings = settings
    }

    func hideUntilPlay() {
        isHiddenUntilPlay = true
        updateGlance()
    }

    /// The cover is left out while paused long enough, or hidden by hand (spec MU-9).
    nonisolated static func hidesCover(isPlaying: Bool, pausedSince: Date?, after minutes: Int?, byHand: Bool, now: Date) -> Bool {
        guard !isPlaying else { return false }
        if byHand { return true }
        guard let minutes, let pausedSince else { return false }
        return now.timeIntervalSince(pausedSince) >= Double(minutes) * 60
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
        hidingObserver = observeChanges { [hiding] in _ = hiding.minutes } onChange: { [weak self] in self?.updateGlance() }
        settingsObserver = observeChanges { [weak self] in
            _ = self?.isOn
            _ = self?.settings.showsNowPlaying
        } onChange: { [weak self] in
            self?.applyEnabled()
        }
        applyEnabled()
    }

    private func applyEnabled() {
        if isOn, timer == nil {
            schedule()
            refresh()
        } else if !isOn, timer != nil {
            timer?.invalidate()
            timer = nil
            apply(nil)
        }
        updateGlance()
    }

    /// The Music module shown or hidden.
    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        guard isOn else { return }
        schedule()
        if visible { refresh() }
    }

    private func schedule() {
        timer?.invalidate()
        timer = RepeatingTimer.start(every: isVisible ? Self.pollInterval : Self.backgroundPollInterval) { [weak self] in
            self?.refresh()
        }
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
        if playing?.isPlaying != false {
            pausedSince = nil
            if playing != nil { isHiddenUntilPlay = false }
        } else if pausedSince == nil {
            pausedSince = Date()
        }
        readAt = Date()
        if playing?.trackID != artworkTrack { loadArtwork(for: playing) }
        if let playing, playing.isPlaying, hasRead, playing.trackID != previous?.trackID { announce() }
        hasRead = true
        updateGlance()
    }

    private func updateGlance() {
        // The cover can be turned off (spec MU-8).
        let hidden = nowPlaying.map {
            Self.hidesCover(
                isPlaying: $0.isPlaying, pausedSince: pausedSince, after: hiding.minutes, byHand: isHiddenUntilPlay, now: Date()
            )
        } ?? true
        let glance = settings.showsNowPlaying && !hidden ? nowPlaying.map {
            MusicIndicator.Glance(
                trackID: $0.trackID, title: $0.title, artist: $0.artist, isPlaying: $0.isPlaying, artwork: artwork, tint: tint
            )
        } : nil
        if indicator.glance != glance { indicator.glance = glance }
        if glance == nil, indicator.isAnnouncing { indicator.isAnnouncing = false }
    }

    /// True while a notch is open on the Music module: the track is in view there (spec MU-10).
    @ObservationIgnored var holdsAnnouncement: () -> Bool = { false }

    private func announce() {
        guard !holdsAnnouncement() else { return }
        indicator.isAnnouncing = true
        endAnnouncement(after: Self.announceDuration)
    }

    /// A long name runs through first; the announcement ends this long from now (spec MU-4b).
    func endAnnouncement(after seconds: TimeInterval) {
        announceTask?.cancel()
        announceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
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
            pausedSince = playing.isPlaying ? nil : Date()
            if playing.isPlaying { isHiddenUntilPlay = false }
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
}

/// The Mac's sound outputs for the player's menu (spec MU-6).
@MainActor
@Observable
final class MusicOutputs {
    private(set) var devices: [SoundOutputs.Device] = []
    private(set) var current: AudioDeviceID?

    func refresh() {
        devices = SoundOutputs.list()
        current = SoundOutputs.current
    }

    func select(_ id: AudioDeviceID) {
        SoundOutputs.select(id)
        refresh()
    }
}

/// After how many minutes of pause the cover goes away; nil: never (spec MU-9).
@MainActor
@Observable
final class MusicHiding {
    var minutes: Int? {
        didSet { UserDefaults.standard.set(minutes ?? -1, forKey: Self.key) }
    }

    static let choices: [Int?] = [0, 1, 5, 15, nil]
    private static let key = "musicHideAfterPause"

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.key) as? Int ?? 5
        minutes = stored < 0 ? nil : stored
    }
}
