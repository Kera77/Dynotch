@testable import Dynotch
import Foundation
import Testing

/// The Weather tab: Open-Meteo's answer, the codes, the morning rain line and the privacy of the request.
struct WeatherTests {
    private let sample = """
    {"current":{"temperature_2m":7.4,"apparent_temperature":4.9,"relative_humidity_2m":81,"weather_code":2,
    "wind_speed_10m":12.3,"is_day":1},
    "hourly":{"time":[1764054000,1764057600],"temperature_2m":[7.1,null],"weather_code":[61,3],
    "precipitation_probability":[70,10],"is_day":[1,1]},
    "daily":{"time":[1764025200],"weather_code":[61],"temperature_2m_max":[9.2],"temperature_2m_min":[2.1],
    "precipitation_probability_max":[70],"sunrise":[1764050400],"sunset":[1764083400],"uv_index_max":[1.2]}}
    """

    @Test func readsOpenMeteosAnswer() throws {
        let forecast = try #require(OpenMeteo.forecast(from: Data(sample.utf8), fetched: Date()))
        #expect(forecast.now.temperature == 7.4)
        #expect(forecast.now.code == 2)
        #expect(forecast.now.isDay)
        // An hour without a temperature is left out.
        #expect(forecast.hours.count == 1)
        #expect(forecast.hours.first?.rainChance == 70)
        #expect(forecast.today?.high == 9.2)
        #expect(forecast.today?.sunrise == Date(timeIntervalSince1970: 1_764_050_400))
    }

    @Test func onlyTheRoundedPlaceGoesOut() throws {
        let url = try #require(OpenMeteo.forecastURL(latitude: 47.497_912, longitude: 19.040_235, imperial: false))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "latitude" }?.value == "47.50")
        #expect(items.first { $0.name == "longitude" }?.value == "19.04")
        #expect(!items.contains { $0.name == "temperature_unit" })
        let imperial = try #require(OpenMeteo.forecastURL(latitude: 40.7, longitude: -74, imperial: true))
        #expect(imperial.absoluteString.contains("temperature_unit=fahrenheit"))
    }

    @Test func codesHaveASymbolAndWords() {
        #expect(WeatherCode.symbol(0, isDay: true) == "sun.max.fill")
        #expect(WeatherCode.symbol(0, isDay: false) == "moon.stars.fill")
        #expect(WeatherCode.text(63) == "Rain")
        #expect(WeatherCode.text(1234) == "Cloudy")
    }

    @Test func morningRainSpansTheWetDaytimeHours() throws {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        func hour(_ clock: Int, _ chance: Int) -> WeatherForecast.Hour {
            WeatherForecast.Hour(
                time: day.addingTimeInterval(TimeInterval(clock * 3600)), temperature: 5, code: 61, rainChance: chance, isDay: true
            )
        }
        let hours = [hour(6, 90), hour(13, 30), hour(14, 60), hour(16, 55), hour(21, 90)]
        let (start, end) = try #require(MorningRain.window(in: hours, on: day))
        #expect(calendar.component(.hour, from: start) == 14)
        #expect(calendar.component(.hour, from: end) == 17)
        #expect(MorningRain.window(in: [hour(13, 30)], on: day) == nil)
    }

    @Test func placesFromTheSearch() {
        let answer = #"{"results":[{"name":"Szeged","latitude":46.25,"longitude":20.15,"country":"Hungary","admin1":"Csongrád"}]}"#
        let places = OpenMeteo.places(from: Data(answer.utf8))
        #expect(places.first?.name == "Szeged")
        #expect(places.first?.detail == "Csongrád, Hungary")
        #expect(OpenMeteo.places(from: Data("{}".utf8)).isEmpty)
    }

    @Test @MainActor func theWeatherTabFollowsItsSwitch() {
        let defaults = UserDefaults(suiteName: "weather-tab-\(UUID().uuidString)") ?? .standard
        let settings = AppSettings(defaults: defaults)
        let weather = WeatherSettings.shared
        let wasOn = weather.isOn
        defer { weather.isOn = wasOn }
        weather.isOn = true
        #expect(settings.mergedTabs(for: .calendar) == [.calendar, .weather])
        weather.isOn = false
        #expect(settings.mergedTabs(for: .calendar) == nil)
        #expect(!settings.isEnabled(.weather))
    }
}
