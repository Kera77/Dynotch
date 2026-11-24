import CoreLocation
import Foundation
import Observation

/// The weather for the Calendar's Weather tab and the morning forecast (spec WX-1…WX-8).
@MainActor
@Observable
final class WeatherService {
    static let shared = WeatherService()

    enum Status: Equatable, Sendable {
        case idle
        case loading
        /// Location Services are off for Dynotch, or no city is chosen (spec WX-2).
        case needsPlace
        case denied
        case failed
    }

    private(set) var forecast: WeatherForecast?
    private(set) var placeName = ""
    private(set) var status = Status.idle

    @ObservationIgnored private var appSettings: AppSettings?
    @ObservationIgnored private var notices: NoticeService?
    @ObservationIgnored private var poller: Poller?
    @ObservationIgnored private let locator = WeatherLocator()
    @ObservationIgnored private var loading: Task<Bool, Never>?
    @ObservationIgnored private var observer: ChangeObservation?

    var settings: WeatherSettings { .shared }

    /// Every 30 minutes (spec WX-4); older than 15 minutes counts as stale.
    nonisolated static let interval: TimeInterval = 30 * 60
    nonisolated static let staleAfter: TimeInterval = 15 * 60

    func start(settings appSettings: AppSettings, notices: NoticeService) {
        self.appSettings = appSettings
        self.notices = notices
        loadCached()
        poller = Poller.start(
            every: Self.interval, isActive: { [weak self] in self?.isActive == true },
            action: { [weak self] in
                Task { await self?.refresh() }
                self?.checkMorning()
            }
        )
        poller?.reevaluate()
        PowerMonitor.shared.listeners.append { [weak self] old, new in
            // The first unlock or wake of the day (spec WX-7).
            if old.isPaused, !new.isPaused { self?.checkMorning() }
        }
        // A new place or the switch: look again at once.
        observer = observeChanges { [settings] in
            _ = settings.city
            _ = settings.usesLocation
            _ = settings.places
            _ = settings.isOn
        } onChange: { [weak self] in
            guard let self, self.isActive else { return }
            Task { await self.refresh() }
        }
        checkMorning()
        refreshIfStale()
    }

    /// The tab is on and the calendar too (spec WX-1).
    var isActive: Bool {
        settings.isOn && appSettings?.isEnabled(.calendar) == true
    }

    /// When the tab opens (spec WX-4).
    func refreshIfStale() {
        guard isActive else { return }
        if let fetched = forecast?.fetched, Date().timeIntervalSince(fetched) < Self.staleAfter { return }
        Task { await refresh() }
    }

    /// Asks for the place first when Location Services are used (spec WX-2).
    func useMyLocation() {
        settings.usesLocation = true
        locator.requestAccess()
        Task { await refresh() }
    }

    @discardableResult
    func refresh() async -> Bool {
        if let loading { return await loading.value }
        let task = Task { await load() }
        loading = task
        let done = await task.value
        loading = nil
        return done
    }

    private func load() async -> Bool {
        guard isActive else { return false }
        status = .loading
        guard let place = await currentPlace() else {
            // Never left spinning: the empty state says what is missing (spec WX-10).
            if status == .loading { status = .needsPlace }
            return false
        }
        placeName = place.name
        let imperial = Locale.current.measurementSystem == .us
        guard let url = OpenMeteo.forecastURL(latitude: place.latitude, longitude: place.longitude, imperial: imperial),
              let data = await Self.fetch(url),
              let fresh = OpenMeteo.forecast(from: data, fetched: Date())
        else {
            DiagnosticsLog.append("weather", "forecast not loaded")
            status = .failed
            return false
        }
        forecast = fresh
        status = .idle
        saveCached()
        return true
    }

    private func currentPlace() async -> WeatherPlace? {
        if !settings.usesLocation {
            guard let city = settings.city else {
                status = .needsPlace
                return nil
            }
            return city
        }
        switch locator.access {
        case .denied:
            // The chosen saved place stands in (spec WX-9).
            DiagnosticsLog.append("weather", "location access denied")
            if settings.city == nil { status = .denied }
            return settings.city
        case .notDetermined:
            locator.requestAccess()
        case .allowed:
            break
        }
        guard let found = await locator.place() else {
            if settings.city == nil { status = locator.access == .denied ? .denied : .needsPlace }
            return settings.city
        }
        return found
    }

    nonisolated static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Dynotch", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }

    /// Places by name for Settings (spec WX-2).
    nonisolated static func search(_ name: String) async -> [WeatherPlace] {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, let url = OpenMeteo.searchURL(trimmed), let data = await fetch(url) else { return [] }
        return OpenMeteo.places(from: data)
    }

    // MARK: - Cache: the last forecast shows offline (spec WX-4)

    private func saveCached() {
        guard let forecast else { return }
        UserDefaults.standard.set(try? JSONEncoder().encode(forecast), forKey: "weatherForecast")
        UserDefaults.standard.set(placeName, forKey: "weatherPlaceName")
    }

    private func loadCached() {
        let data = UserDefaults.standard.data(forKey: "weatherForecast")
        forecast = data.flatMap { try? JSONDecoder().decode(WeatherForecast.self, from: $0) }
        placeName = UserDefaults.standard.string(forKey: "weatherPlaceName") ?? ""
    }

    // MARK: - Morning forecast (spec WX-7, WX-8)

    private var lastMorning: String {
        get { UserDefaults.standard.string(forKey: "weatherLastMorning") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "weatherLastMorning") }
    }

    func checkMorning(now: Date = Date()) {
        guard isActive, settings.morningOn, !PowerMonitor.shared.conditions.isPaused else { return }
        let today = PomodoroHistory.key(for: now)
        let minutes = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        guard lastMorning != today, minutes >= settings.morningNotBefore else { return }
        lastMorning = today
        Task {
            // Fresh data first, waiting up to a minute for the network (spec WX-8).
            var loaded = await refresh()
            for _ in 0..<5 where !loaded {
                try? await Task.sleep(for: .seconds(12))
                loaded = await refresh()
            }
            guard loaded, let forecast else { return }
            showMorning(forecast, now: Date())
        }
    }

    private func showMorning(_ forecast: WeatherForecast, now: Date) {
        let today = forecast.today
        var detail = WeatherCode.text(forecast.now.code)
        if let today { detail += " · H \(Self.degrees(today.high)) L \(Self.degrees(today.low))" }
        if let (start, end) = MorningRain.window(in: forecast.hours, on: now) {
            let from = start.formatted(date: .omitted, time: .shortened)
            detail += " · Rain likely \(from)–\(end.formatted(date: .omitted, time: .shortened))"
        }
        let title = (placeName.isEmpty ? "" : "\(placeName) · ") + Self.degrees(forecast.now.temperature)
        notices?.show(StickyNotice(
            title: title, detail: detail, date: now, symbol: WeatherCode.symbol(forecast.now.code, isDay: forecast.now.isDay),
            sourceName: "Weather", opens: .weather, stays: appSettings?.notificationDuration ?? 8
        ))
    }

    nonisolated static func degrees(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }
}
