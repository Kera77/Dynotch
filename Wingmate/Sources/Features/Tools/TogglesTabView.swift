import SwiftUI

/// The quick toggles as tiles, like the Control Centre (spec QT-1…QT-3, QT-6): a click switches,
/// a drag puts a tile elsewhere (spec QT-8).
struct TogglesTabView: View {
    let toggles: QuickToggleService
    let settings: ToolsSettings
    var isActive: Bool

    @State private var frames: [QuickToggle: CGRect] = [:]
    @State private var dragged: QuickToggle?
    @State private var lastMove = Date.distantPast
    private static let space = "QuickToggles"

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86, maximum: 140), spacing: 10, alignment: .top)], spacing: 10) {
                ForEach(settings.shownToggles) { toggle in
                    tile(toggle)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frames[toggle] = $0 }
                        .opacity(dragged == toggle ? 0.45 : 1)
                        .scaleEffect(dragged == toggle ? 1.06 : 1)
                        .gesture(reorder(toggle))
                }
            }
            .coordinateSpace(name: Self.space)
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
        return VStack(spacing: 6) {
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
            // A fixed line for the note, so showing one does not push the row down (spec QT-11).
            Text(detail(toggle, needsSetup: needsSetup) ?? " ")
                .font(.notch(size: 9, weight: isConfirming(toggle) ? .semibold : .regular))
                .foregroundStyle(isConfirming(toggle) ? Theme.red : .white.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if !needsSetup { toggles.toggle(toggle) } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if !needsSetup { toggles.toggle(toggle) } }
        .help(needsSetup ? "Choose its two Shortcuts in Settings › Tools › Quick toggles" : "\(toggle.title) (drag to reorder)")
        .contextMenu {
            if toggle == .keepAwake {
                ForEach(KeepAwakeLength.allCases) { length in
                    Button(length.title) { toggles.keepAwake(length) }
                }
                if isOn { Button("Turn Off") { toggles.stopKeepingAwake() } }
            }
        }
    }

    /// Dragging a tile over another one puts it there; the order is the settings' one (spec QT-8).
    private func reorder(_ toggle: QuickToggle) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if dragged != toggle { dragged = toggle }
                // A short pause after each move, while the tiles slide, so it does not swing back.
                guard Date().timeIntervalSince(lastMove) > 0.2,
                      let target = frames.first(where: { $0.key != toggle && $0.value.contains(value.location) })?.key
                else { return }
                lastMove = Date()
                withAnimation(Motion.quick) { settings.moveToggle(toggle, onto: target) }
            }
            .onEnded { _ in dragged = nil }
    }

    /// Empty Trash waits for its second click: the note is red (spec QT-11).
    private func isConfirming(_ toggle: QuickToggle) -> Bool {
        toggle == .emptyTrash && toggles.notes[toggle] == QuickToggleService.clickAgain
    }

    private func detail(_ toggle: QuickToggle, needsSetup: Bool) -> String? {
        if needsSetup { return "Set up in Settings" }
        if let note = toggles.notes[toggle] { return note }
        guard toggle == .keepAwake, toggles.isOn(.keepAwake) else { return nil }
        if toggles.keepAwakeUntilTimerEnds { return "Until a timer ends" }
        if let until = toggles.keepAwakeUntil { return "Until \(until.formatted(date: .omitted, time: .shortened))" }
        return nil
    }
}
