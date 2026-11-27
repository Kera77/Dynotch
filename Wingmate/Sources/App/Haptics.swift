import AppKit
import IOKit

/// Trackpad feedback (spec H-7, H-8). Felt only while a finger is on a Force Touch trackpad.
@MainActor
enum Haptics {
    enum Kind {
        /// The notch opened.
        case open
        /// Switched to another feature.
        case featureSwitch
        /// Stepped to another day.
        case dayStep

        var pattern: NSHapticFeedbackManager.FeedbackPattern {
            switch self {
            case .open: .generic
            case .featureSwitch: .levelChange
            case .dayStep: .alignment
            }
        }

        /// The trackpad motor's own patterns: 3 a light tick, 4 a firmer one (spec H-8).
        var actuation: Int32 {
            switch self {
            case .open, .dayStep: 3
            case .featureSwitch: 4
            }
        }
    }

    static func perform(_ kind: Kind, settings: AppSettings) {
        guard settings.hapticsEnabled else { return }
        // The system's haptics play only for the active app, which Wingmate's panel never makes it:
        // the trackpad's motor directly first (spec H-8).
        if TrackpadActuator.shared.actuate(kind.actuation) { return }
        NSHapticFeedbackManager.defaultPerformer.perform(kind.pattern, performanceTime: .now)
    }
}

/// The Force Touch trackpads' motors through the private MultitouchSupport framework, loaded at
/// run time; nothing happens (and the caller falls back) where it is missing (spec H-8).
@MainActor
final class TrackpadActuator {
    static let shared = TrackpadActuator()

    private typealias CreateFunction = @convention(c) (UInt64) -> Unmanaged<CFTypeRef>?
    private typealias OpenFunction = @convention(c) (CFTypeRef) -> Int32
    private typealias ActuateFunction = @convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> Int32

    private struct Functions {
        let create: CreateFunction
        let open: OpenFunction
        let actuate: ActuateFunction
    }

    private let functions: Functions?
    private var actuators: [CFTypeRef] = []
    private var lastScan = Date.distantPast
    private var loggedState: String?
    /// A new trackpad (or one woken up) is looked for at most this often.
    private static let rescanInterval: TimeInterval = 10

    private init() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_LAZY),
              let create = dlsym(handle, "MTActuatorCreateFromDeviceID"),
              let open = dlsym(handle, "MTActuatorOpen"),
              let actuate = dlsym(handle, "MTActuatorActuate")
        else {
            functions = nil
            return
        }
        functions = Functions(
            create: unsafeBitCast(create, to: CreateFunction.self),
            open: unsafeBitCast(open, to: OpenFunction.self),
            actuate: unsafeBitCast(actuate, to: ActuateFunction.self)
        )
    }

    /// Plays `actuation` on every trackpad; false when no motor took it.
    func actuate(_ actuation: Int32) -> Bool {
        guard let functions else {
            log("MultitouchSupport missing: system haptics")
            return false
        }
        if actuators.isEmpty { scan(functions) }
        var played = actuators.filter { functions.actuate($0, actuation, 0, 0, 0) == 0 }.count
        // A trackpad that went to sleep or was unplugged: open them again, once.
        if played == 0, scan(functions) {
            played = actuators.filter { functions.actuate($0, actuation, 0, 0, 0) == 0 }.count
        }
        log(played > 0 ? "trackpad motor: \(actuators.count) trackpad(s)" : "trackpad motor refused: system haptics")
        return played > 0
    }

    /// Opens the motor of every multitouch device; false when it was too soon to look again.
    @discardableResult
    private func scan(_ functions: Functions) -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastScan) >= Self.rescanInterval else { return false }
        lastScan = now
        actuators = Self.deviceIDs().compactMap { id in
            guard let actuator = functions.create(id)?.takeRetainedValue(), functions.open(actuator) == 0 else { return nil }
            return actuator
        }
        return true
    }

    private static func deviceIDs() -> [UInt64] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleMultitouchDevice"), &iterator) == KERN_SUCCESS
        else { return [] }
        defer { IOObjectRelease(iterator) }
        var ids: [UInt64] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let property = IORegistryEntryCreateCFProperty(service, "Multitouch ID" as CFString, kCFAllocatorDefault, 0)
            if let number = property?.takeRetainedValue() as? NSNumber { ids.append(number.uint64Value) }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return ids
    }

    private func log(_ state: String) {
        guard state != loggedState else { return }
        loggedState = state
        DiagnosticsLog.append("haptics", state)
    }
}
