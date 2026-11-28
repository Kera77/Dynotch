import AppKit
import SwiftUI

/// The Calculator tile that counts on the tile itself (spec HT-42).
struct CalculatorKeypadTile: View {
    @State private var expression = ""
    @State private var result: String?

    private static let keys: [[String]] = [
        ["C", "⌫", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["0", "00", ",", "="]
    ]

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            display
            VStack(spacing: 3) {
                ForEach(Self.keys, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(row, id: \.self) { key in keyButton(key) }
                    }
                }
            }
        }
    }

    private var display: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(expression.isEmpty ? " " : expression)
                .font(.notch(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
            if let result {
                // After =, a click copies the result (spec HT-42).
                Button { Self.copy(result) } label: { resultText(result, final: true) }
                    .buttonStyle(.plain)
            } else {
                resultText(Self.preview(of: expression) ?? (expression.isEmpty ? "0" : " "), final: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func resultText(_ text: String, final: Bool) -> some View {
        Text(text)
            .font(.notch(size: 18, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(final ? .white : Color.white.level(0.7))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func keyButton(_ key: String) -> some View {
        Button {
            press(key)
        } label: {
            Text(key)
                .font(.notch(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Self.isOperator(key) ? Color.orange.opacity(0.75) : Theme.selectedFill)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(key)
    }

    private static func isOperator(_ key: String) -> Bool { ["÷", "×", "−", "+", "="].contains(key) }

    private func press(_ key: String) {
        switch key {
        case "C":
            expression = ""
            result = nil
        case "⌫":
            if result != nil { result = nil }
            if !expression.isEmpty { expression.removeLast() }
        case "=":
            if let value = CalculatorEngine.result(for: expression) { result = value }
        default:
            // A new number after a result starts over; an operator goes on from it.
            if let shown = result {
                expression = Self.isOperator(key) ? shown.replacingOccurrences(of: "\u{00A0}", with: "") : ""
                result = nil
            }
            expression += key
        }
    }

    /// The running result while typing, before =.
    static func preview(of expression: String) -> String? {
        CalculatorEngine.result(for: expression)
    }

    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// The Calculator's notepad on a tile: the same editor as the module, the same text; a click on
/// a result copies it (spec HT-47).
struct CalculatorNotepadTile: View {
    @Bindable var store: CalculatorStore

    var body: some View {
        CalculatorEditor(text: $store.text, isActive: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}

/// The Days tile: five days of the module's day strip, and the picked day's first three events
/// with Join for online meetings (spec HT-43, HT-46).
struct DaysTileContent: View {
    @Bindable var calendar: CalendarService

    /// Today and two days each side (spec HT-46).
    static let span = 2

    var body: some View {
        if calendar.access != .granted {
            TileEmptyView(title: "Calendar", text: "Needs access")
        } else {
            HStack(alignment: .center, spacing: 12) {
                DayStripView(selectedDay: $calendar.selectedDay, today: calendar.today, counts: calendar.dayCounts, span: Self.span)
                    .frame(width: DayCell.width * CGFloat(2 * Self.span + 1))
                    .id(calendar.opens)
                    .onHover { MonthTilePager.shared.isOverDays = $0 }
                events
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onDisappear { MonthTilePager.shared.isOverDays = false }
        }
    }

    @ViewBuilder private var events: some View {
        let events = calendar.events(on: calendar.selectedDay)
        if events.isEmpty {
            Text(calendar.selectedDay == calendar.today ? "Nothing for today" : "Nothing on this day")
                .font(.notch(size: 11))
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(events.prefix(3)) { event in eventRow(event) }
            }
            .overlay(alignment: .topTrailing) {
                if events.count > 3 {
                    Text("+\(events.count - 3)").font(.notch(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                        .offset(y: -12)
                }
            }
        }
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(event.color.color).frame(width: 3, height: 12)
            Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                .font(.notch(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(event.title)
                .font(.notch(size: 11, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 4)
            if event.meetingURL != nil {
                Button { calendar.join(event) } label: {
                    Label("Join", systemImage: "video.fill")
                        .font(.notch(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .frame(height: 17)
                        .background(Capsule().fill(Theme.blue))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
        }
        .frame(height: 18)
    }
}
