import AppKit
import Observation

/// Sliding one finger along the trackpad's edges sets the volume (left), the display's
/// brightness (right) and the keyboard's backlight (top), shown in the HUD (spec ES-1…ES-5).
/// The touches come from the private MultitouchSupport framework, loaded at run time.
@MainActor
@Observable
final class EdgeSliderService {
    static let shared = EdgeSliderService()

    /// MultitouchSupport could be loaded and a trackpad started (spec ES-5).
    private(set) var isAvailable = false

    @ObservationIgnored private weak var hud: HUDService?
    @ObservationIgnored private var observer: ChangeObservation?
    @ObservationIgnored private var running = false
    private struct Slide {
        let zone: EdgeZone
        let start: Double
        var level: Double
        let cursor: CGPoint
    }

    @ObservationIgnored private var slide: Slide?

    private let settings = GestureSettings.shared

    func start(hud: HUDService) {
        self.hud = hud
        observer = observeChanges { [settings] in
            _ = settings.edgeSliders
            _ = settings.edgeVolume
            _ = settings.edgeBrightness
            _ = settings.edgeKeyboard
            _ = settings.edgeSteps
        } onChange: { [weak self] in self?.apply() }
        apply()
    }

    private func apply() {
        var zones = Set<EdgeZone>()
        for zone in EdgeZone.allCases where settings.isOn(zone) && Self.canSet(zone) { zones.insert(zone) }
        Multitouch.configure(zones: zones, steps: settings.edgeSteps.count)
        if settings.edgeSliders, !running {
            running = Multitouch.start { [weak self] output in self?.handle(output) }
            isAvailable = running
            DiagnosticsLog.append("edges", running ? "sliders on" : "MultitouchSupport missing: sliders off")
        } else if !settings.edgeSliders, running {
            Multitouch.stop()
            running = false
        }
    }

    /// The keyboard edge only with a backlit keyboard, brightness only on a built-in display (spec ES-5).
    static func canSet(_ zone: EdgeZone) -> Bool {
        switch zone {
        case .left: true
        case .right: BrightnessControl.isAvailable
        case .top: KeyboardBacklight.isAvailable
        }
    }

    private func handle(_ output: EdgeSliderTracker.Output) {
        switch output {
        case .began(let zone):
            guard let start = Self.level(of: zone) else { return }
            // The pointer stays where it was while the finger slides (spec ES-2).
            let cursor = CGEvent(source: nil)?.location ?? .zero
            slide = Slide(zone: zone, start: start, level: start, cursor: cursor)
            show(zone, level: start)
        case .moved(let zone, let steps):
            guard var current = slide, current.zone == zone else { return }
            CGWarpMouseCursorPosition(current.cursor)
            let level = EdgeSliderTracker.level(from: current.start, steps: steps, count: settings.edgeSteps.count)
            guard level != current.level else { return }
            current.level = level
            slide = current
            Self.set(zone, to: level)
            show(zone, level: level)
            // A tap on every step of the macOS grid; none at 1% (spec ES-3).
            if settings.edgeSteps == .macOS, !TrackpadActuator.shared.actuate(3) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        case .ended:
            if let current = slide { CGWarpMouseCursorPosition(current.cursor) }
            slide = nil
        }
    }

    private func show(_ zone: EdgeZone, level: Double) {
        switch zone {
        case .left: hud?.showLevel(.volume, level: level)
        case .right: hud?.showLevel(.brightness, level: level)
        case .top: hud?.showLevel(.keyboard, level: level)
        }
    }

    private static func level(of zone: EdgeZone) -> Double? {
        switch zone {
        case .left:
            guard let device = VolumeControl.defaultOutputDevice(), VolumeControl.isSettable(device) else { return nil }
            return VolumeControl.isMuted(device) ? 0 : VolumeControl.volume(device)
        case .right: return BrightnessControl.brightness()
        case .top: return KeyboardBacklight.brightness()
        }
    }

    private static func set(_ zone: EdgeZone, to level: Double) {
        switch zone {
        case .left:
            guard let device = VolumeControl.defaultOutputDevice() else { return }
            VolumeControl.setVolume(level, on: device)
            VolumeControl.setMuted(level <= 0, on: device)
        case .right: BrightnessControl.setBrightness(level)
        case .top: KeyboardBacklight.setBrightness(level)
        }
    }
}

/// The trackpads' touch frames through MultitouchSupport (spec ES-1). The frames arrive on the
/// framework's own thread; the tracker runs there under a lock, its steps go to the main thread.
enum Multitouch {
    private typealias Device = UnsafeMutableRawPointer
    private typealias Callback = @convention(c) (Device?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    private typealias Register = @convention(c) (Device, Callback) -> Void
    private typealias StartDevice = @convention(c) (Device, Int32) -> Int32
    private typealias StopDevice = @convention(c) (Device) -> Int32
    private typealias Dimensions = @convention(c) (Device, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32

    /// One finger in the framework's touch record: 96 bytes, the normalized position at 32.
    private static let touchSize = 96
    private static let positionOffset = 32
    private static let stateOffset = 20

    private static let lock = NSLock()
    nonisolated(unsafe) private static var tracker = EdgeSliderTracker()
    nonisolated(unsafe) private static var sink: (@MainActor (EdgeSliderTracker.Output) -> Void)?
    nonisolated(unsafe) private static var devices: [Device] = []
    nonisolated(unsafe) private static var stopFunction: StopDevice?

    static func configure(zones: Set<EdgeZone>, steps: Int) {
        lock.lock()
        tracker.enabled = zones
        tracker.steps = steps
        lock.unlock()
    }

    @MainActor
    static func start(_ handler: @escaping @MainActor (EdgeSliderTracker.Output) -> Void) -> Bool {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_LAZY),
              let createSymbol = dlsym(handle, "MTDeviceCreateList"),
              let registerSymbol = dlsym(handle, "MTRegisterContactFrameCallback"),
              let startSymbol = dlsym(handle, "MTDeviceStart"),
              let stopSymbol = dlsym(handle, "MTDeviceStop")
        else { return false }
        let create = unsafeBitCast(createSymbol, to: CreateList.self)
        let register = unsafeBitCast(registerSymbol, to: Register.self)
        let startDevice = unsafeBitCast(startSymbol, to: StartDevice.self)
        stopFunction = unsafeBitCast(stopSymbol, to: StopDevice.self)
        guard let list = create()?.takeRetainedValue() as? [AnyObject], !list.isEmpty else { return false }
        let dimensions = dlsym(handle, "MTDeviceGetSensorSurfaceDimensions").map { unsafeBitCast($0, to: Dimensions.self) }
        // Only trackpads, which are wider than tall: a Magic Mouse's edges are no sliders.
        let trackpads = list.map { Unmanaged.passRetained($0).toOpaque() }.filter { device in
            guard let dimensions else { return true }
            var width: Int32 = 0, height: Int32 = 0
            guard dimensions(device, &width, &height) == 0, width > 0, height > 0 else { return true }
            if width > height { return true }
            Unmanaged<AnyObject>.fromOpaque(device).release()
            return false
        }
        guard !trackpads.isEmpty else { return false }
        sink = handler
        devices = trackpads
        for device in devices {
            register(device, frameCallback)
            _ = startDevice(device, 0)
        }
        return true
    }

    @MainActor
    static func stop() {
        for device in devices {
            _ = stopFunction?(device)
            Unmanaged<AnyObject>.fromOpaque(device).release()
        }
        devices = []
        sink = nil
    }

    private static let frameCallback: Callback = { _, data, count, _, _ in
        var points: [CGPoint] = []
        if let data, count > 0 {
            for index in 0..<Int(count) {
                let base = data.advanced(by: index * touchSize)
                // 4 make touch, 5 touching: the finger is down.
                let state = base.load(fromByteOffset: stateOffset, as: Int32.self)
                guard state == 4 || state == 5 else { continue }
                let x = base.load(fromByteOffset: positionOffset, as: Float.self)
                let y = base.load(fromByteOffset: positionOffset + 4, as: Float.self)
                points.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
            }
        }
        lock.lock()
        let output = tracker.handle(touches: points)
        lock.unlock()
        if let output {
            DispatchQueue.main.async { MainActor.assumeIsolated { sink?(output) } }
        }
        return 0
    }
}

/// The keyboard's backlight through the private CoreBrightness framework (spec ES-1, ES-5).
@MainActor
enum KeyboardBacklight {
    private typealias Getter = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias Setter = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
    private typealias IDs = @convention(c) (AnyObject, Selector) -> Unmanaged<NSArray>?

    private static let client: NSObject? = {
        guard dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY) != nil,
              let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
        else { return nil }
        return type.init()
    }()

    private static let keyboardID: UInt64? = {
        guard let client else { return nil }
        let selector = NSSelectorFromString("copyKeyboardBacklightIDs")
        guard client.responds(to: selector) else { return nil }
        let ids = unsafeBitCast(client.method(for: selector), to: IDs.self)(client, selector)?.takeRetainedValue()
        return (ids?.firstObject as? NSNumber)?.uint64Value
    }()

    static var isAvailable: Bool { keyboardID != nil }

    static func brightness() -> Double? {
        guard let client, let keyboardID else { return nil }
        let selector = NSSelectorFromString("brightnessForKeyboard:")
        guard client.responds(to: selector) else { return nil }
        return Double(unsafeBitCast(client.method(for: selector), to: Getter.self)(client, selector, keyboardID))
    }

    static func setBrightness(_ level: Double) {
        guard let client, let keyboardID else { return }
        let selector = NSSelectorFromString("setBrightness:forKeyboard:")
        guard client.responds(to: selector) else { return }
        _ = unsafeBitCast(client.method(for: selector), to: Setter.self)(client, selector, Float(min(max(level, 0), 1)), keyboardID)
    }
}
