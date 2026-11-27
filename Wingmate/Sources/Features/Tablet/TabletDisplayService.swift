import AppKit
import Observation

/// An iPad as an external display, from the panel's top row (spec TB-1…TB-4).
@MainActor
@Observable
final class TabletDisplayService {
    struct Tablet: Identifiable, Equatable {
        let id: String
        let name: String
        let isConnected: Bool
    }

    private(set) var tablets: [Tablet] = []
    /// The connected iPad shows the main display instead of extending the desktop.
    private(set) var isMirrored = false
    /// The iPad being connected or disconnected.
    private(set) var pending: String?
    /// Why the last action failed.
    private(set) var failure: String?
    /// iPads the keyboard and mouse were linked to from the menu (spec TB-7); ticked there.
    private(set) var linkedKeyboards: Set<String> = []

    @ObservationIgnored private var screenObserver: NSObjectProtocol?
    /// Mirror once the iPad being connected is there.
    @ObservationIgnored private var mirrorsWhenConnected = false
    private static let displayWait: TimeInterval = 6

    var connected: Tablet? { tablets.first(where: \.isConnected) }

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        let connectedIDs = Set(SidecarBridge.devices("connectedDevices").compactMap(SidecarBridge.identifier(of:)))
        let found = SidecarBridge.devices("devices").compactMap { device -> Tablet? in
            guard let id = SidecarBridge.identifier(of: device) else { return nil }
            return Tablet(id: id, name: SidecarBridge.name(of: device), isConnected: connectedIDs.contains(id))
        }
        if found != tablets { tablets = found }
        let mirrored = SidecarDisplay.displayID().map(SidecarDisplay.isMirrored) ?? false
        if mirrored != isMirrored { isMirrored = mirrored }
    }

    /// Extends the desktop onto the iPad, or mirrors the main display on it.
    func connect(_ tablet: Tablet, mirrored: Bool = false) {
        mirrorsWhenConnected = mirrored
        run("connectToDevice:completion:", on: tablet)
    }

    func disconnect(_ tablet: Tablet) {
        mirrorsWhenConnected = false
        run("disconnectFromDevice:completion:", on: tablet)
    }

    func setMirrored(_ mirrored: Bool) {
        guard let display = SidecarDisplay.displayID() else { return }
        if !SidecarDisplay.setMirrored(mirrored, display: display) {
            failure = "The display arrangement could not be changed."
        }
        refresh()
    }

    /// Links (or unlinks) the keyboard and mouse to the iPad through the Displays settings (spec TB-6).
    func linkKeyboard(to tablet: Tablet) {
        guard pending == nil else { return }
        pending = tablet.id
        failure = nil
        Task { [weak self] in
            let outcome = await UniversalControlLink.link(named: tablet.name)
            self?.pending = nil
            self?.failure = outcome.failure
            if let linked = outcome.linked {
                if linked { self?.linkedKeyboards.insert(tablet.id) } else { self?.linkedKeyboards.remove(tablet.id) }
            }
        }
    }

    func openDisplaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private func run(_ selector: String, on tablet: Tablet) {
        guard pending == nil,
              let device = SidecarBridge.devices("devices").first(where: { SidecarBridge.identifier(of: $0) == tablet.id })
        else { return }
        pending = tablet.id
        failure = nil
        let started = SidecarBridge.perform(selector, device: device) { [weak self] message in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.finish(failure: message) }
            }
        }
        if !started { finish(failure: "This Mac does not offer Sidecar.") }
        DiagnosticsLog.append("tablet", "\(selector) started=\(started)")
    }

    private func finish(failure message: String?) {
        pending = nil
        failure = message
        if let message { DiagnosticsLog.append("tablet", "failed: \(message)") }
        refresh()
        if message == nil, mirrorsWhenConnected {
            mirrorsWhenConnected = false
            waitForDisplay(mirrored: true, deadline: Date().addingTimeInterval(Self.displayWait))
        }
    }

    /// The iPad's display appears a moment after connecting; mirror it once it is there.
    private func waitForDisplay(mirrored: Bool, deadline: Date) {
        if SidecarDisplay.displayID() != nil {
            setMirrored(mirrored)
            return
        }
        guard Date() < deadline else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.waitForDisplay(mirrored: mirrored, deadline: deadline)
        }
    }
}
