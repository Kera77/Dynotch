import AppKit
import CoreAudio
import DiskArbitration
import IOBluetooth
import Observation

/// A device that came or went (spec DV-1…DV-4).
struct DeviceEvent: Identifiable, Equatable {
    enum Category: String, CaseIterable, Sendable {
        case bluetooth
        case usb
        case display
        case drive
        case audio

        var title: String {
            switch self {
            case .bluetooth: "Bluetooth devices"
            case .usb: "USB devices"
            case .display: "Displays"
            case .drive: "Drives and disk images"
            case .audio: "Sound output"
            }
        }
    }

    enum Action: Equatable {
        case eject(URL)
        case open(URL)
        case useForAudio(String)
        case displaySettings
        /// The macOS banner's own button ("Move to iPhone"), done here (spec DV-10).
        case bluetoothButton(title: String, device: String)
    }

    let id = UUID()
    let category: Category
    let name: String
    let symbol: String
    let isConnected: Bool
    var detail: String?
    var actions: [Action] = []
    /// Each earbud, the case, or the one level (spec DV-8b).
    var levels: [DeviceLevel] = []

    static func == (lhs: DeviceEvent, rhs: DeviceEvent) -> Bool {
        lhs.id == rhs.id && lhs.detail == rhs.detail && lhs.levels == rhs.levels && lhs.actions == rhs.actions
    }
}

/// Watches Bluetooth, USB, displays, drives and the sound output; shows each change under the
/// notch for a few seconds (spec DV-1…DV-7).
@MainActor
@Observable
final class DeviceWatcher: NSObject {
    private(set) var current: DeviceEvent?

    var isOn: Bool { didSet { defaults.set(isOn, forKey: Keys.isOn) } }
    var showsDisconnects: Bool { didSet { defaults.set(showsDisconnects, forKey: Keys.disconnects) } }
    private(set) var categoriesOff: Set<DeviceEvent.Category> {
        didSet { defaults.set(categoriesOff.map(\.rawValue), forKey: Keys.off) }
    }

    private enum Keys {
        static let isOn = "devicesOn"
        static let disconnects = "devicesDisconnects"
        static let off = "devicesCategoriesOff"
    }

    private static let quietTime: TimeInterval = 30
    private static let flapTime: TimeInterval = 10
    private static let repeatTime: TimeInterval = 30 * 60

    private let settings: AppSettings
    private let defaults: UserDefaults
    @ObservationIgnored private var quietUntil = Date().addingTimeInterval(quietTime)
    @ObservationIgnored private var lastSeen: [String: Date] = [:]
    /// Bluetooth devices connected without a disconnect since, and when (spec DV-12).
    @ObservationIgnored private var bluetoothConnectedAt: [String: Date] = [:]
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var screens: Set<String> = []
    @ObservationIgnored private var audioOutput: String?
    @ObservationIgnored private var bluetoothNotification: IOBluetoothUserNotification?
    private let usb = USBWatcher()
    private let banners = BluetoothBannerWatcher()

    init(settings: AppSettings, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
        isOn = defaults.object(forKey: Keys.isOn) as? Bool ?? true
        showsDisconnects = defaults.object(forKey: Keys.disconnects) as? Bool ?? true
        categoriesOff = Set((defaults.stringArray(forKey: Keys.off) ?? []).compactMap(DeviceEvent.Category.init(rawValue:)))
        super.init()
    }

    func shows(_ category: DeviceEvent.Category) -> Bool { !categoriesOff.contains(category) }

    func setShows(_ category: DeviceEvent.Category, enabled: Bool) {
        if enabled { categoriesOff.remove(category) } else { categoriesOff.insert(category) }
    }

    // MARK: - Watching

    func start() {
        screens = Set(NSScreen.screens.map(\.localizedName))
        audioOutput = AudioOutputs.defaultOutputName()
        bluetoothNotification = IOBluetoothDevice.register(
            forConnectNotifications: self, selector: #selector(bluetoothConnected(_:device:))
        )
        let workspace = NSWorkspace.shared.notificationCenter
        observers = [
            workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.quietUntil = Date().addingTimeInterval(Self.quietTime) }
            },
            workspace.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] note in
                let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
                MainActor.assumeIsolated { if let url { self?.volume(url, mounted: true) } }
            },
            workspace.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] note in
                let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
                MainActor.assumeIsolated { if let url { self?.volume(url, mounted: false) } }
            },
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.screensChanged() }
            }
        ]
        usb.start { [weak self] name, added in self?.usbChanged(name, added: added) }
        banners.isEnabled = { [weak self] in self?.hidesBluetoothBanners ?? false }
        banners.onCatch = { [weak self] in self?.bannerCaught($0) }
        if hidesBluetoothBanners { banners.start() }
        AudioOutputs.watchDefault { [weak self] in self?.audioChanged() }
    }

    // IOBluetooth calls these on its own queue, not the main one: touching main-actor state here
    // stopped the app (0.42.1). Only the name crosses over, on the main queue.
    @objc nonisolated private func bluetoothConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(bluetoothDisconnected(_:device:)))
        let name = device.name ?? "Bluetooth device"
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.bluetooth(name, connected: true) }
        }
    }

    @objc nonisolated private func bluetoothDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        let name = device.name ?? "Bluetooth device"
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.bluetooth(name, connected: false) }
        }
    }

    private func bluetooth(_ name: String, connected: Bool) {
        let now = Date()
        // A device that reconnects again and again without going away: one notice in 30 min.
        if connected {
            defer { bluetoothConnectedAt[name] = now }
            if BluetoothRepeat.isRepeat(since: bluetoothConnectedAt[name], now: now, window: Self.repeatTime) {
                DiagnosticsLog.append("devices", "bluetooth connected again, not shown")
                return
            }
        } else {
            bluetoothConnectedAt[name] = nil
        }
        let kind = BatteryDevice.Kind.detect(name)
        var event = DeviceEvent(category: .bluetooth, name: name, symbol: DeviceSymbols.symbol(for: kind), isConnected: connected)
        if connected, kind == .earbuds || kind == .headphones, AudioOutputs.defaultOutputName() != name {
            event.actions = [.useForAudio(name)]
        }
        show(event, key: "bt:" + name)
        // macOS's own banner about it is closed; the notch says it instead (spec DV-9).
        if hidesBluetoothBanners { banners.expect(name) }
        guard connected else { return }
        // The levels arrive a moment after the connection: asked a few times (spec DV-8b).
        Task { [weak self] in
            for wait in [1.0, 1, 1, 2, 3] {
                try? await Task.sleep(for: .seconds(wait))
                let found = await Task.detached { DeviceBattery.structuredLevels(named: name) }.value
                guard let self, self.current?.name == name else { return }
                guard !found.isEmpty else { continue }
                self.current?.levels = found
                // Shown long enough to read, from when they arrived.
                self.keepShowing()
                return
            }
        }
    }

    private var hidesBluetoothBanners: Bool { isOn && shows(.bluetooth) && settings.hideNativeBanners }

    /// A macOS Bluetooth banner was closed: its button moves to the notch, in blue (spec DV-10).
    private func bannerCaught(_ caught: BluetoothBannerWatcher.Caught) {
        guard let title = caught.callToAction else { return }
        let action = DeviceEvent.Action.bluetoothButton(title: title, device: caught.deviceName)
        if current?.category == .bluetooth, current?.name == caught.deviceName {
            current?.actions = [action]
        } else {
            let kind = BatteryDevice.Kind.detect(caught.deviceName)
            let connected = BluetoothConnection.isConnected(caught.deviceName)
            current = DeviceEvent(
                category: .bluetooth, name: caught.deviceName, symbol: DeviceSymbols.symbol(for: kind), isConnected: connected,
                actions: [action]
            )
        }
        keepShowing()
    }

    private func volume(_ url: URL, mounted: Bool) {
        let keys: Set<URLResourceKey> = [.volumeIsInternalKey, .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        let values = try? url.resourceValues(forKeys: keys)
        let isImage = DiskImages.isDiskImage(url)
        guard values?.volumeIsInternal != true || isImage else { return }
        let name = values?.volumeName ?? url.lastPathComponent
        var event = DeviceEvent(
            category: .drive, name: name, symbol: isImage ? "opticaldiscdrive.fill" : "externaldrive.fill", isConnected: mounted
        )
        if mounted {
            event.detail = DiskImages.sizeText(total: values?.volumeTotalCapacity, free: values?.volumeAvailableCapacity, isImage: isImage)
            event.actions = [.open(url), .eject(url)]
        }
        show(event, key: "drive:" + name)
    }

    private func screensChanged() {
        let now = Set(NSScreen.screens.map(\.localizedName))
        for added in now.subtracting(screens) {
            let event = DeviceEvent(category: .display, name: added, symbol: "display", isConnected: true, actions: [.displaySettings])
            show(event, key: "display:" + added)
        }
        for removed in screens.subtracting(now) {
            show(DeviceEvent(category: .display, name: removed, symbol: "display", isConnected: false), key: "display:" + removed)
        }
        screens = now
    }

    private func usbChanged(_ name: String, added: Bool) {
        show(DeviceEvent(category: .usb, name: name, symbol: DeviceSymbols.usbSymbol(for: name), isConnected: added), key: "usb:" + name)
    }

    private func audioChanged() {
        let name = AudioOutputs.defaultOutputName()
        defer { audioOutput = name }
        guard let name, name != audioOutput else { return }
        // Headphones just connected: their notice stays, with the levels (spec DV-8b).
        if current?.category == .bluetooth, current?.name == name {
            current?.actions.removeAll { if case .useForAudio = $0 { true } else { false } }
            return
        }
        let event = DeviceEvent(
            category: .audio, name: name, symbol: "speaker.wave.2.fill", isConnected: true, detail: "Sound now plays here"
        )
        show(event, key: "audio:" + name)
    }

    // MARK: - Showing (spec DV-5, DV-6)

    private func show(_ event: DeviceEvent, key: String) {
        let now = Date()
        defer { lastSeen[key] = now }
        guard isOn, shows(event.category), event.isConnected || showsDisconnects, now >= quietUntil else { return }
        // The same device going and coming again within seconds: one notice.
        if let last = lastSeen[key], now.timeIntervalSince(last) < Self.flapTime { return }
        DiagnosticsLog.append("devices", "\(event.category.rawValue) \(event.isConnected ? "connected" : "disconnected")")
        current = event
        RecentNotice.shared.note(.battery, id: "device:" + key)
        keepShowing()
    }

    /// Hides the notice after the notification time, counted from now.
    private func keepShowing() {
        hideTask?.cancel()
        let duration = settings.notificationDuration
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        hideTask?.cancel()
        current = nil
    }

    func perform(_ action: DeviceEvent.Action) {
        switch action {
        case .eject(let url):
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                dismiss()
            } catch {
                current?.detail = "Could not eject: it is in use"
            }
        case .open(let url):
            NSWorkspace.shared.open(url)
        case .useForAudio(let name):
            AudioOutputs.setDefaultOutput(named: name)
            dismiss()
        case .bluetoothButton(_, let device):
            dismiss()
            Task.detached { BluetoothConnection.toggle(device) }
        case .displaySettings:
            if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") { NSWorkspace.shared.open(url) }
        }
    }
}

/// Connecting and disconnecting a paired Bluetooth device by name (spec DV-10).
enum BluetoothConnection {
    nonisolated static func isConnected(_ name: String) -> Bool {
        device(named: name)?.isConnected() ?? false
    }

    /// "Move to iPhone" lets the device go from this Mac; "Connect" / "Move to Mac" takes it here.
    nonisolated static func toggle(_ name: String) {
        guard let device = device(named: name) else { return }
        let result = device.isConnected() ? device.closeConnection() : device.openConnection()
        DiagnosticsLog.append("devices", "bluetooth button: \(device.isConnected() ? "connected" : "disconnected") result=\(result)")
    }

    nonisolated private static func device(named name: String) -> IOBluetoothDevice? {
        ((IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []).first { $0.name == name }
    }
}

/// A Bluetooth connection without a disconnect since the previous one (spec DV-12).
enum BluetoothRepeat {
    static func isRepeat(since previous: Date?, now: Date, window: TimeInterval) -> Bool {
        guard let previous else { return false }
        return now.timeIntervalSince(previous) < window
    }
}
