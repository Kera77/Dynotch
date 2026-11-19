import SwiftUI

/// Dynotch's own notifications, each kind can be turned off (spec E-25).
enum DynotchAlert: String, CaseIterable, Sendable {
    case system
    case aiUsage
    case batteries
    case updates

    var title: String {
        switch self {
        case .system: "System (swap, memory…)"
        case .aiUsage: "AI usage"
        case .batteries: "Batteries charged"
        case .updates: "Dynotch updated"
        }
    }
}

/// Settings › Notifications › Dynotch alerts (spec E-25).
struct DynotchAlertsSection: View {
    @ObservedObject var preferences: NotificationPreferences

    var body: some View {
        Section {
            ForEach(DynotchAlert.allCases, id: \.self) { alert in
                Toggle(alert.title, isOn: Binding(
                    get: { preferences.isOn(alert) },
                    set: { preferences.set(alert, isOn: $0) }
                ))
            }
        } header: {
            Text("Dynotch alerts")
        } footer: {
            Text("Turned off, that kind does not pop up in the notch and is not listed. "
                + "The red dot beside the notch is set in the System module's Options.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
