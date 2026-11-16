import SwiftUI

/// Lock control shown in the menu bar panel's bottom bar.
struct PinControl {
    let isPinned: Bool
    let toggle: () -> Void
}

/// Sidebar with folders and notes, editor, and a bottom bar (spec J-2…J-8).
struct NotesWorkspaceView: View {
    @ObservedObject var store: NotesStore
    /// Only the visible view talks to Notes, so hidden pages don't trigger the permission prompt.
    let isActive: Bool
    var pin: PinControl?

    static let accent = Color(red: 0.98, green: 0.78, blue: 0.16)
    private static let sidebarWidth: CGFloat = 210

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
                    .frame(width: Self.sidebarWidth)
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)
                editor
            }
            bottomBar
        }
    }

    private var editor: some View {
        PlainTextEditor(
            text: Binding(get: { store.text }, set: { store.edit($0) }),
            isEditable: store.isEditable,
            placeholder: store.selection == .draft ? "New note. The first line becomes its title." : nil,
            caretColor: NSColor(Self.accent)
        )
        .overlay {
            if store.isLoadingNote {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.leading, 6)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .help(statusText)
            Spacer(minLength: 8)

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
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 16)
                PinButton(isPinned: pin.isPinned, action: pin.toggle)
                    .frame(width: 30, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.14)))
            }

            switch store.selection {
            case .draft:
                Button(action: store.saveDraftToNotes) {
                    Text("Save to Notes")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Self.accent))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.selectedFolder == nil)
                .opacity(store.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                .help("New note in \"\(store.selectedFolder?.name ?? "")\"")
            case .note:
                Button(action: store.openInNotes) {
                    Label("Open in Notes", systemImage: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.14)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
        case .conflict, .failed: Color(red: 1, green: 0.45, blue: 0.4)
        default: Color.white.opacity(store.readOnlyReason == nil ? 0.6 : 0.8)
        }
    }

    // MARK: - States

    private func message(text: String, showsProgress: Bool) -> some View {
        VStack(spacing: 8) {
            if showsProgress { ProgressView().controlSize(.small) }
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(Color.white.opacity(0.6))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func accessPrompt(text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(text)
                .font(.system(size: 12))
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
    @ObservedObject var store: NotesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            folderMenu
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    row(
                        title: "New Note",
                        subtitle: "draft",
                        symbol: "square.and.pencil",
                        isSelected: store.selection == .draft,
                        action: store.selectDraft
                    )
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.1)))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help(store.selectedFolder.map { "\($0.account) › \($0.name)" } ?? "Choose a folder")
    }

    private func row(title: String, subtitle: String, symbol: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NotesWorkspaceView.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? NotesWorkspaceView.accent.opacity(0.28) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Notes feature in the notch.
struct NotesFeatureView: View {
    @ObservedObject var store: NotesStore
    let isActive: Bool

    var body: some View {
        NotesWorkspaceView(store: store, isActive: isActive)
            .padding(.top, 4)
    }
}

/// Content of the notes menu bar panel.
struct NotesMenuBarView: View {
    @ObservedObject var store: NotesStore
    @ObservedObject var state: MenuBarPanelState

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
