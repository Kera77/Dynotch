import Foundation

/// The forecast the Weather tab shows (spec WX-6).
struct WeatherForecast: Codable, Equatable, Sendable {
    struct Now: Codable, Equatable, Sendable {
        let temperature: Double
        let feelsLike: Double
        let humidity: Double
        let wind: Double
        let code: Int
        let isDay: Bool
    }

    struct Hour: Codable, Equatable, Sendable, Identifiable {
        let time: Date
        let temperature: Double
        let code: Int
        let rainChance: Int
        let isDay: Bool
        var id: Date { time }
    }

    struct Day: Codable, Equatable, Sendable, Identifiable {
        let date: Date
        let code: Int
        let high: Double
        let low: Double
        let rainChance: Int
        let sunrise: Date?
        let sunset: Date?
        let uvIndex: Double
        var id: Date { date }
    }

    let now: Now
    let hours: [Hour]
    let days: [Day]
    let fetched: Date

    /// The next 24 hours from `now` (spec WX-6).
    func nextHours(from date: Date) -> [Hour] {
        let start = date.addingTimeInterval(-3600)
        return Array(hours.filter { $0.time > start }.prefix(24))
    }

    var today: Day? { days.first }
}

/// Open-Meteo's answer (spec WX-3), times as Unix seconds.
enum OpenMeteo {
    /// The forecast's address: only the rounded coordinates and the units go out (spec WX-3).
    nonisolated static func forecastURL(latitude: Double, longitude: Double, imperial: Bool) -> URL? {
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        parts?.queryItems = [
            URLQueryItem(name: "latitude", value: rounded(latitude)),
            URLQueryItem(name: "longitude", value: rounded(longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
            ),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,is_day"),
            URLQueryItem(
                name: "daily",
                value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset,uv_index_max"
            ),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "7")
        ] + (imperial ? [
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"), URLQueryItem(name: "wind_speed_unit", value: "mph")
        ] : [])
        return parts?.url
    }

    nonisolated static func searchURL(_ name: String) -> URL? {
        var parts = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        parts?.queryItems = [
            URLQueryItem(name: "name", value: name), URLQueryItem(name: "count", value: "6"),
            URLQueryItem(name: "language", value: "en"), URLQueryItem(name: "format", value: "json")
        ]
        return parts?.url
    }

    /// About 1 km: two decimals (spec WX-3).
    nonisolated static func rounded(_ value: Double) -> String {
        String(format: "%.2f", (value * 100).rounded() / 100)
    }

    nonisolated static func forecast(from data: Data, fetched: Date) -> WeatherForecast? {
        guard let answer = try? JSONDecoder().decode(MeteoAnswer.self, from: data) else { return nil }
        let current = answer.current
        let now = WeatherForecast.Now(
            temperature: current.temperature, feelsLike: current.feelsLike, humidity: current.humidity,
            wind: current.wind, code: current.code, isDay: current.isDay == 1
        )
        let hourly = answer.hourly
        let hours = hourly.time.indices.compactMap { index -> WeatherForecast.Hour? in
            guard let temperature = value(hourly.temperature, index) else { return nil }
            return WeatherForecast.Hour(
                time: Date(timeIntervalSince1970: hourly.time[index]), temperature: temperature,
                code: value(hourly.code, index) ?? 0, rainChance: value(hourly.rainChance, index) ?? 0,
                isDay: value(hourly.isDay, index) != 0
            )
        }
        let daily = answer.daily
        let days = daily.time.indices.compactMap { index -> WeatherForecast.Day? in
            guard let high = value(daily.high, index), let low = value(daily.low, index) else { return nil }
            return WeatherForecast.Day(
                date: Date(timeIntervalSince1970: daily.time[index]), code: value(daily.code, index) ?? 0, high: high, low: low,
                rainChance: value(daily.rainChance, index) ?? 0,
                sunrise: value(daily.sunrise, index).map(Date.init(timeIntervalSince1970:)),
                sunset: value(daily.sunset, index).map(Date.init(timeIntervalSince1970:)),
                uvIndex: value(daily.uvIndex, index) ?? 0
            )
        }
        return WeatherForecast(now: now, hours: hours, days: days, fetched: fetched)
    }

    private nonisolated static func value<Value>(_ list: [Value?], _ index: Int) -> Value? {
        list.indices.contains(index) ? list[index] : nil
    }

    nonisolated static func places(from data: Data) -> [WeatherPlace] {
        guard let answer = try? JSONDecoder().decode(MeteoPlaces.self, from: data) else { return [] }
        return (answer.results ?? []).map { result in
            WeatherPlace(
                name: result.name, detail: [result.admin1, result.country].compactMap { $0 }.joined(separator: ", "),
                latitude: result.latitude, longitude: result.longitude
            )
        }
    }
}

/// The WMO weather codes as a symbol and a few words (spec WX-6).
enum WeatherCode {
    private struct Look {
        let day: String
        let night: String
        let text: String
    }

    private nonisolated static let looks: [Int: Look] = {
        var table: [Int: Look] = [:]
        func add(_ codes: [Int], _ day: String, night: String? = nil, _ text: String) {
            for code in codes { table[code] = Look(day: day, night: night ?? day, text: text) }
        }
        add([0], "sun.max.fill", night: "moon.stars.fill", "Clear")
        add([1], "sun.max.fill", night: "moon.fill", "Mostly clear")
        add([2], "cloud.sun.fill", night: "cloud.moon.fill", "Partly cloudy")
        add([3], "cloud.fill", "Cloudy")
        add([45, 48], "cloud.fog.fill", "Fog")
        add([51, 53, 55], "cloud.drizzle.fill", "Drizzle")
        add([56, 57], "cloud.sleet.fill", "Freezing drizzle")
        add([61, 63], "cloud.rain.fill", "Rain")
        add([65], "cloud.heavyrain.fill", "Heavy rain")
        add([66, 67], "cloud.sleet.fill", "Freezing rain")
        add([71, 73, 75, 77], "cloud.snow.fill", "Snow")
        add([80, 81], "cloud.sun.rain.fill", night: "cloud.moon.rain.fill", "Showers")
        add([82], "cloud.heavyrain.fill", "Showers")
        add([85, 86], "cloud.snow.fill", "Snow showers")
        add([95], "cloud.bolt.rain.fill", "Thunderstorm")
        add([96, 99], "cloud.bolt.rain.fill", "Thunderstorm with hail")
        return table
    }()

    nonisolated static func symbol(_ code: Int, isDay: Bool = true) -> String {
        guard let look = looks[code] else { return "cloud.fill" }
        return isDay ? look.day : look.night
    }

    nonisolated static func text(_ code: Int) -> String {
        looks[code]?.text ?? "Cloudy"
    }
}

/// The morning forecast's rain line (spec WX-7): the first and last daytime hour (8–20) with at
/// least a 50% chance, as "Rain likely 14:00–17:00".
enum MorningRain {
    nonisolated static func window(in hours: [WeatherForecast.Hour], on day: Date, calendar: Calendar = .current) -> (Date, Date)? {
        let wet = hours.filter { hour in
            guard calendar.isDate(hour.time, inSameDayAs: day) else { return false }
            let clock = calendar.component(.hour, from: hour.time)
            return (8..<20).contains(clock) && hour.rainChance >= 50
        }
        guard let first = wet.first?.time, let last = wet.last?.time else { return nil }
        return (first, last.addingTimeInterval(3600))
    }
}

private struct MeteoCurrent: Decodable {
    let temperature: Double
    let feelsLike: Double
    let humidity: Double
    let code: Int
    let wind: Double
    let isDay: Int

    enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m", feelsLike = "apparent_temperature", humidity = "relative_humidity_2m"
        case code = "weather_code", wind = "wind_speed_10m", isDay = "is_day"
    }
}

private struct MeteoHourly: Decodable {
    let time: [Double]
    let temperature: [Double?]
    let code: [Int?]
    let rainChance: [Int?]
    let isDay: [Int?]

    enum CodingKeys: String, CodingKey {
        case time, temperature = "temperature_2m", code = "weather_code", rainChance = "precipitation_probability"
        case isDay = "is_day"
    }
}

private struct MeteoDaily: Decodable {
    let time: [Double]
    let code: [Int?]
    let high: [Double?]
    let low: [Double?]
    let rainChance: [Int?]
    let sunrise: [Double?]
    let sunset: [Double?]
    let uvIndex: [Double?]

    enum CodingKeys: String, CodingKey {
        case time, code = "weather_code", high = "temperature_2m_max", low = "temperature_2m_min"
        case rainChance = "precipitation_probability_max", sunrise, sunset, uvIndex = "uv_index_max"
    }
}

private struct MeteoAnswer: Decodable {
    let current: MeteoCurrent
    let hourly: MeteoHourly
    let daily: MeteoDaily
}

private struct MeteoPlace: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
}

private struct MeteoPlaces: Decodable {
    let results: [MeteoPlace]?
}
