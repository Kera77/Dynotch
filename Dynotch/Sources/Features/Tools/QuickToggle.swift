import AppKit
import CoreAudio
import Foundation

/// The Toggles tab's tiles (spec QT-2).
enum QuickToggle: String, CaseIterable, Identifiable, Codable, Sendable {
    case keepAwake
    case doNotDisturb
    case darkMode
    case muteMicrophone
    case nightShift
    case hideDesktopIcons
    case showHiddenFiles
    case lockScreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keepAwake: "Keep Awake"
        case .doNotDisturb: "Do Not Disturb"
        case .darkMode: "Dark Mode"
        case .muteMicrophone: "Mute Microphone"
        case .nightShift: "Night Shift"
        case .hideDesktopIcons: "Hide Desktop Icons"
        case .showHiddenFiles: "Show Hidden Files"
        case .lockScreen: "Lock Screen"
        }
    }

    func symbol(isOn: Bool) -> String {
        switch self {
        case .keepAwake: "cup.and.saucer.fill"
        case .doNotDisturb: "moon.fill"
        case .darkMode: "circle.lefthalf.filled"
        case .muteMicrophone: isOn ? "mic.slash.fill" : "mic.fill"
        case .nightShift: "sun.horizon.fill"
        case .hideDesktopIcons: isOn ? "eye.slash" : "menubar.dock.rectangle"
        case .showHiddenFiles: isOn ? "eye" : "eye.slash"
        case .lockScreen: "lock.fill"
        }
    }

    /// The text a HUD announcement writes after a shortcut (spec HA-2).
    func announcement(isOn: Bool) -> String {
        switch self {
        case .muteMicrophone: isOn ? "Microphone muted" : "Microphone on"
        case .keepAwake: isOn ? "Keep Awake on" : "Keep Awake off"
        case .lockScreen: "Locking"
        default: "\(title) \(isOn ? "on" : "off")"
        }
    }

    /// Lock Screen is an action, not a switch.
    var isAction: Bool { self == .lockScreen }

    /// Night Shift needs a private framework that may be missing (spec QT-2).
    @MainActor var isAvailable: Bool {
        self != .nightShift || NightShift.isAvailable
    }
}

/// Keep Awake's lengths (spec QT-3).
enum KeepAwakeLength: String, CaseIterable, Identifiable, Sendable {
    case quarterHour, hour, twoHours, untilTimerEnds, indefinitely

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quarterHour: "15 min"
        case .hour: "1 hour"
        case .twoHours: "2 hours"
        case .untilTimerEnds: "Until a timer ends"
        case .indefinitely: "Indefinitely"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .quarterHour: 15 * 60
        case .hour: 3600
        case .twoHours: 7200
        case .untilTimerEnds, .indefinitely: nil
        }
    }
}

/// Night Shift through the private CoreBrightness framework, loaded at run time (spec QT-2).
@MainActor
enum NightShift {
    private static let client: NSObject? = {
        guard Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework")?.load() == true,
              let type = NSClassFromString("CBBlueLightClient") as? NSObject.Type
        else { return nil }
        return type.init()
    }()

    private typealias StatusFunction = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
    private typealias EnableFunction = @convention(c) (AnyObject, Selector, Bool) -> Bool

    static var isAvailable: Bool {
        guard let client else { return false }
        return client.responds(to: NSSelectorFromString("getBlueLightStatus:"))
            && client.responds(to: NSSelectorFromString("setEnabled:"))
    }

    /// Whether it is on now; the status struct starts with `active` and `enabled` flags.
    static var isOn: Bool {
        guard isAvailable, let client else { return false }
        let selector = NSSelectorFromString("getBlueLightStatus:")
        let function = unsafeBitCast(client.method(for: selector), to: StatusFunction.self)
        let status = UnsafeMutableRawPointer.allocate(byteCount: 64, alignment: 8)
        defer { status.deallocate() }
        status.initializeMemory(as: UInt8.self, repeating: 0, count: 64)
        guard function(client, selector, status) else { return false }
        return status.load(fromByteOffset: 1, as: Bool.self)
    }

    static func set(_ isOn: Bool) {
        guard isAvailable, let client else { return }
        let selector = NSSelectorFromString("setEnabled:")
        let function = unsafeBitCast(client.method(for: selector), to: EnableFunction.self)
        _ = function(client, selector, isOn)
    }
}

/// The default input's mute (spec QT-2): the device's own mute, or its volume at 0 where it has none.
enum Microphone {
    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
    }

    nonisolated static func defaultInput() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var property = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
    }

    nonisolated static func isMuted() -> Bool {
        guard let device = defaultInput() else { return false }
        var property = address(kAudioDevicePropertyMute)
        if AudioObjectHasProperty(device, &property) {
            var muted = UInt32(0)
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &property, 0, nil, &size, &muted) == noErr { return muted != 0 }
        }
        return volume(of: device) == 0
    }

    nonisolated static func setMuted(_ muted: Bool) {
        guard let device = defaultInput() else { return }
        var property = address(kAudioDevicePropertyMute)
        var settable: DarwinBoolean = false
        if AudioObjectHasProperty(device, &property), AudioObjectIsPropertySettable(device, &property, &settable) == noErr,
           settable.boolValue {
            var value = UInt32(muted ? 1 : 0)
            AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
            return
        }
        // No mute of its own: the volume goes to 0 and comes back to where it was.
        let key = "micVolumeBeforeMute"
        if muted {
            UserDefaults.standard.set(volume(of: device) ?? 1, forKey: key)
            setVolume(0, of: device)
        } else {
            let previous = UserDefaults.standard.object(forKey: key) as? Float32 ?? 1
            setVolume(previous > 0 ? previous : 1, of: device)
        }
    }

    private nonisolated static func volume(of device: AudioDeviceID) -> Float32? {
        var property = address(kAudioDevicePropertyVolumeScalar)
        guard AudioObjectHasProperty(device, &property) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr ? value : nil
    }

    private nonisolated static func setVolume(_ value: Float32, of device: AudioDeviceID) {
        var property = address(kAudioDevicePropertyVolumeScalar)
        var level = value
        AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<Float32>.size), &level)
    }
}

/// The Finder's own settings behind two tiles (spec QT-2).
enum FinderSetting {
    nonisolated static func bool(_ key: String) -> Bool? {
        CFPreferencesCopyAppValue(key as CFString, "com.apple.finder" as CFString) as? Bool
    }

    /// Writes it and restarts the Finder, which reads it only at launch. Off the main thread.
    nonisolated static func set(_ key: String, _ value: Bool) {
        _ = ProcessRunner.run("/usr/bin/defaults", ["write", "com.apple.finder", key, "-bool", value ? "true" : "false"], timeout: 5)
        _ = ProcessRunner.run("/usr/bin/killall", ["Finder"], timeout: 5)
    }
}

/// Locks the screen at once, as the Control Centre's Lock Screen does (spec QT-2).
enum ScreenLock {
    private typealias LockFunction = @convention(c) () -> Void

    nonisolated static func lock() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
           let symbol = dlsym(handle, "SACLockScreenImmediate") {
            unsafeBitCast(symbol, to: LockFunction.self)()
            return
        }
        _ = ProcessRunner.run("/usr/bin/pmset", ["displaysleepnow"], timeout: 5)
    }
}

/// The user's Shortcuts, run by name (spec TM-16, QT-2).
enum ShortcutsApp {
    /// Off the main thread.
    nonisolated static func names() -> [String] {
        guard let result = ProcessRunner.run("/usr/bin/shortcuts", ["list"], timeout: 10), result.succeeded else { return [] }
        let text = String(bytes: result.output, encoding: .utf8) ?? ""
        return text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.sorted()
    }

    static func run(_ name: String) {
        guard !name.isEmpty else { return }
        Task.detached {
            let result = ProcessRunner.run("/usr/bin/shortcuts", ["run", name], timeout: 30)
            if result?.succeeded != true { DiagnosticsLog.append("tools", "shortcut did not run") }
        }
    }
}
