import AppKit
import CoreAudio
import DiskArbitration
import IOKit
import IOKit.usb

/// The battery module's icons for the Mac's own devices (spec DV-1).
enum DeviceSymbols {
    static func symbol(for kind: BatteryDevice.Kind) -> String {
        let names = kind == .other ? ["dot.radiowaves.left.and.right"] : kind.symbols
        return names.first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil } ?? "dot.radiowaves.left.and.right"
    }

    static func usbSymbol(for name: String) -> String {
        let words = name.lowercased()
        if words.contains("keyboard") { return "keyboard.fill" }
        if words.contains("mouse") { return "computermouse.fill" }
        if words.contains("hub") { return "cable.connector" }
        if words.contains("audio") || words.contains("mic") { return "mic.fill" }
        if words.contains("camera") || words.contains("webcam") { return "web.camera.fill" }
        return "cable.connector.horizontal"
    }
}

/// "L 80%  R 78%  Case 100%" for earbuds, or one level, from Bluetooth's report.
enum DeviceBattery {
    nonisolated static func levels(named name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return levels(named: name, json: data)
    }

    nonisolated static func levels(named name: String, json: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return nil }
        for section in sections {
            for list in section.values.compactMap({ $0 as? [[String: Any]] }) {
                for entry in list {
                    guard let info = entry[name] as? [String: Any] else { continue }
                    return text(from: info)
                }
            }
        }
        return nil
    }

    nonisolated static func text(from info: [String: Any]) -> String? {
        let parts = [("L", "device_batteryLevelLeft"), ("R", "device_batteryLevelRight"), ("Case", "device_batteryLevelCase"),
                     ("", "device_batteryLevelMain")]
            .compactMap { label, key -> String? in
                guard let value = info[key] as? String else { return nil }
                return label.isEmpty ? value : "\(label) \(value)"
            }
        return parts.isEmpty ? nil : parts.joined(separator: "  ")
    }
}

/// Disk images among the mounted volumes (spec DV-3, DV-4).
enum DiskImages {
    static func isDiskImage(_ volume: URL) -> Bool {
        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, volume as CFURL),
              let description = DADiskCopyDescription(disk) as? [String: Any]
        else { return false }
        let model = description[kDADiskDescriptionDeviceModelKey as String] as? String ?? ""
        return model.lowercased().contains("disk image")
    }

    static func sizeText(total: Int?, free: Int?, isImage: Bool) -> String? {
        guard let total else { return isImage ? "Disk image" : nil }
        let size = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
        if isImage { return "Disk image · \(size)" }
        guard let free else { return size }
        return "\(ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .file)) free of \(size)"
    }
}

/// The sound output (spec DV-3, DV-4).
enum AudioOutputs {
    private static func property<T>(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope, _ empty: T
    ) -> T {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var value = empty
        var size = UInt32(MemoryLayout<T>.size)
        _ = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value)
        return value
    }

    private static func name(of device: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    static func defaultOutputName() -> String? {
        let device: AudioObjectID = property(
            AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal, 0
        )
        return device == 0 ? nil : name(of: device)
    }

    private static func outputDevices() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices) == noErr else {
            return []
        }
        return devices.filter { device in
            var streams = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            return AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &streamSize) == noErr && streamSize > 0
        }
    }

    /// "Use for audio": the sound goes to the device with this name.
    static func setDefaultOutput(named wanted: String) {
        guard var device = outputDevices().first(where: { name(of: $0) == wanted }) else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &device)
    }

    /// Calls `changed` on the main thread when the sound output changes.
    static func watchDefault(_ changed: @escaping @MainActor () -> Void) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main) { _, _ in
            MainActor.assumeIsolated { changed() }
        }
    }
}

/// USB devices plugged in or out (spec DV-3), by IOKit's matching notifications.
@MainActor
final class USBWatcher {
    private var port: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var changed: (String, Bool) -> Void = { _, _ in }
    private var primed = false

    func start(_ changed: @escaping (String, Bool) -> Void) {
        self.changed = changed
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for (type, added) in [(kIOFirstMatchNotification, true), (kIOTerminatedNotification, false)] {
            var iterator: io_iterator_t = 0
            let callback: IOServiceMatchingCallback = { refcon, iterator in
                guard let refcon else { return }
                let watcher = Unmanaged<USBWatcher>.fromOpaque(refcon).takeUnretainedValue()
                MainActor.assumeIsolated { watcher.drain(iterator) }
            }
            let matching = IOServiceMatching("IOUSBHostDevice")
            if IOServiceAddMatchingNotification(port, type, matching, callback, context, &iterator) == KERN_SUCCESS {
                iterators.append(iterator)
                addedByIterator[iterator] = added
                // The devices already there: read without a notice.
                drain(iterator, notify: false)
            }
        }
        primed = true
    }

    private var addedByIterator: [io_iterator_t: Bool] = [:]

    private func drain(_ iterator: io_iterator_t, notify: Bool = true) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard notify, primed, let added = addedByIterator[iterator] else { continue }
            let name = IORegistryEntryCreateCFProperty(service, "USB Product Name" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String
            // Unnamed internal parts are left out.
            guard let name, !name.isEmpty else { continue }
            changed(name, added)
        }
    }
}
