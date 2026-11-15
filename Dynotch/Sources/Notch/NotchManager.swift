import AppKit

/// Keeps one notch panel on every connected display and rebuilds them when displays change.
@MainActor
final class NotchManager {
    private let settings: AppSettings
    private let calendar: CalendarService
    private let openSettings: () -> Void
    private var controllers: [NotchController] = []
    private var screenObserver: NSObjectProtocol?
    private var signature = ""

    init(settings: AppSettings, calendar: CalendarService, openSettings: @escaping () -> Void) {
        self.settings = settings
        self.calendar = calendar
        self.openSettings = openSettings
    }

    func start() {
        rebuildIfNeeded()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildIfNeeded() }
        }
    }

    private func rebuildIfNeeded() {
        let screens = NSScreen.screens
        let newSignature = screens
            .map { "\($0.frame)|\($0.visibleFrame.maxY)|\($0.safeAreaInsets.top)" }
            .joined(separator: ";")
        guard newSignature != signature else { return }
        signature = newSignature

        controllers.forEach { $0.stop() }
        controllers = screens.map {
            NotchController(screen: $0, settings: settings, calendar: calendar, openSettings: openSettings)
        }
        controllers.forEach { $0.start() }
    }
}
