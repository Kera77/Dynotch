import CoreLocation
import Foundation

/// Where the Mac is, through Location Services (spec WX-2). One look at a time; the place is kept
/// for 3 hours, so the 30-minute refreshes don't ask every time.
@MainActor
final class WeatherLocator: NSObject, CLLocationManagerDelegate {
    enum Access: Sendable {
        case notDetermined
        case allowed
        case denied
    }

    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<CLLocation?, Never>] = []
    private var cached: (place: WeatherPlace, date: Date)?
    nonisolated static let keptFor: TimeInterval = 3 * 3600

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var access: Access {
        switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorizedAlways, .authorizedWhenInUse: .allowed
        default: .denied
        }
    }

    func requestAccess() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// The place now, with its town's name; nil without access or a fix.
    func place() async -> WeatherPlace? {
        if let cached, Date().timeIntervalSince(cached.date) < Self.keptFor { return cached.place }
        guard let location = await locate() else { return nil }
        let name = await Self.townName(of: location) ?? "Current location"
        let place = WeatherPlace(name: name, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        cached = (place, Date())
        return place
    }

    private func locate() async -> CLLocation? {
        if access == .notDetermined {
            // Waits a little for the answer to the system's question.
            for _ in 0..<30 where access == .notDetermined { try? await Task.sleep(for: .seconds(1)) }
        }
        guard access == .allowed else { return nil }
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
            if waiting.count == 1 { manager.requestLocation() }
        }
    }

    private func finish(_ location: CLLocation?) {
        let continuations = waiting
        waiting = []
        continuations.forEach { $0.resume(returning: location) }
    }

    private static func townName(of location: CLLocation) async -> String? {
        let marks = try? await CLGeocoder().reverseGeocodeLocation(location)
        return marks?.first.flatMap { $0.locality ?? $0.subAdministrativeArea ?? $0.administrativeArea }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        MainActor.assumeIsolated { finish(latest) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            DiagnosticsLog.append("weather", "no location fix")
            finish(nil)
        }
    }
}
