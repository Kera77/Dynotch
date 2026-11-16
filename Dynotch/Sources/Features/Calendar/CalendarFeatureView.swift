import SwiftUI

/// Calendar feature: compact day view, or the full month view in the large panel.
struct CalendarFeatureView: View {
    @ObservedObject var service: CalendarService
    @ObservedObject var model: NotchViewModel

    var body: some View {
        switch service.access {
        case .granted:
            if model.isLarge {
                CalendarFullView(service: service) { setLarge(false) }
                    .transition(.opacity)
            } else {
                CalendarCompactView(service: service) { setLarge(true) }
                    .transition(.opacity)
            }
        case .notDetermined:
            accessPrompt(text: "Dynotch needs access to your calendars.", button: "Allow Access")
        case .denied:
            accessPrompt(
                text: "No calendar access. Allow it in Privacy & Security › Calendars › Dynotch.",
                button: "Open System Settings"
            )
        }
    }

    private func setLarge(_ large: Bool) {
        withAnimation(NotchController.animation) { model.setCalendarLarge(large) }
    }

    private func accessPrompt(text: String, button: String) -> some View {
        VStack(spacing: 10) {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(button) { service.requestAccess() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
