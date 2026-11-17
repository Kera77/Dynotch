import AppKit

/// Keeps one notch panel on every connected display and rebuilds them when displays change.
@MainActor
final class NotchManager {
    private let services: AppServices
    private let openSettings: () -> Void
    private var controllers: [NotchController] = []
    private var screenObserver: NSObjectProtocol?
    private var signature = ""
    private var spaceSwipes: SpaceSwipeMonitor?

    init(services: AppServices, openSettings: @escaping () -> Void) {
        self.services = services
        self.openSettings = openSettings
    }

    func start() {
        rebuildIfNeeded()
        let monitor = SpaceSwipeMonitor { [weak self] phase in
            self?.spaceSwipe(phase)
        }
        monitor.start()
        spaceSwipes = monitor
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildIfNeeded() }
        }
    }

    /// A shortcut opens the feature on the display the pointer is on (spec SC-1).
    func open(_ feature: FeatureID, pinned: Bool) {
        let pointer = NSEvent.mouseLocation
        let controller = controllers.first { $0.model.geometry.screenFrame.contains(pointer) } ?? controllers.first
        controller?.toggle(feature, pinned: pinned)
    }

    /// The pin shortcut (spec SC-3).
    func togglePin() {
        let pointer = NSEvent.mouseLocation
        let controller = controllers.first { $0.model.isExpanded }
            ?? controllers.first { $0.model.geometry.screenFrame.contains(pointer) } ?? controllers.first
        controller?.togglePin()
    }

    /// The swipe moves the Spaces of the display under the pointer, or of every display when
    /// they share their Spaces.
    private func spaceSwipe(_ phase: SpaceSwipe.Phase) {
        let pointer = NSEvent.mouseLocation
        let affected = NSScreen.screensHaveSeparateSpaces
            ? controllers.filter { $0.model.geometry.screenFrame.contains(pointer) }
            : controllers
        for controller in affected {
            switch phase {
            case .began: controller.spaceSwipeBegan()
            case .ended: controller.spaceSwipeEnded()
            case .changed: break
            }
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
