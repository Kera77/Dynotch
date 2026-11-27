import SwiftUI

/// Wingmate's own notifications, each kind can be turned off (spec E-25, SY-12b).
enum WingmateAlert: String, CaseIterable, Sendable {
    case memory
    case swap
    case system
    case aiUsage
    case batteries
    case updates

    var title: String {
        switch self {
        case .memory: "Low memory"
        case .swap: "Swap above the limit"
        case .system: "Disk full, Mac slowing down"
        case .aiUsage: "AI usage"
        case .batteries: "Batteries charged"
        case .updates: "Wingmate updated"
        }
    }
}

/// Settings › Notifications › Wingmate alerts (spec E-25).
struct WingmateAlertsSection: View {
    var preferences: NotificationPreferences

    var body: some View {
        Section {
            ForEach(WingmateAlert.allCases, id: \.self) { alert in
                Toggle(alert.title, isOn: Binding(
                    get: { preferences.isOn(alert) },
                    set: { preferences.set(alert, isOn: $0) }
                ))
            }
        } header: {
            Text("Wingmate alerts")
        } footer: {
            Text("Turned off, that kind does not pop up in the notch and is not listed; for the system "
                + "warnings neither is the red dot beside the notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
