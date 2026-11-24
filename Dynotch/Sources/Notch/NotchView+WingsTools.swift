import SwiftUI

// MARK: - The Tools and the weather in the Wings (spec PV-9, TM-3, WX-6)

extension NotchView {
    /// The countdown shown beside the notch, or the tab's name.
    var toolsWingLeft: some View {
        let clock = ToolsService.shared.glance?.clock
        return WingLabel(symbol: clock?.symbol ?? "timer", text: clock.map { $0.tab.title } ?? ToolsSettings.shared.tab.title)
    }

    @ViewBuilder var toolsWingRight: some View {
        if let clock = ToolsService.shared.glance?.clock {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                WingText(ClockText.text(clock.seconds(at: context.date)), bold: true)
            }
        } else {
            WingText("Nothing running", dim: true)
        }
    }

    var weatherWingLeft: some View {
        let forecast = WeatherService.shared.forecast
        return WingLabel(
            symbol: forecast.map { WeatherCode.symbol($0.now.code, isDay: $0.now.isDay) } ?? "cloud.sun",
            text: forecast.map { WeatherService.degrees($0.now.temperature) } ?? "Weather"
        )
    }

    var weatherWingRight: some View {
        WingText(WeatherService.shared.forecast.map { WeatherCode.text($0.now.code) } ?? WeatherService.shared.placeName, dim: true)
    }
}
