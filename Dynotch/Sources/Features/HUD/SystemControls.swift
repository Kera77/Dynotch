import AppKit
import AudioToolbox
import CoreAudio

/// System output volume through CoreAudio (spec H-2, A-2).
enum VolumeControl {
    static func defaultOutputDevice() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != 0
        else { return nil }
        return device
    }

    static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    static let muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    /// False for outputs whose volume can't be set (e.g. HDMI): their keys are left to macOS.
    static func isSettable(_ device: AudioDeviceID) -> Bool {
        var address = volumeAddress
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    static func volume(_ device: AudioDeviceID) -> Double? {
        var address = volumeAddress
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return Double(value)
    }

    static func setVolume(_ level: Double, on device: AudioDeviceID) {
        var address = volumeAddress
        var value = Float32(min(max(level, 0), 1))
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    }

    static func isMuted(_ device: AudioDeviceID) -> Bool {
        var address = muteAddress
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    static func setMuted(_ muted: Bool, on device: AudioDeviceID) {
        var address = muteAddress
        var value = UInt32(muted ? 1 : 0)
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }
}

/// Brightness of the built-in display through the private DisplayServices framework, loaded at
/// run time (spec H-2, A-2). Missing on a macOS version: brightness keys are left to macOS.
enum BrightnessControl {
    private typealias Getter = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (CGDirectDisplayID, Float) -> Int32

    nonisolated(unsafe) private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY
    )
    nonisolated(unsafe) private static let getter: Getter? = dlsym(handle, "DisplayServicesGetBrightness")
        .map { unsafeBitCast($0, to: Getter.self) }
    nonisolated(unsafe) private static let setter: Setter? = dlsym(handle, "DisplayServicesSetBrightness")
        .map { unsafeBitCast($0, to: Setter.self) }

    static var builtInDisplay: CGDirectDisplayID? {
        var count: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(16, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    static var isAvailable: Bool {
        getter != nil && setter != nil && builtInDisplay != nil
    }

    static func brightness() -> Double? {
        guard let getter, let display = builtInDisplay else { return nil }
        var value: Float = 0
        return getter(display, &value) == 0 ? Double(value) : nil
    }

    static func setBrightness(_ level: Double) {
        guard let setter, let display = builtInDisplay else { return }
        _ = setter(display, Float(min(max(level, 0), 1)))
    }
}

/// Keys of the volume and brightness rows (NX_KEYTYPE_*).
enum MediaKey: Int {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7

    var isVolume: Bool { self == .soundUp || self == .soundDown || self == .mute }
}

/// Pure level stepping (spec A-3): macOS steps by 1/16, Option+Shift by 1/64, on a grid.
enum HUDLogic {
    static func stepped(_ level: Double, increase: Bool, fine: Bool) -> Double {
        let steps = fine ? 64.0 : 16.0
        let next = (level * steps).rounded() + (increase ? 1 : -1)
        return min(max(next / steps, 0), 1)
    }

    /// Speaker symbol for a level.
    static func volumeSymbol(level: Double, muted: Bool) -> String {
        if muted || level <= 0.001 { return "speaker.slash.fill" }
        if level < 0.34 { return "speaker.wave.1.fill" }
        if level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
