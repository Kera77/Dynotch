import AppKit
import Combine
import CoreAudio

/// Shows volume and brightness changes beside the notch instead of the macOS overlay
/// (spec H-1…H-6, A-1…A-6).
@MainActor
final class HUDService: ObservableObject {
    enum Kind: Equatable, Sendable {
        case volume
        case brightness
    }

    struct Display: Equatable, Sendable {
        let kind: Kind
        let level: Double
        let muted: Bool
    }

    @Published private(set) var display: Display?

    private let settings: AppSettings
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var hideTask: Task<Void, Never>?
    private var listenedDevice: AudioDeviceID?
    private var settingsObserver: AnyCancellable?
    /// Our own volume changes also arrive through the listener; they are shown once.
    private var ownChangeUntil = Date.distantPast

    private static let visibleFor: Duration = .milliseconds(1500)

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        settingsObserver = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.applyEnabled() }
            }
        }
        applyEnabled()
        listenToVolume()
    }

    // MARK: - Key tap

    private func applyEnabled() {
        if settings.hudEnabled, tap == nil {
            startTap()
        } else if !settings.hudEnabled, let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
            self.tap = nil
            tapSource = nil
        }
    }

    private func startTap() {
        let systemDefined = CGEventMask(1 << 14) // NX_SYSDEFINED: media keys
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let service = Unmanaged<HUDService>.fromOpaque(refcon).takeUnretainedValue()
            let consumed = MainActor.assumeIsolated { service.handle(type: type, event: event) }
            return consumed ? nil : Unmanaged.passUnretained(event)
        }
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: systemDefined, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            DiagnosticsLog.append("hud", "key tap not created (Accessibility: \(AXIsProcessTrusted()))")
            return
        }
        let source = CFMachPortCreateRunLoopSource(nil, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        tap = created
        tapSource = source
        DiagnosticsLog.append("hud", "key tap on")
    }

    /// - Returns: true if the key was handled and must not reach macOS (no native overlay).
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        guard type.rawValue == 14, let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else { return false }
        let data = nsEvent.data1
        guard let key = MediaKey(rawValue: (data & 0xFFFF_0000) >> 16) else { return false }
        let isDown = ((data & 0xFF00) >> 8) == 0xA
        let fine = nsEvent.modifierFlags.contains(.option) && nsEvent.modifierFlags.contains(.shift)

        if key.isVolume {
            guard let device = VolumeControl.defaultOutputDevice(), VolumeControl.isSettable(device) else { return false }
            if isDown { changeVolume(key, device: device, fine: fine) }
            return true
        }
        guard BrightnessControl.isAvailable else { return false }
        if isDown { changeBrightness(up: key == .brightnessUp, fine: fine) }
        return true
    }

    private func changeVolume(_ key: MediaKey, device: AudioDeviceID, fine: Bool) {
        ownChangeUntil = Date().addingTimeInterval(0.3)
        let current = VolumeControl.volume(device) ?? 0
        switch key {
        case .mute:
            VolumeControl.setMuted(!VolumeControl.isMuted(device), on: device)
        default:
            let level = HUDLogic.stepped(current, up: key == .soundUp, fine: fine)
            VolumeControl.setVolume(level, on: device)
            // Changing the level unmutes, as in macOS.
            VolumeControl.setMuted(level <= 0, on: device)
        }
        show(.volume, level: VolumeControl.volume(device) ?? current, muted: VolumeControl.isMuted(device))
    }

    private func changeBrightness(up: Bool, fine: Bool) {
        let current = BrightnessControl.brightness() ?? 0.5
        let level = HUDLogic.stepped(current, up: up, fine: fine)
        BrightnessControl.setBrightness(level)
        show(.brightness, level: level, muted: false)
    }

    // MARK: - Volume changed elsewhere (spec A-4)

    private func listenToVolume() {
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.listenToCurrentDevice() }
        }
        listenToCurrentDevice()
    }

    private func listenToCurrentDevice() {
        guard let device = VolumeControl.defaultOutputDevice(), device != listenedDevice else { return }
        listenedDevice = device
        for var address in [VolumeControl.volumeAddress, VolumeControl.muteAddress] {
            AudioObjectAddPropertyListenerBlock(device, &address, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.volumeChangedElsewhere(device) }
            }
        }
    }

    private func volumeChangedElsewhere(_ device: AudioDeviceID) {
        guard settings.hudEnabled, Date() > ownChangeUntil, device == VolumeControl.defaultOutputDevice() else { return }
        show(.volume, level: VolumeControl.volume(device) ?? 0, muted: VolumeControl.isMuted(device))
    }

    // MARK: - Display

    private func show(_ kind: Kind, level: Double, muted: Bool) {
        display = Display(kind: kind, level: level, muted: muted)
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visibleFor)
            guard !Task.isCancelled else { return }
            self?.display = nil
        }
    }
}
