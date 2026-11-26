import Foundation

/// A tile's size in rows and columns (spec HT-2): 1×2 is one row tall and two columns wide.
struct TileSize: Hashable, Sendable {
    let rows: Int
    let columns: Int

    static let small = TileSize(rows: 1, columns: 1)
    static let wide = TileSize(rows: 1, columns: 2)
    static let tall = TileSize(rows: 2, columns: 1)
    static let large = TileSize(rows: 2, columns: 2)
    static let wideLarge = TileSize(rows: 2, columns: 3)
    static let tallLarge = TileSize(rows: 3, columns: 2)
    /// One row across the five columns (spec HT-43).
    static let strip = TileSize(rows: 1, columns: 5)

    var label: String { "\(rows)×\(columns)" }
}

/// A tile the Home can show (spec HT-14). The raw value is the saved id, `module.tile` (spec HT-15).
enum HomeTile: String, CaseIterable, Identifiable, Sendable {
    case clock = "home.clock"
    case clockWide = "home.clockWide"
    case worldClock = "home.worldClock"
    case today = "home.today"
    case month = "calendar.month"
    case nextEvent = "calendar.nextEvent"
    case nextEventWide = "calendar.nextEventWide"
    case week = "calendar.week"
    case agendaTall = "calendar.agendaTall"
    case agenda = "calendar.agenda"
    case calendarWide = "calendar.calendarWide"
    case calendarTall = "calendar.calendarTall"
    case days = "calendar.days"
    case weatherNow = "weather.now"
    case hourly = "weather.hourly"
    case fiveDays = "weather.fiveDays"
    case rain = "weather.rain"
    case unread = "notifications.unread"
    case latest = "notifications.latest"
    case latestLarge = "notifications.latestLarge"
    case mail = "notifications.mail"
    case remindersOpen = "reminders.open"
    case upcoming = "reminders.upcoming"
    case remindersToday = "reminders.today"
    case latestNote = "notes.latest"
    case todos = "notes.todos"
    case quickNote = "notes.quickNote"
    case lastResult = "calculator.lastResult"
    case keypad = "calculator.keypad"
    case notepad = "calculator.notepad"
    case fiveHour = "claudeUsage.fiveHour"
    case weekly = "claudeUsage.weekly"
    case limits = "claudeUsage.limits"
    case chat = "claudeChat.chat"
    case ask = "claudeChat.ask"
    case claudeSessions = "claudeSessions.list"
    case cleaner = "cleaner.status"
    case batteryMac = "battery.mac"
    case devices = "battery.devices"
    case lastCopied = "clipboard.last"
    case recentClips = "clipboard.recent"
    case recentClipsTall = "clipboard.recentTall"
    case trayFiles = "tray.files"
    case trayFilesWide = "tray.filesWide"
    case nowPlaying = "music.nowPlaying"
    case nowPlayingWide = "music.nowPlayingWide"
    case nowPlayingLarge = "music.nowPlayingLarge"
    case cpu = "stats.cpu"
    case memory = "stats.memory"
    case swap = "stats.swap"
    case network = "stats.network"
    case disk = "stats.disk"
    case macBattery = "stats.battery"
    case topProcesses = "stats.processes"
    case terminal = "terminal.terminal"
    case run = "terminal.run"
    case timer = "tools.timer"
    case stopwatch = "tools.stopwatch"
    case pomodoro = "tools.pomodoro"
    case quickToggles = "tools.quickToggles"
    case keepAwake = "tools.keepAwake"
    case version = "info.version"

    var id: String { rawValue }

    private struct Info: Sendable {
        let feature: FeatureID
        let title: String
        let size: TileSize
    }

    private static let info: [HomeTile: Info] = [
        .clock: Info(feature: .home, title: "Clock", size: .small),
        .clockWide: Info(feature: .home, title: "Clock", size: .wide),
        .worldClock: Info(feature: .home, title: "World clock", size: .small),
        .today: Info(feature: .home, title: "Today", size: .large),
        .month: Info(feature: .calendar, title: "Month", size: .wide),
        .nextEvent: Info(feature: .calendar, title: "Next event", size: .small),
        .nextEventWide: Info(feature: .calendar, title: "Next event", size: .wide),
        .week: Info(feature: .calendar, title: "Week", size: .wide),
        .agendaTall: Info(feature: .calendar, title: "Agenda", size: .tall),
        .agenda: Info(feature: .calendar, title: "Agenda", size: .large),
        .calendarWide: Info(feature: .calendar, title: "Calendar", size: .wideLarge),
        .calendarTall: Info(feature: .calendar, title: "Calendar", size: .tallLarge),
        .days: Info(feature: .calendar, title: "Days", size: .strip),
        .weatherNow: Info(feature: .weather, title: "Now", size: .small),
        .hourly: Info(feature: .weather, title: "Hourly", size: .wide),
        .fiveDays: Info(feature: .weather, title: "5 days", size: .large),
        .rain: Info(feature: .weather, title: "Rain", size: .small),
        .unread: Info(feature: .notifications, title: "Unread", size: .small),
        .latest: Info(feature: .notifications, title: "Latest", size: .wide),
        .latestLarge: Info(feature: .notifications, title: "Latest", size: .large),
        .mail: Info(feature: .notifications, title: "Mail", size: .small),
        .remindersOpen: Info(feature: .reminders, title: "Open", size: .small),
        .upcoming: Info(feature: .reminders, title: "Upcoming", size: .wide),
        .remindersToday: Info(feature: .reminders, title: "Today", size: .large),
        .latestNote: Info(feature: .notes, title: "Latest note", size: .wide),
        .todos: Info(feature: .notes, title: "To-dos", size: .tall),
        .quickNote: Info(feature: .notes, title: "Quick note", size: .wide),
        .lastResult: Info(feature: .calculator, title: "Last result", size: .small),
        .keypad: Info(feature: .calculator, title: "Calculator", size: .large),
        .notepad: Info(feature: .calculator, title: "Notepad", size: .wide),
        .fiveHour: Info(feature: .claudeUsage, title: "5-hour", size: .small),
        .weekly: Info(feature: .claudeUsage, title: "Weekly", size: .small),
        .limits: Info(feature: .claudeUsage, title: "Limits", size: .wide),
        .chat: Info(feature: .claudeChat, title: "Chat", size: .wide),
        .ask: Info(feature: .claudeChat, title: "Ask", size: .wide),
        .claudeSessions: Info(feature: .claudeSessions, title: "Sessions", size: .wide),
        .cleaner: Info(feature: .cleaner, title: "Cleaner", size: .small),
        .batteryMac: Info(feature: .battery, title: "Mac", size: .small),
        .devices: Info(feature: .battery, title: "Devices", size: .wide),
        .lastCopied: Info(feature: .clipboard, title: "Last copied", size: .small),
        .recentClips: Info(feature: .clipboard, title: "Recent", size: .wide),
        .recentClipsTall: Info(feature: .clipboard, title: "Recent", size: .tall),
        .trayFiles: Info(feature: .tray, title: "Files", size: .small),
        .trayFilesWide: Info(feature: .tray, title: "Files", size: .wide),
        .nowPlaying: Info(feature: .music, title: "Now playing", size: .small),
        .nowPlayingWide: Info(feature: .music, title: "Now playing", size: .wide),
        .nowPlayingLarge: Info(feature: .music, title: "Now playing", size: .large),
        .cpu: Info(feature: .stats, title: "CPU", size: .small),
        .memory: Info(feature: .stats, title: "Memory", size: .small),
        .swap: Info(feature: .stats, title: "Swap", size: .small),
        .network: Info(feature: .stats, title: "Network", size: .small),
        .disk: Info(feature: .stats, title: "Disk", size: .small),
        .macBattery: Info(feature: .stats, title: "Battery", size: .small),
        .topProcesses: Info(feature: .stats, title: "Top processes", size: .tall),
        .terminal: Info(feature: .terminal, title: "Terminal", size: .wide),
        .run: Info(feature: .terminal, title: "Run", size: .small),
        .timer: Info(feature: .tools, title: "Timer", size: .small),
        .stopwatch: Info(feature: .tools, title: "Stopwatch", size: .small),
        .pomodoro: Info(feature: .tools, title: "Pomodoro", size: .small),
        .quickToggles: Info(feature: .tools, title: "Quick toggles", size: .wide),
        .keepAwake: Info(feature: .tools, title: "Keep Awake", size: .small),
        .version: Info(feature: .info, title: "Version", size: .small)
    ]

    /// The module the tile opens (spec HT-11); the Home's own tiles open nothing.
    var feature: FeatureID { Self.info[self]?.feature ?? .home }
    var title: String { Self.info[self]?.title ?? rawValue }
    var size: TileSize { Self.info[self]?.size ?? .small }

    /// The first launch's tiles and Reset to default (spec HT-17).
    static let defaults: [HomeTile] = [.clockWide, .nextEvent, .weatherNow, .remindersOpen, .fiveHour, .nowPlayingWide]

    /// Tiles with a text field: the Home then takes the keyboard (spec HT-28).
    static let withFields: Set<HomeTile> = [.quickNote, .ask, .notepad]

    /// Tiles with their own settings (spec HT-29).
    static let withOptions: Set<HomeTile> = [.worldClock, .run]

    /// Saved ids back to tiles: unknown ones and repeats are left out (spec HT-15, HT-23).
    static func decode(_ ids: [String]) -> [HomeTile] {
        var tiles: [HomeTile] = []
        for tile in ids.compactMap(HomeTile.init(rawValue:)) where !tiles.contains(tile) {
            tiles.append(tile)
        }
        return tiles
    }
}

/// One module's tiles in the settings' catalog (spec HT-21).
struct HomeTileGroup: Identifiable, Sendable {
    let feature: FeatureID
    let tiles: [HomeTile]

    var id: FeatureID { feature }

    /// The modules in the given order, each with its tiles; modules without a tile are left out.
    static func catalog(order: [FeatureID]) -> [HomeTileGroup] {
        let features = order + FeatureID.allCases.filter { !order.contains($0) }
        return features.compactMap { feature in
            let tiles = HomeTile.allCases.filter { $0.feature == feature }
            return tiles.isEmpty ? nil : HomeTileGroup(feature: feature, tiles: tiles)
        }
    }
}
