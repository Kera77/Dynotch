import AppKit
import ApplicationServices
import Observation

/// Unread counts of the chosen apps, read from their Dock badges (spec B-1…B-7).
@MainActor
@Observable
final class BadgeService {
    private static let appsKey = "badgeApps"
    private static let brandIconsKey = "badgeBrandIcons"
    private static let hiddenKey = "badgeHidden"
    private static let interval: TimeInterval = 2

    /// The chosen apps in the order they stand beside the notch.
    private(set) var apps: [BadgeApp] {
        didSet { save() }
    }

    /// Badge text per bundle identifier; only apps with a badge.
    private(set) var labels: [String: String] = [:]
    private(set) var pulses: [String: Date] = [:]
    /// Badges taken out of the notch for a while, by bundle identifier (spec B-11).
    private(set) var hidden: [String: BadgeHide] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(hidden) { defaults.set(data, forKey: Self.hiddenKey) }
        }
    }
    /// A count from elsewhere than the Dock: Gmail's from Mail (spec GM-7); "" hides the badge.
    @ObservationIgnored var labelOverride: (BadgeApp) -> String? = { _ in nil }
    /// The highlighted Beeper networks (spec BP-13) and one network's unread count (spec BP-14).
    @ObservationIgnored var beeperNetworks: () -> [String] = { [] }
    @ObservationIgnored var beeperNetworkUnread: (String) -> Int = { _ in 0 }
    @ObservationIgnored var removeBeeperNetwork: (String) -> Void = { _ in }
    /// Reading the Dock needs Accessibility access.
    private(set) var isTrusted = true

    private let defaults: UserDefaults
    @ObservationIgnored private var poller: Poller?
    @ObservationIgnored private var isReading = false
    /// The first reading only records what is there: old badges are not new notifications.
    @ObservationIgnored private var hasBaseline = false
    @ObservationIgnored private var bundleIDs: [String: String] = [:]
    @ObservationIgnored private var loggedSignature = ""
    /// Unread counts from the default browser's Gmail and Google Chat tabs, by site (spec B-2b, B-2c).
    @ObservationIgnored private var tabCounts: [String: Int] = [:]
    @ObservationIgnored private var isReadingTabs = false
    @ObservationIgnored private var lastTabRead = Date.distantPast
    @ObservationIgnored private var loggedTabs = ""
    /// The badges beside the notch as last told, to tell the menu bar measuring (spec RF-12).
    @ObservationIgnored private var visibleSignature = ""
    /// The badges beside the notch changed: which, or their text.
    @ObservationIgnored var onVisibleChange: () -> Void = {}
    private static let tabInterval: TimeInterval = 6

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
        hidden = defaults.data(forKey: Self.hiddenKey)
            .flatMap { try? JSONDecoder().decode([String: BadgeHide].self, from: $0) } ?? [:]
        save()
    }

    /// Enabled apps that have a badge now.
    var visible: [BadgeItem] {
        apps.compactMap { app in
            let override = BeeperNetworkBadge.network(fromBadgeID: app.bundleID) == nil ? labelOverride(app) : nil
            guard app.isEnabled, hidden[app.bundleID] == nil, let label = override ?? labels[app.bundleID], !label.isEmpty
            else { return nil }
            return BadgeItem(app: app, label: label, pulseStart: pulses[app.bundleID])
        }
    }

    /// The Dock is read only while an app's badge is chosen (spec RF-8).
    func start() {
        guard poller == nil else { return }
        let poller = Poller(
            every: Self.interval, isActive: { [weak self] in self?.isWatching ?? false }, action: { [weak self] in self?.refresh() }
        )
        // Turned off: the badges go away.
        poller.onInactive = { [weak self] in self?.refresh() }
        poller.start()
        self.poller = poller
        refresh()
    }

    private var isWatching: Bool {
        apps.contains(where: \.isEnabled) || !beeperNetworks().isEmpty
    }

    private func notifyIfVisibleChanged() {
        let signature = visible.map { "\($0.app.bundleID)=\($0.label)" }.joined(separator: ",")
        guard signature != visibleSignature else { return }
        visibleSignature = signature
        onVisibleChange()
    }

    func refresh() {
        let synced = BeeperNetworkBadge.synced(apps, networks: beeperNetworks())
        if synced != apps { apps = synced }
        guard apps.contains(where: \.isEnabled) else {
            apply([:], now: Date())
            return
        }
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
        readTabsIfDue()
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

    /// The default browser's tab titles every few seconds, only while it runs (spec B-2b, B-2c).
    private func readTabsIfDue() {
        let now = Date()
        let interval = Poller.scaled(Self.tabInterval, factor: Poller.slowFactor, scales: true)
        guard !isReadingTabs, now.timeIntervalSince(lastTabRead) >= interval,
              apps.contains(where: { $0.isEnabled && BrowserTabBadges.site(forBadgeName: $0.name) != nil })
        else { return }
        isReadingTabs = true
        lastTabRead = now
        Task { [weak self] in
            let tabs = await BrowserTabBadges.read()
            guard let self else { return }
            self.isReadingTabs = false
            let counts = tabs.map(BrowserTabBadges.counts(from:)) ?? [:]
            let signature = counts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            if signature != self.loggedTabs {
                self.loggedTabs = signature
                DiagnosticsLog.append("badges", "Browser tabs: \(signature.isEmpty ? "none" : signature)")
            }
            self.tabCounts = counts
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
        // An open Gmail or Google Chat tab in the default browser knows better than a web app's Dock badge,
        // which stays on the last number once the web app quits (spec B-2b).
        for app in apps where app.isEnabled && BeeperNetworkBadge.network(fromBadgeID: app.bundleID) == nil {
            guard let site = BrowserTabBadges.site(forBadgeName: app.name), let count = tabCounts[site] else { continue }
            result[app.bundleID] = count > 0 ? String(count) : nil
        }
        // Highlighted Beeper networks count their own chats, and Beeper's badge the rest (spec BP-14).
        var highlighted = 0
        for app in apps where app.isEnabled {
            guard let network = BeeperNetworkBadge.network(fromBadgeID: app.bundleID) else { continue }
            let count = beeperNetworkUnread(network)
            highlighted += count
            result[app.bundleID] = count > 0 ? String(count) : nil
        }
        for app in apps where app.isEnabled && BeeperNetworkBadge.network(fromBadgeID: app.bundleID) == nil
            && app.bundleID.lowercased().contains("beeper") {
            result[app.bundleID] = BeeperNetworkBadge.remainder(result[app.bundleID], minus: highlighted)
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
        let stillHidden = BadgeHide.remaining(hidden, labels: current, now: now)
        if stillHidden != hidden { hidden = stillHidden }
        notifyIfVisibleChanged()
    }

    /// Takes a badge out of the notch for a while (spec B-11).
    func hide(_ bundleID: String, _ choice: BadgeHide.Choice, now: Date = Date()) {
        hidden[bundleID] = BadgeHide.make(choice, label: labels[bundleID] ?? "", now: now)
        acknowledge(bundleID)
        notifyIfVisibleChanged()
    }

    /// Back beside the notch (spec B-11).
    func unhide(_ bundleID: String) {
        hidden[bundleID] = nil
        notifyIfVisibleChanged()
    }

    /// The pointer was on the badge: it was noticed, so it stops pulsing (spec B-5).
    func acknowledge(_ bundleID: String) {
        if pulses[bundleID] != nil { pulses[bundleID] = nil }
    }

    // MARK: - Choosing apps (spec B-1, B-3)

    /// Added with the icon chosen in its row, else the suggested one (spec B-13).
    func add(_ app: InstalledApp, icon chosen: BadgeIcon? = nil) {
        guard !apps.contains(where: { $0.bundleID == app.bundleID }) else { return }
        let icon = chosen ?? BadgePreset.suggestedIcon(bundleID: app.bundleID, name: app.name)
        apps.append(BadgeApp(bundleID: app.bundleID, name: app.name, isEnabled: true, icon: icon))
        refresh()
    }

    func remove(_ bundleID: String) {
        // A highlighted Beeper network's badge goes with its highlight (spec BP-14).
        if let network = BeeperNetworkBadge.network(fromBadgeID: bundleID) { removeBeeperNetwork(network) }
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
