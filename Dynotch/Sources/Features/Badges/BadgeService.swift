import AppKit
import ApplicationServices
import Combine

/// Unread counts of the chosen apps, read from their Dock badges (spec B-1…B-7).
@MainActor
final class BadgeService: ObservableObject {
    private static let appsKey = "badgeApps"
    private static let brandIconsKey = "badgeBrandIcons"
    private static let interval: TimeInterval = 2

    /// The chosen apps in the order they stand beside the notch.
    @Published private(set) var apps: [BadgeApp] {
        didSet { save() }
    }

    /// Badge text per bundle identifier; only apps with a badge.
    @Published private(set) var labels: [String: String] = [:]
    @Published private(set) var pulses: [String: Date] = [:]
    /// Reading the Dock needs Accessibility access.
    @Published private(set) var isTrusted = true

    private let defaults: UserDefaults
    private var timer: Timer?
    private var isReading = false
    /// The first reading only records what is there: old badges are not new notifications.
    private var hasBaseline = false
    private var bundleIDs: [String: String] = [:]
    private var loggedSignature = ""

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.data(forKey: Self.appsKey).flatMap { try? JSONDecoder().decode([BadgeApp].self, from: $0) }
        var loaded = stored ?? []
        if !defaults.bool(forKey: Self.brandIconsKey) {
            // Once: the generic glyphs of Beeper, Google Chat and Gmail become their own marks.
            loaded = loaded.map { app in
                var app = app
                app.icon = BadgeTracker.upgradedIcon(for: app)
                return app
            }
            defaults.set(true, forKey: Self.brandIconsKey)
        }
        apps = loaded
        save()
    }

    /// Enabled apps that have a badge now.
    var visible: [BadgeItem] {
        apps.compactMap { app in
            guard app.isEnabled, let label = labels[app.bundleID], !label.isEmpty else { return nil }
            return BadgeItem(app: app, label: label, pulseStart: pulses[app.bundleID])
        }
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        timer.tolerance = timer.timeInterval * 0.2
        self.timer = timer
        refresh()
    }

    func refresh() {
        guard apps.contains(where: \.isEnabled) else {
            apply([:], now: Date())
            return
        }
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
        guard trusted, !isReading else { return }
        isReading = true
        Task { [weak self] in
            let entries = await Task.detached { DockBadgeReader.read() }.value
            guard let self else { return }
            self.isReading = false
            self.log(entries)
            self.apply(self.labels(from: entries), now: Date())
        }
    }

    /// Badge text of the enabled apps, keyed by bundle identifier.
    private func labels(from entries: [DockEntry]) -> [String: String] {
        let enabled = Set(apps.filter(\.isEnabled).map(\.bundleID))
        var result: [String: String] = [:]
        for entry in entries where !entry.label.isEmpty {
            guard let path = entry.path, let bundleID = bundleID(atPath: path), enabled.contains(bundleID) else { continue }
            result[bundleID] = entry.label
        }
        return result
    }

    /// What the Dock reported, written when it changes (for troubleshooting).
    private func log(_ entries: [DockEntry]) {
        let badges = entries.filter { !$0.label.isEmpty }.map { "\($0.title)=\($0.label)" }
        let signature = "\(entries.count) Dock apps; badges: \(badges.joined(separator: ", "))"
        guard signature != loggedSignature else { return }
        loggedSignature = signature
        DiagnosticsLog.append("badges", signature)
    }

    private func bundleID(atPath path: String) -> String? {
        if let known = bundleIDs[path] { return known }
        let found = Bundle(path: path)?.bundleIdentifier
        bundleIDs[path] = found
        return found
    }

    func apply(_ current: [String: String], now: Date) {
        let updated = hasBaseline
            ? BadgeTracker.pulses(pulses, previous: labels, current: current, now: now)
            : [:]
        hasBaseline = true
        if updated != pulses { pulses = updated }
        if current != labels { labels = current }
    }

    /// The pointer was on the badge: it was noticed, so it stops pulsing (spec B-5).
    func acknowledge(_ bundleID: String) {
        if pulses[bundleID] != nil { pulses[bundleID] = nil }
    }

    // MARK: - Choosing apps (spec B-1, B-3)

    func add(_ app: InstalledApp) {
        guard !apps.contains(where: { $0.bundleID == app.bundleID }) else { return }
        let icon = BadgePreset.suggestedIcon(bundleID: app.bundleID, name: app.name)
        apps.append(BadgeApp(bundleID: app.bundleID, name: app.name, isEnabled: true, icon: icon))
        refresh()
    }

    func remove(_ bundleID: String) {
        apps.removeAll { $0.bundleID == bundleID }
    }

    func setEnabled(_ bundleID: String, _ enabled: Bool) {
        update(bundleID) { $0.isEnabled = enabled }
        refresh()
    }

    func setIcon(_ bundleID: String, _ icon: BadgeIcon) {
        update(bundleID) { $0.icon = icon }
    }

    private func update(_ bundleID: String, _ change: (inout BadgeApp) -> Void) {
        guard let index = apps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        change(&apps[index])
    }

    // MARK: - Order (spec B-7)

    func move(from source: IndexSet, to destination: Int) {
        var order = apps
        let moving = source.sorted().map { order[$0] }
        for index in source.sorted(by: >) { order.remove(at: index) }
        let insertAt = destination - source.filter { $0 < destination }.count
        order.insert(contentsOf: moving, at: max(0, min(insertAt, order.count)))
        apps = order
    }

    /// Moves a badge among the ones visible beside the notch; the others keep their places.
    func moveVisible(_ bundleID: String, toVisibleIndex index: Int) {
        let shown = visible.map(\.id)
        let reordered = BadgeReorder.moved(shown, id: bundleID, to: index)
        guard reordered != shown else { return }
        let byID = Dictionary(apps.map { ($0.bundleID, $0) }) { first, _ in first }
        var remaining = reordered.makeIterator()
        apps = apps.map { app in
            guard shown.contains(app.bundleID), let next = remaining.next() else { return app }
            return byID[next] ?? app
        }
    }

    // MARK: - Actions

    /// Clicking a badge opens its app (spec B-6).
    func open(_ app: BadgeApp) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    // MARK: - Own icons (spec B-3)

    static var iconFolder: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent("Dynotch/BadgeIcons", isDirectory: true)
    }

    /// Copies the chosen image into the app's folder and uses it as the icon.
    func importIcon(for bundleID: String, from url: URL) {
        let folder = Self.iconFolder
        let name = UUID().uuidString + "." + (url.pathExtension.isEmpty ? "png" : url.pathExtension)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: folder.appendingPathComponent(name))
            setIcon(bundleID, .custom(name))
        } catch {
            NSSound.beep()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(apps) { defaults.set(data, forKey: Self.appsKey) }
    }
}
