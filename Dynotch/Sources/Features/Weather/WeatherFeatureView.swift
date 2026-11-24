import SwiftUI

/// The Calendar's Weather tab (spec WX-6): now, the next 24 hours, and 7 days when there is room.
struct WeatherFeatureView: View {
    let service = WeatherService.shared
    var isActive: Bool

    var body: some View {
        Group {
            if let forecast = service.forecast {
                GeometryReader { proxy in
                    VStack(alignment: .leading, spacing: 10) {
                        header(forecast)
                        nowRow(forecast)
                        details(forecast)
                        HourStrip(hours: forecast.nextHours(from: Date()))
                        // Small: only now and the hours (spec WX-6).
                        if proxy.size.height > 270 { DayList(days: forecast.days) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if isActive { service.refreshIfStale() } }
        .onChange(of: isActive) { _, active in if active { service.refreshIfStale() } }
    }

    @ViewBuilder private var emptyState: some View {
        switch service.status {
        case .loading:
            ProgressView().controlSize(.small)
        case .denied:
            EmptyStateView(
                symbol: "location.slash", text: "Location Services are off for Dynotch. Save a place in Settings › Calendar › Weather."
            )
        case .needsPlace:
            EmptyStateView(
                symbol: "location", text: "Where should the weather be from? Use your location, or save a place in Settings › Calendar.",
                actionTitle: "Use My Location"
            ) {
                service.useMyLocation()
            }
        case .failed, .idle:
            EmptyStateView(symbol: "cloud.sun", text: "The weather could not be loaded.", actionTitle: "Try Again") {
                Task { await service.refresh() }
            }
        }
    }

    private func header(_ forecast: WeatherForecast) -> some View {
        HStack(spacing: 6) {
            Image(systemName: service.settings.usesLocation ? "location.fill" : "mappin")
                .font(.notch(size: 10))
                .foregroundStyle(.white.opacity(0.6))
            Text(service.placeName.isEmpty ? "Weather" : service.placeName)
                .font(.notch(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            // Older data offline (spec WX-4).
            if Date().timeIntervalSince(forecast.fetched) > WeatherService.interval * 1.5 {
                Text("Updated \(forecast.fetched.formatted(date: .omitted, time: .shortened))")
                    .font(.notch(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func nowRow(_ forecast: WeatherForecast) -> some View {
        let now = forecast.now
        return HStack(spacing: 12) {
            Image(systemName: WeatherCode.symbol(now.code, isDay: now.isDay))
                .symbolRenderingMode(.multicolor)
                .font(.notch(size: 34))
            Text(WeatherService.degrees(now.temperature))
                .font(.notch(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(WeatherCode.text(now.code))
                    .font(.notch(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                if let today = forecast.today {
                    Text("Feels \(WeatherService.degrees(now.feelsLike)) · H \(WeatherService.degrees(today.high)) "
                        + "L \(WeatherService.degrees(today.low))")
                        .font(.notch(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func details(_ forecast: WeatherForecast) -> some View {
        let imperial = Locale.current.measurementSystem == .us
        let today = forecast.today
        return HStack(spacing: 14) {
            detail("wind", "\(Int(forecast.now.wind.rounded())) \(imperial ? "mph" : "km/h")")
            detail("humidity", "\(Int(forecast.now.humidity.rounded()))%")
            if let today {
                detail("umbrella", "\(today.rainChance)%")
                detail("sun.max", "UV \(Int(today.uvIndex.rounded()))")
                if let sunrise = today.sunrise { detail("sunrise", sunrise.formatted(date: .omitted, time: .shortened)) }
                if let sunset = today.sunset { detail("sunset", sunset.formatted(date: .omitted, time: .shortened)) }
            }
        }
        .lineLimit(1)
    }

    private func detail(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.notch(size: 10))
            Text(text).font(.notch(size: 11, weight: .medium)).monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.75))
        .fixedSize()
    }
}

/// The next 24 hours, scrolling sideways (spec WX-6).
private struct HourStrip: View {
    let hours: [WeatherForecast.Hour]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(hours) { hour in
                    VStack(spacing: 5) {
                        Text(hour.time.formatted(.dateTime.hour()))
                            .font(.notch(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Image(systemName: WeatherCode.symbol(hour.code, isDay: hour.isDay))
                            .symbolRenderingMode(.multicolor)
                            .font(.notch(size: 15))
                            .frame(height: 18)
                        Text(WeatherService.degrees(hour.temperature))
                            .font(.notch(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(hour.rainChance >= 20 ? "\(hour.rainChance)%" : " ")
                            .font(.notch(size: 9, weight: .medium))
                            .foregroundStyle(Color.cyan)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
        .scrollIndicators(.never)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Color.white.level(0.06)))
    }
}

/// 7 days with a low–high bar against the week's range (spec WX-6).
private struct DayList: View {
    let days: [WeatherForecast.Day]

    var body: some View {
        let low = days.map(\.low).min() ?? 0
        let high = days.map(\.high).max() ?? 1
        ScrollView(.vertical) {
            VStack(spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    HStack(spacing: 10) {
                        Text(index == 0 ? "Today" : day.date.formatted(.dateTime.weekday(.abbreviated)))
                            .frame(width: 48, alignment: .leading)
                            .foregroundStyle(.white)
                        Image(systemName: WeatherCode.symbol(day.code))
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 22)
                        Text(day.rainChance >= 20 ? "\(day.rainChance)%" : "")
                            .foregroundStyle(Color.cyan)
                            .frame(width: 34, alignment: .leading)
                        Text(WeatherService.degrees(day.low)).foregroundStyle(.white.opacity(0.6)).frame(width: 34, alignment: .trailing)
                        RangeBar(low: day.low, high: day.high, weekLow: low, weekHigh: high)
                        Text(WeatherService.degrees(day.high)).foregroundStyle(.white).frame(width: 34, alignment: .leading)
                    }
                    .font(.notch(size: 12, weight: .medium))
                    .monospacedDigit()
                    .frame(height: 22)
                }
            }
        }
        .scrollIndicators(.never)
    }
}

private struct RangeBar: View {
    let low: Double
    let high: Double
    let weekLow: Double
    let weekHigh: Double

    var body: some View {
        GeometryReader { proxy in
            let span = max(weekHigh - weekLow, 1)
            let start = (low - weekLow) / span * proxy.size.width
            let width = max((high - low) / span * proxy.size.width, 4)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.level(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: width)
                    .offset(x: start)
            }
        }
        .frame(height: 5)
    }
}
