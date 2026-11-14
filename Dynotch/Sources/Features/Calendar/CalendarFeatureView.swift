import SwiftUI

/// Next 7 days of events (spec K-1…K-6).
struct CalendarFeatureView: View {
    @ObservedObject var service: CalendarService

    var body: some View {
        switch service.access {
        case .granted:
            if service.days.isEmpty {
                placeholder(symbol: "calendar", text: "Nincs esemény a következő 7 napban.")
            } else {
                agenda
            }
        case .notDetermined:
            accessPrompt(text: "A Dynotch hozzáférést kér a naptáraidhoz.", button: "Hozzáférés engedélyezése")
        case .denied:
            accessPrompt(
                text: "Nincs naptár-hozzáférés. Engedélyezd: Adatvédelem › Naptárak › Dynotch.",
                button: "Rendszerbeállítások megnyitása"
            )
        }
    }

    private var agenda: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(service.days) { day in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Self.dayTitle(day.date, now: service.now))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        ForEach(day.events) { event in
                            EventRow(event: event, now: service.now) { service.join(event) }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.never)
        .foregroundStyle(.white)
    }

    private func placeholder(symbol: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 24))
            Text(text).font(.system(size: 13))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    static func dayTitle(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Ma" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Holnap"
        }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct EventRow: View {
    let event: CalendarEvent
    let now: Date
    let join: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: event.color.red, green: event.color.green, blue: event.color.blue))
                .frame(width: 3, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(timeText)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(event.isOngoing(at: now) && !event.isAllDay ? Color.green : .secondary)
            }

            Spacer(minLength: 8)

            if event.meetingURL != nil {
                Button(action: join) {
                    Label("Csatlakozás", systemImage: "video.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.blue)
            }
        }
    }

    private var timeText: String {
        if event.isAllDay { return "Egész nap" }
        let range = "\(event.start.formatted(date: .omitted, time: .shortened)) – "
            + event.end.formatted(date: .omitted, time: .shortened)
        return event.isOngoing(at: now) ? "Most · \(range)" : range
    }
}
