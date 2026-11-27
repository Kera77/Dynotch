import AppKit
import SwiftUI

/// The Terminal module: the tabs above, the shown shell below, filling the module (spec TE-1…TE-6).
struct TerminalFeatureView: View {
    var store: TerminalStore
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if let session = store.selected {
                TerminalHost(session: session, store: store, isActive: isActive)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The shell starts when the module shows, and again after the last one exited (spec TE-3).
        .task(id: isActive) {
            if isActive, store.selected == nil { store.newSession() }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            // Titles follow the program in front and the folder (spec TE-4).
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(store.sessions) { session in
                            TerminalTab(
                                title: session.title, isSelected: session.id == store.selected?.id,
                                select: { store.selectedID = session.id }, close: { store.close(session) }
                            )
                        }
                    }
                }
                .scrollIndicators(.never)
            }
            Button {
                store.newSession()
            } label: {
                Image(systemName: "plus").font(.notch(size: 11, weight: .semibold))
            }
            .buttonStyle(.notch)
            .disabled(store.sessions.count >= TerminalStore.maxTabs)
            .help("New tab (⌘T)")
            Spacer(minLength: 4)
            Button(action: openInTerminal) {
                Image(systemName: "arrow.up.forward.app").font(.notch(size: 12, weight: .semibold))
            }
            .buttonStyle(.notch)
            .help("Open this folder in Terminal")
            .accessibilityLabel("Open in Terminal")
        }
        .foregroundStyle(Color.white.level(0.85))
        .frame(height: 22)
    }

    /// Terminal opens in the shown tab's folder, else in the home folder (spec TE-6).
    private func openInTerminal() {
        let folder = store.selected?.directory ?? NSHomeDirectory()
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([URL(fileURLWithPath: folder, isDirectory: true)], withApplicationAt: terminal,
                                configuration: NSWorkspace.OpenConfiguration())
    }
}

/// One tab's capsule: its title and an × to close it.
private struct TerminalTab: View {
    let title: String
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.notch(size: 11, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: 120)
            Button(action: close) {
                Image(systemName: "xmark").font(.notch(size: 8, weight: .bold))
            }
            .buttonStyle(.notch)
            .help("Close tab (⌘W)")
            .accessibilityLabel("Close \(title)")
        }
        .foregroundStyle(isSelected ? Color.white : Color.white.level(0.6))
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(Capsule(style: .continuous).fill(isSelected ? Color.white.level(0.22) : Color.white.level(0.08)))
        .contentShape(Capsule())
        .onTapGesture(perform: select)
    }
}

/// Puts the shown tab's terminal view into the panel and gives it the keyboard while the module is active.
private struct TerminalHost: NSViewRepresentable {
    let session: TerminalSession
    let store: TerminalStore
    let isActive: Bool

    func makeNSView(context: Context) -> TerminalContainerView {
        let container = TerminalContainerView(frame: .zero)
        container.store = store
        return container
    }

    func updateNSView(_ container: TerminalContainerView, context: Context) {
        container.store = store
        // Every display's panel has this page: only the one showing the module takes the view.
        guard isActive else { return }
        container.show(session.view, focus: false)
        // The panel becomes key a moment after it opens.
        DispatchQueue.main.async { container.takeFocus() }
    }
}

/// The Terminal module's wings (spec PV-9): the shown tab left, how many are open right.
enum TerminalWing {
    static func tabs(_ count: Int) -> String {
        count == 0 ? "No shell running" : "\(count) tab\(count == 1 ? "" : "s")"
    }
}
