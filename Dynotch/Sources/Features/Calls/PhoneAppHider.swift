import AppKit
import CoreAudio

/// Keeps the Phone or FaceTime app in the Dock while a call rings and lasts, instead of letting
/// it jump to the front (spec P-5). A click in another app (e.g. on its Dock icon) lets it show.
@MainActor
final class PhoneAppHider {
    static let identifiers: Set<String> = ["com.apple.FaceTime", "com.apple.mobilephone"]
    /// After the ringing stops, a call that was answered needs a moment to take the microphone.
    private static let grace: TimeInterval = 5
    /// A click this recent in another app means the user brought the app forward.
    private static let clickWindow: TimeInterval = 1

    private let settings: AppSettings
    private var activationObserver: NSObjectProtocol?
    private var clickMonitor: Any?
    private var lastClick = Date.distantPast
    /// The user showed the app during this call: leave it alone.
    private var userShown = false
    private var isRinging = false
    private var hidesUntil: Date?

    init(settings: AppSettings) {
        self.settings = settings
    }

    private var isHiding: Bool {
        guard settings.keepsPhoneInDock, !userShown else { return false }
        return isRinging || (hidesUntil.map { $0 > Date() } ?? false)
    }

    /// The call banner appeared or went (called with every scan).
    func update(isRinging ringing: Bool) {
        if ringing, !isRinging {
            userShown = false
            start()
        }
        if !ringing, isRinging { hidesUntil = Date().addingTimeInterval(Self.grace) }
        isRinging = ringing
        // While the microphone is in use the call goes on.
        if !ringing, hidesUntil != nil, Self.microphoneInUse() {
            hidesUntil = Date().addingTimeInterval(Self.grace)
        }
        if isHiding {
            hideRunningPhoneApps()
        } else if !ringing, hidesUntil.map({ $0 <= Date() }) ?? false {
            stop()
        }
    }

    private func start() {
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let identifier = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated { self?.activated(identifier) }
        }
        // Only clicks in other apps arrive here, not those in Dynotch's own notch.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.lastClick = Date() }
        }
        DiagnosticsLog.append("calls", "keeping the phone app in the Dock")
    }

    private func stop() {
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        activationObserver = nil
        clickMonitor = nil
        hidesUntil = nil
    }

    private func activated(_ identifier: String?) {
        guard let identifier, Self.identifiers.contains(identifier), settings.keepsPhoneInDock else { return }
        if Date().timeIntervalSince(lastClick) < Self.clickWindow {
            userShown = true
            return
        }
        if isHiding { hideRunningPhoneApps() }
    }

    private func hideRunningPhoneApps() {
        for app in NSWorkspace.shared.runningApplications
        where Self.identifiers.contains(app.bundleIdentifier ?? "") && !app.isHidden {
            app.hide()
        }
    }

    /// Whether any app records from the default input device.
    static func microphoneInUse() -> Bool {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown
        else { return false }
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }
}
