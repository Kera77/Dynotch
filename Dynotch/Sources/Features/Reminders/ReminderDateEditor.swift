import SwiftUI

/// The day of a reminder, inside the notch instead of a system pop-up (spec R-24): quick
/// choices, the chosen day, and a small month under it.
struct ReminderDayPicker: View {
    @Binding var due: Date
    /// Called when the month opens, so the detail scrolls it fully into view (spec R-25).
    var onShowMonth: () -> Void = {}
    @State private var showsMonth = false

    static let monthID = "reminder-month"
    @State private var month = Date()

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Narrow: the chosen day under the quick choices.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { quickChips; Spacer(minLength: 0); dayChip }
                VStack(alignment: .leading, spacing: 6) { HStack(spacing: 6) { quickChips }; dayChip }
            }
            if showsMonth {
                ReminderMonth(month: $month, selected: due) { setDay($0) }
                    .id(Self.monthID)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder private var quickChips: some View {
        ForEach(Self.quickDays, id: \.title) { quick in
            ReminderChip(title: quick.title, isSelected: calendar.isDate(due, inSameDayAs: quick.day(Date()))) {
                setDay(quick.day(Date()))
            }
        }
    }

    private var dayChip: some View {
        ReminderChip(
            title: due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
            symbol: showsMonth ? "chevron.up" : "chevron.down", isSelected: showsMonth
        ) {
            month = due
            withAnimation(Motion.quick) { showsMonth.toggle() }
            if showsMonth { onShowMonth() }
        }
    }

    /// Keeps the time of day; only the day changes.
    private func setDay(_ day: Date) {
        let time = calendar.dateComponents([.hour, .minute], from: due)
        due = calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: day) ?? day
        month = due
    }

    private struct QuickDay {
        let title: String
        let day: (Date) -> Date
    }

    private static let quickDays: [QuickDay] = [
        QuickDay(title: "Today") { $0 },
        QuickDay(title: "Tomorrow") { Calendar.current.date(byAdding: .day, value: 1, to: $0) ?? $0 },
        QuickDay(title: "Next week") { Calendar.current.date(byAdding: .day, value: 7, to: $0) ?? $0 }
    ]
}

/// A small month like the Calendar module's (spec R-24).
private struct ReminderMonth: View {
    @Binding var month: Date
    let selected: Date
    let select: (Date) -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        let calendar = Calendar.current
        let days = CalendarAgenda.monthGrid(for: month)
        let today = calendar.startOfDay(for: Date())
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(month.formatted(.dateTime.year().month(.wide)).capitalized)
                    .font(.notch(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                CalendarIconButton(symbol: "chevron.left", help: "Previous month") { change(-1) }
                CalendarIconButton(symbol: "chevron.right", help: "Next month") { change(1) }
            }
            LazyVGrid(columns: Self.columns, spacing: 0) {
                ForEach(days.prefix(7), id: \.self) { day in
                    Text(day.formatted(.dateTime.weekday(.narrow)).uppercased())
                        .font(.notch(size: 9, weight: .semibold))
                        .foregroundStyle(Color.white.level(0.45))
                        .frame(height: 14)
                }
                ForEach(days, id: \.self) { day in
                    cell(day, inMonth: calendar.isDate(day, equalTo: month, toGranularity: .month),
                         isToday: day == today, isSelected: calendar.isDate(day, inSameDayAs: selected))
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).fill(Color.white.level(0.05)))
    }

    private func cell(_ day: Date, inMonth: Bool, isToday: Bool, isSelected: Bool) -> some View {
        Text(day.formatted(.dateTime.day()))
            .font(.notch(size: 11, weight: isSelected || isToday ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(isToday || isSelected ? Color.white : Color.white.level(inMonth ? 0.85 : 0.3))
            .frame(width: 22, height: 22)
            .background(Circle().fill(isSelected ? Theme.blue : isToday ? Color.white.level(0.18) : .clear))
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .contentShape(Rectangle())
            .onTapGesture { select(day) }
    }

    private func change(_ months: Int) {
        withAnimation(Motion.quick) { month = Calendar.current.date(byAdding: .month, value: months, to: month) ?? month }
    }
}

/// The time of a reminder: quick choices and hour : minute with steppers (spec R-24).
struct ReminderTimePicker: View {
    @Binding var due: Date

    private var calendar: Calendar { .current }
    private var hour: Int { calendar.component(.hour, from: due) }
    private var minute: Int { calendar.component(.minute, from: due) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { quickChips; Spacer(minLength: 0); clock }
            VStack(alignment: .leading, spacing: 6) { HStack(spacing: 6) { quickChips }; clock }
        }
    }

    @ViewBuilder private var quickChips: some View {
        ForEach([9, 12, 18], id: \.self) { quick in
            ReminderChip(title: "\(quick):00", isSelected: hour == quick && minute == 0) { set(hour: quick, minute: 0) }
        }
    }

    private var clock: some View {
        HStack(spacing: 2) {
            stepper(value: String(format: "%02d", hour), help: "hour") { set(hour: (hour + $0 + 24) % 24, minute: minute) }
            Text(":").font(.notch(size: 15, weight: .semibold)).foregroundStyle(Color.white.level(0.6))
            stepper(value: String(format: "%02d", minute), help: "minute") { step in
                // Five minutes a step, onto the grid of fives.
                let next = step > 0 ? (minute / 5 + 1) * 5 : ((minute + 4) / 5 - 1) * 5
                set(hour: hour, minute: (next + 60) % 60)
            }
        }
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).fill(Color.white.level(0.08)))
    }

    private func stepper(value: String, help: String, step: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 0) {
            arrow("chevron.up", help: "Later \(help)") { step(1) }
            Text(value)
                .font(.notch(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
            arrow("chevron.down", help: "Earlier \(help)") { step(-1) }
        }
    }

    private func arrow(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.notch(size: 8, weight: .bold))
                .foregroundStyle(Color.white.level(0.55))
                .frame(width: 26, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .help(help.prefix(1).uppercased() + help.dropFirst())
        .accessibilityLabel(help)
    }

    private func set(hour: Int, minute: Int) {
        due = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: due) ?? due
    }
}

/// A quick choice as a capsule; the chosen one in the accent colour.
struct ReminderChip: View {
    let title: String
    var symbol: String?
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).lineLimit(1)
                if let symbol { Image(systemName: symbol).font(.notch(size: 8, weight: .bold)) }
            }
            .font(.notch(size: 11, weight: .medium))
            .foregroundStyle(isSelected ? Color.white : Color.white.level(0.8))
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(Capsule(style: .continuous).fill(isSelected ? Theme.blue.opacity(0.85) : Color.white.level(0.1)))
            .contentShape(Capsule())
        }
        .buttonStyle(.notch)
        .fixedSize()
    }
}

/// A choice of the details as a soft capsule with the usual menu (spec R-24).
struct ReminderMenu<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(title: String, value: Value)]
    var isEnabled = true

    var body: some View {
        Menu {
            Picker("", selection: $selection) {
                ForEach(options, id: \.value) { Text($0.title).tag($0.value) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 4) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.notch(size: 8, weight: .semibold))
            }
            .font(.notch(size: 11, weight: .medium))
            .foregroundStyle(Color.white.level(isEnabled ? 0.85 : 0.35))
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(Capsule(style: .continuous).fill(Color.white.level(0.1)))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.notch)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(!isEnabled)
    }
}
