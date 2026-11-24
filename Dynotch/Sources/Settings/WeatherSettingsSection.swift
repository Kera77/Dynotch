import SwiftUI

/// Settings › Calendar › Weather (spec WX-1, WX-2, WX-7, WX-8, WX-9).
struct WeatherSettingsSection: View {
    @Bindable var settings = WeatherSettings.shared
    @State private var search = ""
    @State private var found: [WeatherPlace] = []
    @State private var searching: Task<Void, Never>?

    var body: some View {
        Section {
            Toggle("Weather tab", isOn: $settings.isOn)
            Picker("Location", selection: $settings.usesLocation) {
                Text("Current location").tag(true)
                Text("Saved place").tag(false)
            }
            .disabled(!settings.isOn)
            savedPlaces.disabled(!settings.isOn)
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

    /// The saved places with the chosen one ticked, and the search that adds one (spec WX-9).
    @ViewBuilder private var savedPlaces: some View {
        ForEach(settings.places) { place in
            HStack {
                Button {
                    settings.city = place
                } label: {
                    HStack {
                        Image(systemName: settings.city == place ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(settings.city == place ? Color.accentColor : .secondary)
                        Text(place.name)
                        Text(place.detail).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    settings.remove(place)
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove this place")
            }
        }
        TextField(settings.places.isEmpty ? "Search for a place to save" : "Add a place", text: $search)
            .onChange(of: search) { _, text in lookUp(text) }
        ForEach(found) { place in
            Button {
                settings.add(place)
                search = ""
                found = []
            } label: {
                HStack {
                    Image(systemName: "plus.circle").foregroundStyle(.secondary)
                    Text(place.name)
                    Text(place.detail).foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        if settings.usesLocation, !settings.places.isEmpty {
            Text("When the current location is not known, the ticked place is shown.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
