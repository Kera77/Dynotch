import Foundation
import Observation

/// A place chosen by name (spec WX-2).
struct WeatherPlace: Codable, Equatable, Hashable, Identifiable, Sendable {
    let name: String
    /// Region and country, for telling places of the same name apart.
    var detail: String = ""
    let latitude: Double
    let longitude: Double

    var id: String { "\(name)|\(latitude)|\(longitude)" }
}

/// Settings › Calendar › Weather (spec WX-1, WX-2, WX-7, WX-8).
@MainActor
@Observable
final class WeatherSettings {
    static let shared = WeatherSettings()

    @ObservationIgnored private let defaults: UserDefaults

    /// The Weather tab and every look for the weather (spec WX-1).
    var isOn: Bool { didSet { defaults.set(isOn, forKey: "weatherOn") } }
    /// Where you are (Location Services), or a city (spec WX-2).
    var usesLocation: Bool { didSet { defaults.set(usesLocation, forKey: "weatherUsesLocation") } }
    var city: WeatherPlace? {
        didSet { defaults.set(city.flatMap { try? JSONEncoder().encode($0) }, forKey: "weatherCity") }
    }
    /// The morning forecast and its earliest time, in minutes after midnight (spec WX-7, WX-8).
    var morningOn: Bool { didSet { defaults.set(morningOn, forKey: "weatherMorningOn") } }
    var morningNotBefore: Int { didSet { defaults.set(morningNotBefore, forKey: "weatherMorningNotBefore") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isOn = defaults.object(forKey: "weatherOn") as? Bool ?? true
        usesLocation = defaults.object(forKey: "weatherUsesLocation") as? Bool ?? true
        city = defaults.data(forKey: "weatherCity").flatMap { try? JSONDecoder().decode(WeatherPlace.self, from: $0) }
        morningOn = defaults.object(forKey: "weatherMorningOn") as? Bool ?? true
        morningNotBefore = min(max(defaults.object(forKey: "weatherMorningNotBefore") as? Int ?? 5 * 60, 0), 23 * 60 + 59)
    }

    /// The morning time as a date today, for the time picker.
    var notBeforeDate: Date {
        get { Calendar.current.startOfDay(for: Date()).addingTimeInterval(TimeInterval(morningNotBefore * 60)) }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            morningNotBefore = (parts.hour ?? 5) * 60 + (parts.minute ?? 0)
        }
    }
}
