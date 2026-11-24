import SwiftUI

/// The Tools module (spec TM-1): Timer | Stopwatch | Pomodoro | Toggles, the tabs that are on.
struct ToolsFeatureView: View {
    let service = ToolsService.shared
    let settings = ToolsSettings.shared
    var isActive: Bool

    var body: some View {
        let tabs = settings.shownTabs
        let shown = tabs.contains(settings.tab) ? settings.tab : (tabs.first ?? .timer)
        VStack(alignment: .leading, spacing: 8) {
            if tabs.count > 1 {
                CapsulePicker(items: tabs, selection: Binding(get: { shown }, set: { settings.tab = $0 }), title: \.title)
            }
            Group {
                switch shown {
                case .timer: TimerTabView(service: service, settings: settings)
                case .stopwatch: StopwatchTabView(service: service)
                case .pomodoro: PomodoroTabView(service: service, settings: settings)
                case .toggles: TogglesTabView(toggles: .shared, settings: settings, isActive: isActive)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A capsule button of the Tools: presets, Start, Lap (spec TM-7, TM-10).
struct ToolsPill: View {
    let title: String
    var symbol: String?
    var prominent = false
    var tint: Color = Theme.blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.notch(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(prominent ? tint : Theme.fill))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A round icon button of the Tools (pause, +1 min, X).
struct ToolsIconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Theme.fill))
        }
        .buttonStyle(.notch)
        .help(help)
    }
}

// MARK: - Timer (spec TM-7…TM-9)

struct TimerTabView: View {
    let service: ToolsService
    let settings: ToolsSettings
    @State private var typed = ""
    @State private var name = ""
    @State private var invalid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(settings.presets, id: \.self) { minutes in
                        ToolsPill(title: ClockText.duration(TimeInterval(minutes * 60))) { start(TimeInterval(minutes * 60)) }
                    }
                    ForEach(service.recent, id: \.self) { seconds in
                        ToolsPill(title: ClockText.duration(seconds), symbol: "clock.arrow.circlepath") { start(seconds) }
                    }
                }
            }
            .scrollIndicators(.never)
            entryRow
            ScrollView(.vertical) {
                VStack(spacing: 6) {
                    ForEach(service.sortedTimers) { timer in
                        TimerRow(timer: timer, service: service)
                    }
                }
            }
            .scrollIndicators(.never)
            .overlay {
                if service.timers.isEmpty {
                    Text("Pick a time above, or type one: 12, 1:30, 90s, 1h 15m")
                        .font(.notch(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.level(0.5))
                }
            }
        }
    }

    private var entryRow: some View {
        HStack(spacing: 6) {
            field("Time: 12, 1:30, 1h 15m", text: $typed)
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.red, lineWidth: invalid ? 1 : 0))
            field("Name (optional)", text: $name)
            ToolsPill(title: "Start", symbol: "play.fill", prominent: true, action: startTyped)
                .disabled(service.timers.count >= ToolsService.maxTimers)
        }
    }

    private func field(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .font(.notch(size: 12))
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.level(0.08)))
            .onSubmit(startTyped)
    }

    private func startTyped() {
        guard let seconds = DurationInput.parse(typed) else {
            invalid = true
            return
        }
        invalid = false
        if service.startTimer(seconds, name: name, custom: true) {
            typed = ""
            name = ""
        }
    }

    private func start(_ seconds: TimeInterval) {
        service.startTimer(seconds, name: name)
        name = ""
    }
}

private struct TimerRow: View {
    let timer: CountdownTimer
    let service: ToolsService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(timer.title)
                            .font(.notch(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(ClockText.text(timer.remaining(at: context.date)))
                            .font(.notch(size: 20, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(timer.isPaused ? 0.5 : 1))
                    }
                    ProgressView(value: timer.fractionLeft(at: context.date))
                        .progressViewStyle(.linear)
                        .tint(timer.isPaused ? .gray : Theme.blue)
                }
                ToolsIconButton(symbol: timer.isPaused ? "play.fill" : "pause.fill", help: timer.isPaused ? "Resume" : "Pause") {
                    service.pauseOrResume(timer.id)
                }
                ToolsIconButton(symbol: "plus", help: "+1 min") { service.addMinute(timer.id) }
                ToolsIconButton(symbol: "xmark", help: "Cancel") { service.cancel(timer.id) }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Color.white.level(0.06)))
        }
    }
}
