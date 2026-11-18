import AppKit

/// What Spotify plays (spec MU-1).
struct NowPlaying: Equatable, Sendable {
    enum State: String, Sendable {
        case playing
        case paused
    }

    var state: State
    var trackID: String
    var title: String
    var artist: String
    var album: String
    var artworkURL: URL?
    /// Seconds.
    var duration: Double
    /// Seconds, when it was read.
    var position: Double
    var isShuffling: Bool
    var isRepeating: Bool
    /// 0…100
    var volume: Int

    var isPlaying: Bool { state == .playing }

    /// The fields of `SpotifyClient.script`, in order; nil when nothing plays.
    nonisolated static func parse(_ fields: [String]) -> NowPlaying? {
        guard fields.count >= 11, let state = State(rawValue: fields[0]) else { return nil }
        // Spotify gives the length in milliseconds and the position in seconds.
        let duration = (Double(fields[5]) ?? 0) / 1000
        return NowPlaying(
            state: state, trackID: fields[10], title: fields[1], artist: fields[2], album: fields[3],
            artworkURL: URL(string: fields[4]).flatMap { $0.scheme == "https" ? $0 : nil },
            duration: duration, position: min(max(Double(fields[6]) ?? 0, 0), max(duration, 0)),
            isShuffling: fields[7] == "true", isRepeating: fields[8] == "true",
            volume: min(max(Int(Double(fields[9]) ?? 0), 0), 100)
        )
    }
}

/// Talks to Spotify through AppleScript (spec MU-1). Only while Spotify runs: a script sent to
/// it would launch it.
enum SpotifyClient {
    static let bundleID = "com.spotify.client"
    /// Spotify posts this whenever playback changes.
    static let changeNotification = Notification.Name("com.spotify.client.PlaybackStateChanged")

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    private static let queue = DispatchQueue(label: "Dynotch.spotify", qos: .userInitiated)

    private static let script = """
    tell application id "com.spotify.client"
        set playerState to player state as string
        if playerState is "stopped" then return {"stopped"}
        set t to current track
        return {playerState, name of t, artist of t, album of t, artwork url of t, duration of t, ¬
            player position, shuffling, repeating, sound volume, id of t}
    end tell
    """

    /// The current track, or nil when Spotify is closed or stopped.
    static func read() async -> NowPlaying? {
        guard isRunning else { return nil }
        let fields = await run(script)
        return fields.flatMap(NowPlaying.parse)
    }

    enum Command: Sendable {
        case playPause, next, previous
        case seek(Double)
        case shuffle(Bool)
        case repeating(Bool)
        case volume(Int)

        var line: String {
            switch self {
            case .playPause: "playpause"
            case .next: "next track"
            case .previous: "previous track"
            case .seek(let seconds): "set player position to \(Int(seconds.rounded()))"
            case .shuffle(let isOn): "set shuffling to \(isOn)"
            case .repeating(let isOn): "set repeating to \(isOn)"
            case .volume(let level): "set sound volume to \(min(max(level, 0), 100))"
            }
        }
    }

    static func send(_ command: Command) async {
        guard isRunning else { return }
        _ = await run("tell application id \"\(bundleID)\" to \(command.line)")
    }

    static func open() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Runs a script off the main thread; a list result comes back as text fields.
    private static func run(_ source: String) async -> [String]? {
        await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
                if let error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                    DiagnosticsLog.append("music", "Spotify script failed (\(code))")
                }
                continuation.resume(returning: result.map(fields(of:)))
            }
        }
    }

    private nonisolated static func fields(of descriptor: NSAppleEventDescriptor) -> [String] {
        guard descriptor.numberOfItems > 0 else { return [descriptor.stringValue ?? ""] }
        return (1...descriptor.numberOfItems).map { index in
            guard let item = descriptor.atIndex(index) else { return "" }
            switch item.descriptorType {
            case typeTrue: return "true"
            case typeFalse: return "false"
            case typeBoolean: return item.booleanValue ? "true" : "false"
            case typeIEEE64BitFloatingPoint, typeIEEE32BitFloatingPoint, typeSInt32, typeSInt16, typeSInt64:
                return String(item.doubleValue)
            default: return item.stringValue ?? ""
            }
        }
    }
}
