import AppKit
import Combine
import EventKit

/// Reads events for the next 7 days from macOS Calendar (iCloud, Google, Exchange… whatever
/// is configured in System Settings › Internet Accounts) and tracks the upcoming event.
@MainActor
final class CalendarService: ObservableObject {
    enum Access: Equatable {
        case notDetermined
        case granted
        case denied
    }

    @Published private(set) var access: Access
    @Published private(set) var days: [AgendaDay] = []
    @Published private(set) var upcoming: CalendarEvent?
    @Published private(set) var now = Date()

    private let store = EKEventStore()
    private let settings: AppSettings
    private var events: [CalendarEvent] = []
    private var storeObserver: NSObjectProtocol?
    private var tickTimer: Timer?
    private var lastFetch: Date?
    private var settingsObserver: AnyCancellable?

    private static let refetchInterval: TimeInterval = 5 * 60
    private static let tickInterval: TimeInterval = 15

    init(settings: AppSettings) {
        self.settings = settings
        access = Self.currentAccess()
    }

    func start() {
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fetch() }
        }

        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer

        settingsObserver = settings.objectWillChange.sink { [weak self] in
            // objectWillChange fires before the value changes; recompute on the next runloop turn.
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.recompute() }
            }
        }

        if access == .notDetermined, settings.isEnabled(.calendar) {
            requestAccess()
        } else {
            fetch()
        }
    }

    /// Asks for Calendar access, or opens System Settings if it was denied before.
    func requestAccess() {
        switch Self.currentAccess() {
        case .granted:
            access = .granted
            fetch()
        case .denied:
            openPrivacySettings()
        case .notDetermined:
            NSApp.activate()
            store.requestFullAccessToEvents { [weak self] _, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.access = Self.currentAccess()
                    self.store.reset()
                    self.fetch()
                }
            }
        }
    }

    /// Called when the panel opens so the list is fresh.
    func refreshIfStale() {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < 60 {
            tick()
        } else {
            fetch()
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func join(_ event: CalendarEvent) {
        guard let url = event.meetingURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private func fetch() {
        access = Self.currentAccess()
        guard access == .granted else {
            events = []
            recompute()
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: CalendarAgenda.dayCount, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .map(Self.makeEvent)
        lastFetch = Date()
        recompute()
    }

    private func tick() {
        if let lastFetch, Date().timeIntervalSince(lastFetch) > Self.refetchInterval {
            fetch()
        } else {
            recompute()
        }
    }

    private func recompute() {
        let now = Date()
        self.now = now
        let newDays = CalendarAgenda.days(from: events, now: now)
        if newDays != days { days = newDays }

        let newUpcoming = settings.calendarAlertEnabled && settings.isEnabled(.calendar)
            ? CalendarAgenda.upcoming(in: events, now: now, leadTime: TimeInterval(settings.calendarLeadMinutes * 60))
            : nil
        if newUpcoming != upcoming { upcoming = newUpcoming }
    }

    private static func makeEvent(_ event: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)",
            title: event.title?.isEmpty == false ? event.title : "(Névtelen esemény)",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            color: color(of: event.calendar),
            meetingURL: MeetingLink.find(url: event.url, texts: [event.location, event.notes])
        )
    }

    private static func color(of calendar: EKCalendar?) -> CalendarColor {
        guard let cgColor = calendar?.cgColor,
              let rgb = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB)
        else { return .fallback }
        return CalendarColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
    }
}
