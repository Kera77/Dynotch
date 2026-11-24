import SwiftUI

/// The quick toggles as tiles, like the Control Centre (spec QT-1…QT-3).
struct TogglesTabView: View {
    let toggles: QuickToggleService
    let settings: ToolsSettings
    var isActive: Bool

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86, maximum: 140), spacing: 10)], spacing: 10) {
                ForEach(settings.shownToggles) { toggle in
                    tile(toggle)
                }
            }
            .padding(.top, 2)
        }
        .scrollIndicators(.never)
        // States changed elsewhere show when the tab opens (spec QT-1).
        .onAppear { toggles.refresh() }
        .onChange(of: isActive) { _, active in if active { toggles.refresh() } }
    }

    private func tile(_ toggle: QuickToggle) -> some View {
        let isOn = toggles.isOn(toggle)
        let needsSetup = toggles.needsSetup(toggle)
        return Button {
            if needsSetup { return }
            toggles.toggle(toggle)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: toggle.symbol(isOn: isOn))
                    .font(.notch(size: 15, weight: .semibold))
                    .foregroundStyle(isOn ? Color.white : Color.white.opacity(needsSetup ? 0.35 : 0.85))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(isOn && !toggle.isAction ? Theme.blue : Theme.fill))
                Text(toggle.title)
                    .font(.notch(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(needsSetup ? 0.4 : 0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = detail(toggle, needsSetup: needsSetup) {
                    Text(detail)
                        .font(.notch(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(needsSetup ? "Choose its two Shortcuts in Settings › Tools › Quick toggles" : toggle.title)
        .contextMenu {
            if toggle == .keepAwake {
                ForEach(KeepAwakeLength.allCases) { length in
                    Button(length.title) { toggles.keepAwake(length) }
                }
                if isOn { Button("Turn Off") { toggles.stopKeepingAwake() } }
            }
        }
    }

    private func detail(_ toggle: QuickToggle, needsSetup: Bool) -> String? {
        if needsSetup { return "Set up in Settings" }
        guard toggle == .keepAwake, toggles.isOn(.keepAwake) else { return nil }
        if toggles.keepAwakeUntilTimerEnds { return "Until a timer ends" }
        if let until = toggles.keepAwakeUntil { return "Until \(until.formatted(date: .omitted, time: .shortened))" }
        return nil
    }
}
