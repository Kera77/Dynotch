import AppKit
import SwiftUI

/// Lock control shown in the menu bar panel's bottom bar.
struct PinControl {
    let isPinned: Bool
    let toggle: () -> Void
}

/// Sidebar with folders and notes, editor, and a bottom bar (spec J-2…J-8).
struct NotesWorkspaceView: View {
    var store: NotesStore
    /// Only the visible view talks to Notes, so hidden pages don't trigger the permission prompt.
    let isActive: Bool
    var pin: PinControl?

    @State private var editorController = RichNoteController()

    static var accent: Color { Color.yellow }
    /// The notes list grows with a resized module (spec RS-5).
    @State private var width: CGFloat = 0

    nonisolated static func sidebarWidth(for width: CGFloat) -> CGFloat {
        Responsive.share(0.26, of: width, in: 210...320)
    }

    var body: some View {
        Group {
            switch store.access {
            case .ready:
                workspace
            case .unknown, .loading:
                message(text: "Loading notes…", showsProgress: true)
            case .denied:
                accessPrompt(
                    text: "Dynotch needs permission to control Notes.\n"
                        + "System Settings › Privacy & Security › Automation › Dynotch › Notes",
                    button: "Open System Settings",
                    action: store.openAutomationSettings
                )
            case .failed(let error):
                accessPrompt(text: "Notes is not available.\n\(error)", button: "Retry", action: store.retry)
            }
        }
        .onAppear { if isActive { store.activate() } }
        .onChange(of: isActive) { _, active in
            if active { store.activate() }
        }
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                NotesSidebar(store: store)
                    .frame(width: Self.sidebarWidth(for: width))
                Rectangle()
                    .fill(Color.white.level(0.1))
                    .frame(width: 1)
                editor
            }
            bottomBar
        }
        .readWidth($width)
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 4) {
            RichNoteToolbar(controller: editorController, isEnabled: store.isEditable)
                .padding(.trailing, 4)
                .padding(.top, 2)
            RichNoteEditor(
                content: Binding(get: { store.content }, set: { store.edit($0) }),
                isEditable: store.isEditable,
                placeholder: store.selection == .draft ? "New note. The first line becomes its title." : nil,
                caretColor: NSColor(Self.accent),
                controller: editorController
            )
            .overlay {
                if store.isLoadingNote {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .padding(.leading, 6)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Text(statusText)
                .font(.notch(size: 11, weight: .medium))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .help(statusText)
            Spacer(minLength: 8)

            if store.readOnlyReason != nil, store.convertibleHTML != nil {
                Button("Make editable", action: store.makeListsEditable)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Turns the list into a to-do list Dynotch can edit (○ / ◉ lines). Apple Notes gets this form "
                        + "with your first change; its own checkboxes and their ticks are not kept.")
            }

            if store.saveState == .conflict {
                Button("Reload", action: store.reloadFromNotes)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Overwrite", action: store.overwriteNotes)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if let pin {
                Rectangle()
                    .fill(Color.white.level(0.15))
                    .frame(width: 1, height: 16)
                PinButton(isPinned: pin.isPinned, action: pin.toggle)
                    .frame(width: 30, height: 28)
                    .background(RoundedRectangle(cornerRadius: AppleStyle.corner(7), style: .continuous).fill(Color.white.level(0.14)))
            }

            switch store.selection {
            case .draft:
                Button(action: store.saveDraftToNotes) {
                    Text("Save to Notes")
                        .font(.notch(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(7), style: .continuous).fill(Self.accent))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.notch)
                .disabled(store.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.selectedFolder == nil)
                .opacity(store.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                .help("New note in \"\(store.selectedFolder?.name ?? "")\"")
            case .note:
                Button(action: store.openInNotes) {
                    Label("Open in Notes", systemImage: "arrow.up.forward.app")
                        .font(.notch(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(7), style: .continuous).fill(Color.white.level(0.14)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.notch)
            }
        }
        .padding(.top, 8)
    }

    private var statusText: String {
        if let reason = store.readOnlyReason { return reason }
        switch store.saveState {
        case .idle:
            return store.selection == .draft ? "Draft, only stored here" : "Changes are saved to Notes automatically"
        case .pending:
            return "Edited…"
        case .saving:
            return "Saving…"
        case .saved(let date):
            return "Saved to Notes · \(date.formatted(date: .omitted, time: .shortened))"
        case .conflict:
            return "The note was changed in Notes meanwhile"
        case .failed(let error):
            return "Error: \(error)"
        }
    }

    private var statusColor: Color {
        switch store.saveState {
        case .conflict, .failed: Color.red
        default: Color.white.level(store.readOnlyReason == nil ? 0.6 : 0.8)
        }
    }

    // MARK: - States

    private func message(text: String, showsProgress: Bool) -> some View {
        VStack(spacing: 8) {
            if showsProgress { ProgressView().controlSize(.small) }
            Text(text).font(.notch(size: 12, weight: .medium))
        }
        .foregroundStyle(Color.white.level(0.6))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func accessPrompt(text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(text)
                .font(.notch(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(button, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Folder picker, the draft, and the notes of the selected folder.
private struct NotesSidebar: View {
    var store: NotesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            folderMenu
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    row(
                        title: "Scratchpad",
                        subtitle: "kept here until saved",
                        symbol: "square.and.pencil",
                        isSelected: store.selection == .draft,
                        action: store.selectDraft
                    )
                    clipboardButton
                    ForEach(store.notes) { note in
                        row(
                            title: note.name.isEmpty ? "Untitled note" : note.name,
                            subtitle: note.modifiedDate.formatted(.relative(presentation: .named)),
                            symbol: nil,
                            isSelected: store.selection == .note(note.id)
                        ) {
                            store.selectNote(note.id)
                        }
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(.trailing, 8)
    }

    /// The clipboard's text into the scratchpad (spec J-13).
    private var clipboardButton: some View {
        Button {
            if let text = NSPasteboard.general.string(forType: .string) { store.addToScratchpad(text) }
        } label: {
            Label("Paste as Note", systemImage: "doc.on.clipboard")
                .font(.notch(size: 11, weight: .medium))
                .foregroundStyle(Color.white.level(0.7))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .help("Add the clipboard's text to the scratchpad")
    }

    private var folderMenu: some View {
        Menu {
            ForEach(store.foldersByAccount, id: \.account) { group in
                Section(group.account) {
                    ForEach(group.folders) { folder in
                        Button {
                            store.selectFolder(folder.id)
                        } label: {
                            if folder.id == store.selectedFolderID {
                                Label(folder.name, systemImage: "checkmark")
                            } else {
                                Text(folder.name)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(NotesWorkspaceView.accent)
                Text(store.selectedFolder?.name ?? "Folder")
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.notch(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.level(0.5))
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: AppleStyle.corner(7), style: .continuous).fill(Color.white.level(0.1)))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.notch)
        .menuIndicator(.hidden)
        .help(store.selectedFolder.map { "\($0.account) › \($0.name)" } ?? "Choose a folder")
    }

    private func row(title: String, subtitle: String, symbol: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.notch(size: 11, weight: .semibold))
                        .foregroundStyle(NotesWorkspaceView.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.notch(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.notch(size: 10))
                        .foregroundStyle(Color.white.level(0.45))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: AppleStyle.corner(7), style: .continuous)
                    .fill(isSelected ? NotesWorkspaceView.accent.opacity(0.28) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
    }
}

/// Notes feature in the notch.
struct NotesFeatureView: View {
    var store: NotesStore
    let isActive: Bool

    var body: some View {
        NotesWorkspaceView(store: store, isActive: isActive)
            .padding(.top, 4)
    }
}

/// Content of the notes menu bar panel.
struct NotesMenuBarView: View {
    var store: NotesStore
    var state: MenuBarPanelState

    var body: some View {
        NotesWorkspaceView(
            store: store,
            isActive: true,
            pin: PinControl(isPinned: state.isPinned) { state.isPinned.toggle() }
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .popoverChrome(arrowX: state.arrowX)
    }
}
