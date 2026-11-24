import AppKit
import SwiftUI

// MARK: - Stopwatch (spec TM-10…TM-12)

struct StopwatchTabView: View {
    let service: ToolsService

    var body: some View {
        let stopwatch = service.stopwatch
        VStack(spacing: 10) {
            // Tenths only while it is on screen (spec TM-12).
            TimelineView(.periodic(from: .now, by: stopwatch.isRunning ? 0.1 : 60)) { context in
                Text(ClockText.text(stopwatch.elapsed(at: context.date), tenths: true))
                    .font(.notch(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            HStack(spacing: 8) {
                ToolsPill(
                    title: stopwatch.isRunning ? "Pause" : "Start", symbol: stopwatch.isRunning ? "pause.fill" : "play.fill",
                    prominent: true, tint: stopwatch.isRunning ? .orange : Theme.green, action: service.startOrPauseStopwatch
                )
                if stopwatch.isRunning {
                    ToolsPill(title: "Lap", symbol: "flag.fill", action: service.lap)
                } else if !stopwatch.isReset {
                    ToolsPill(title: "Reset", symbol: "arrow.counterclockwise", action: service.resetStopwatch)
                }
                if !stopwatch.lapTotals.isEmpty {
                    ToolsPill(title: "Copy", symbol: "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(StopwatchState.copyText(stopwatch.laps), forType: .string)
                    }
                }
            }
            lapList(stopwatch.laps)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func lapList(_ laps: [StopwatchState.Lap]) -> some View {
        let extremes = StopwatchState.extremes(of: laps)
        return ScrollView(.vertical) {
            VStack(spacing: 2) {
                ForEach(laps) { lap in
                    HStack {
                        Text("Lap \(lap.number)").foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text(ClockText.text(lap.time, tenths: true))
                            .foregroundStyle(color(for: lap.number, extremes: extremes))
                        Text(ClockText.text(lap.total, tenths: true))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.notch(size: 12, weight: .medium))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                }
            }
        }
        .scrollIndicators(.never)
    }

    private func color(for number: Int, extremes: (fastest: Int, slowest: Int)?) -> Color {
        guard let extremes else { return .white }
        if number == extremes.fastest { return Theme.green }
        if number == extremes.slowest { return Theme.red }
        return .white
    }
}

// MARK: - Pomodoro (spec TM-14…TM-17)

struct PomodoroTabView: View {
    let service: ToolsService
    let settings: ToolsSettings

    var body: some View {
        let state = service.pomodoro
        let plan = settings.plan
        let color = state.phase.isBreak ? Theme.green : Theme.red
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ZStack {
                        Circle().stroke(Color.white.level(0.12), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: state.fractionLeft(at: context.date, plan: plan))
                            .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text(ClockText.text(state.remaining(at: context.date, plan: plan)))
                                .font(.notch(size: 26, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                            Text(state.phase.title)
                                .font(.notch(size: 11, weight: .semibold))
                                .foregroundStyle(color)
                        }
                    }
                    .frame(width: 120, height: 120)
                }
                cycleDots(state: state)
                buttons(state: state)
            }
            Spacer(minLength: 0)
            WeekBars(history: service.history)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func cycleDots(state: PomodoroState) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<max(settings.longBreakAfter, 1), id: \.self) { index in
                Circle()
                    .fill(index < state.doneInCycle ? Theme.red : Color.white.level(0.2))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func buttons(state: PomodoroState) -> some View {
        HStack(spacing: 8) {
            ToolsPill(
                title: state.isRunning ? "Pause" : "Start", symbol: state.isRunning ? "pause.fill" : "play.fill", prominent: true,
                tint: state.isRunning ? .orange : Theme.green, action: service.startOrPausePomodoro
            )
            ToolsIconButton(symbol: "forward.end.fill", help: "Skip to the next phase", action: service.skipPhase)
            ToolsIconButton(symbol: "arrow.counterclockwise", help: "Reset", action: service.resetPomodoro)
        }
    }
}

/// Today's Focus count and the last 7 days (spec TM-17).
private struct WeekBars: View {
    let history: PomodoroHistory

    var body: some View {
        let days = history.lastWeek(endingAt: Date())
        let peak = max(days.map(\.done).max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 6) {
            Text("Today: \(days.last?.done ?? 0)")
                .font(.notch(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(day.done >= 1 ? Theme.red.opacity(0.85) : Color.white.level(0.12))
                            .frame(width: 12, height: max(3, 50 * CGFloat(day.done) / CGFloat(peak)))
                        Text(day.day.formatted(.dateTime.weekday(.narrow)))
                            .font(.notch(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .frame(height: 66, alignment: .bottom)
        }
    }
}
