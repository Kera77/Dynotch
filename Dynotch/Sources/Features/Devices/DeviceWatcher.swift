import AppKit
import Combine
import CoreAudio
import DiskArbitration
import IOBluetooth

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
    }

    let id = UUID()
    let category: Category
    let name: String
    let symbol: String
    let isConnected: Bool
    var detail: String?
    var actions: [Action] = []

    static func == (lhs: DeviceEvent, rhs: DeviceEvent) -> Bool { lhs.id == rhs.id && lhs.detail == rhs.detail }
}

/// Watches Bluetooth, USB, displays, drives and the sound output; shows each change under the
/// notch for a few seconds (spec DV-1…DV-7).
@MainActor
final class DeviceWatcher: NSObject, ObservableObject {
    @Published private(set) var current: DeviceEvent?

    @Published var isOn: Bool { didSet { defaults.set(isOn, forKey: Keys.isOn) } }
    @Published var showsDisconnects: Bool { didSet { defaults.set(showsDisconnects, forKey: Keys.disconnects) } }
    @Published private(set) var categoriesOff: Set<DeviceEvent.Category> {
        didSet { defaults.set(categoriesOff.map(\.rawValue), forKey: Keys.off) }
    }

    private enum Keys {
        static let isOn = "devicesOn"
        static let disconnects = "devicesDisconnects"
        static let off = "devicesCategoriesOff"
    }

    private static let quietTime: TimeInterval = 30
    private static let flapTime: TimeInterval = 10

    private let settings: AppSettings
    private let defaults: UserDefaults
    private var quietUntil = Date().addingTimeInterval(quietTime)
    private var lastSeen: [String: Date] = [:]
    private var hideTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var screens: Set<String> = []
    private var audioOutput: String?
    private var bluetoothNotification: IOBluetoothUserNotification?
    private let usb = USBWatcher()

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
        AudioOutputs.watchDefault { [weak self] in self?.audioChanged() }
    }

    @objc private func bluetoothConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(bluetoothDisconnected(_:device:)))
        bluetooth(device.name ?? "Bluetooth device", connected: true)
    }

    @objc private func bluetoothDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        bluetooth(device.name ?? "Bluetooth device", connected: false)
    }

    private func bluetooth(_ name: String, connected: Bool) {
        let kind = BatteryDevice.Kind.detect(name)
        var event = DeviceEvent(category: .bluetooth, name: name, symbol: DeviceSymbols.symbol(for: kind), isConnected: connected)
        if connected, kind == .earbuds || kind == .headphones, AudioOutputs.defaultOutputName() != name {
            event.actions = [.useForAudio(name)]
        }
        show(event, key: "bt:" + name)
        guard connected else { return }
        // The levels arrive a moment after the connection.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            let levels = await Task.detached { DeviceBattery.levels(named: name) }.value
            guard let self, let levels, self.current?.name == name else { return }
            self.current?.detail = levels
        }
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
        case .displaySettings:
            if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") { NSWorkspace.shared.open(url) }
        }
    }
}
