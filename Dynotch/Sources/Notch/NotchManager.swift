import AppKit

/// Keeps one notch panel on every connected display and rebuilds them when displays change.
@MainActor
final class NotchManager {
    private let services: AppServices
    private let openSettings: () -> Void
    private var controllers: [NotchController] = []
    private var screenObserver: NSObjectProtocol?
    private var signature = ""

    init(services: AppServices, openSettings: @escaping () -> Void) {
        self.services = services
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
            NotchController(screen: $0, services: services, openSettings: openSettings)
        }
        controllers.forEach { $0.start() }
    }
}
