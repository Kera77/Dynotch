import SwiftUI

/// Shown beside the closed notch shortly before an event (spec K-7…K-9):
/// calendar icon on the left, countdown on the right.
struct UpcomingEventIndicator: View {
    let event: CalendarEvent
    let now: Date
    let notchWidth: CGFloat
    let sideWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: event.meetingURL != nil ? "video.fill" : "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: sideWidth)
            Color.clear.frame(width: notchWidth)
            Text(countdown)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(width: sideWidth)
        }
        .help(event.title)
    }

    private var color: Color {
        Color(red: event.color.red, green: event.color.green, blue: event.color.blue)
    }

    private var countdown: String {
        let minutes = CalendarAgenda.minutesUntil(event.start, now: now)
        return minutes == 0 ? "most" : "\(minutes)p"
    }
}
