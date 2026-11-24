import SwiftUI

/// Settings › Calendar › Weather (spec WX-1, WX-2, WX-7, WX-8).
struct WeatherSettingsSection: View {
    @Bindable var settings = WeatherSettings.shared
    @State private var search = ""
    @State private var found: [WeatherPlace] = []
    @State private var searching: Task<Void, Never>?

    var body: some View {
        Section {
            Toggle("Weather tab", isOn: $settings.isOn)
            Picker("Location", selection: $settings.usesLocation) {
                Text("Automatic (Location Services)").tag(true)
                Text("City").tag(false)
            }
            .disabled(!settings.isOn)
            if !settings.usesLocation {
                citySearch.disabled(!settings.isOn)
            }
            Toggle("Morning forecast", isOn: $settings.morningOn)
                .disabled(!settings.isOn)
            DatePicker("Not before", selection: $settings.notBeforeDate, displayedComponents: .hourAndMinute)
                .disabled(!settings.isOn || !settings.morningOn)
        } header: {
            Text("Weather")
        } footer: {
            Text("From Open-Meteo: only the place, rounded to about 1 km, is sent. The morning forecast comes once a day, "
                + "at the first unlock after the time set.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var citySearch: some View {
        LabeledContent("City") {
            Text(settings.city.map { $0.name + ($0.detail.isEmpty ? "" : ", \($0.detail)") } ?? "None")
                .foregroundStyle(.secondary)
        }
        TextField("Search for a city", text: $search)
            .onChange(of: search) { _, text in lookUp(text) }
        ForEach(found) { place in
            Button {
                settings.city = place
                search = ""
                found = []
            } label: {
                HStack {
                    Text(place.name)
                    Text(place.detail).foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func lookUp(_ text: String) {
        searching?.cancel()
        searching = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let places = await WeatherService.search(text)
            guard !Task.isCancelled else { return }
            found = places
        }
    }
}
