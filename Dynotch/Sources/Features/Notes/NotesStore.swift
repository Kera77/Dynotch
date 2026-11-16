import AppKit
import Combine

/// State of the notes feature, shared by the notch panels and the menu bar panel (spec J-1…J-9).
@MainActor
final class NotesStore: ObservableObject {
    enum Access: Equatable {
        case unknown
        case loading
        case ready
        /// Automation permission for Notes is missing.
        case denied
        case failed(String)
    }

    enum Selection: Equatable {
        /// The local draft, not yet in Notes.
        case draft
        case note(String)
    }

    enum SaveState: Equatable {
        case idle
        /// Edited, waiting for typing to pause.
        case pending
        case saving
        case saved(Date)
        /// The note changed in Notes since it was loaded; nothing was overwritten.
        case conflict
        case failed(String)
    }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var folders: [NotesFolder] = []
    @Published private(set) var notes: [NoteSummary] = []
    @Published private(set) var selectedFolderID: String?
    @Published private(set) var selection: Selection
    @Published private(set) var text: String
    @Published private(set) var isLoadingNote = false
    /// Why the selected note can't be edited here, if it can't.
    @Published private(set) var readOnlyReason: String?
    @Published private(set) var saveState: SaveState = .idle

    static let autosaveDelay: Duration = .milliseconds(1500)
    private static let refreshInterval: TimeInterval = 60

    private enum Key {
        static let folder = "notesFolder"
        static let note = "notesNote"
        static let draft = "notesDraft"
    }

    let bridge = NotesBridge()
    private let defaults: UserDefaults
    private var draftText: String {
        didSet { defaults.set(draftText, forKey: Key.draft) }
    }
    /// Modification time of the selected note as loaded, for conflict detection.
    private var loadedModified: Double?
    var saveTask: Task<Void, Never>?
    var lastRefresh = Date.distantPast

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let draft = defaults.string(forKey: Key.draft) ?? ""
        draftText = draft
        selectedFolderID = defaults.string(forKey: Key.folder)
        if let noteID = defaults.string(forKey: Key.note) {
            selection = .note(noteID)
            text = ""
        } else {
            selection = .draft
            text = draft
        }
    }

    var isEditable: Bool {
        access == .ready && !isLoadingNote && readOnlyReason == nil
    }

    // MARK: - Loading

    /// Called when a notes view becomes visible: loads, or refreshes when stale. Nothing talks
    /// to Notes before this, so the permission prompt only appears when the feature is used.
    func activate() {
        guard access != .loading else { return }
        let stale = Date().timeIntervalSince(lastRefresh) > Self.refreshInterval
        guard access != .ready || stale else { return }
        Task { await reload() }
    }

    func retry() {
        access = .unknown
        Task { await reload() }
    }

    private func reload() async {
        if access != .ready { access = .loading }
        do {
            let loaded = try await bridge.folders()
            folders = loaded
            lastRefresh = Date()
            access = .ready
            if selectedFolderID == nil || !loaded.contains(where: { $0.id == selectedFolderID }) {
                selectedFolderID = Self.defaultFolder(in: loaded)?.id
                defaults.set(selectedFolderID, forKey: Key.folder)
            }
            await loadNotes()
            // Refresh the open note unless it has unsaved edits.
            if case .note(let id) = selection, saveState != .pending, saveState != .saving {
                await loadNote(id)
            }
        } catch {
            handle(error)
        }
    }

    private func loadNotes() async {
        guard let folderID = selectedFolderID else {
            notes = []
            return
        }
        do {
            notes = try await bridge.notes(inFolder: folderID)
        } catch {
            handle(error)
        }
    }

    func loadNote(_ id: String) async {
        isLoadingNote = true
        defer { isLoadingNote = false }
        do {
            let detail = try await bridge.note(id)
            guard selection == .note(id) else { return }
            text = detail.text
            loadedModified = detail.modified
            readOnlyReason = Self.readOnlyReason(for: detail)
            saveState = .idle
        } catch {
            // Deleted or moved in Notes: fall back to the draft.
            selection = .draft
            text = draftText
            readOnlyReason = nil
            defaults.removeObject(forKey: Key.note)
            saveState = .failed("Can't open the note: \(error)")
        }
    }

    // MARK: - Selection

    func selectFolder(_ id: String) {
        guard id != selectedFolderID else { return }
        Task {
            await flush()
            selectedFolderID = id
            defaults.set(id, forKey: Key.folder)
            await loadNotes()
        }
    }

    func selectNote(_ id: String) {
        guard selection != .note(id) else { return }
        Task {
            await flush()
            selection = .note(id)
            defaults.set(id, forKey: Key.note)
            text = ""
            readOnlyReason = nil
            saveState = .idle
            await loadNote(id)
        }
    }

    func selectDraft() {
        guard selection != .draft else { return }
        Task {
            await flush()
            selection = .draft
            defaults.removeObject(forKey: Key.note)
            text = draftText
            readOnlyReason = nil
            loadedModified = nil
            saveState = .idle
        }
    }

    // MARK: - Editing and saving

    /// Text typed in an editor.
    func edit(_ newText: String) {
        guard newText != text, isEditable else { return }
        text = newText
        switch selection {
        case .draft:
            draftText = newText
        case .note:
            scheduleSave()
        }
    }

    /// Saves the draft as a new note in the selected folder (spec J-4).
    func saveDraftToNotes() {
        guard selection == .draft, let folderID = selectedFolderID,
              !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        let content = draftText
        saveState = .saving
        Task {
            do {
                let created = try await bridge.create(inFolder: folderID, html: NoteHTML.html(fromPlainText: content))
                draftText = ""
                selection = .note(created.id)
                defaults.set(created.id, forKey: Key.note)
                loadedModified = created.modified
                saveState = .saved(Date())
                await loadNotes()
            } catch {
                saveState = .failed("\(error)")
            }
        }
    }

    private func scheduleSave() {
        saveState = .pending
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            await self?.save(force: false)
        }
    }

    /// Saves pending edits right away (before switching notes).
    func flush() async {
        guard saveState == .pending else { return }
        saveTask?.cancel()
        await save(force: false)
    }

    func save(force: Bool) async {
        guard case .note(let id) = selection, readOnlyReason == nil else { return }
        let snapshot = text
        saveState = .saving
        do {
            let result = try await bridge.save(
                id, html: NoteHTML.html(fromPlainText: snapshot),
                expectedModified: force ? nil : loadedModified
            )
            if result.conflict {
                saveState = .conflict
                return
            }
            loadedModified = result.modified
            if let index = notes.firstIndex(where: { $0.id == id }) {
                notes[index] = NoteSummary(id: id, name: result.name ?? NoteHTML.title(of: snapshot), modified: result.modified)
            }
            // Typed on while saving: the next autosave is already scheduled.
            if text == snapshot, selection == .note(id) { saveState = .saved(Date()) }
        } catch {
            saveState = .failed("\(error)")
        }
    }
}

// MARK: - Conflicts, navigation to Notes, helpers

extension NotesStore {
    var selectedFolder: NotesFolder? {
        folders.first { $0.id == selectedFolderID }
    }

    /// Accounts with their folders, in Notes' order.
    var foldersByAccount: [(account: String, folders: [NotesFolder])] {
        var order: [String] = []
        var grouped: [String: [NotesFolder]] = [:]
        for folder in folders {
            if grouped[folder.account] == nil { order.append(folder.account) }
            grouped[folder.account, default: []].append(folder)
        }
        return order.map { ($0, grouped[$0] ?? []) }
    }

    /// After a conflict: discard local edits and load the version in Notes.
    func reloadFromNotes() {
        guard case .note(let id) = selection else { return }
        saveTask?.cancel()
        Task { await loadNote(id) }
    }

    /// After a conflict: replace the version in Notes with the text here.
    func overwriteNotes() {
        saveTask?.cancel()
        Task { await save(force: true) }
    }

    func openInNotes() {
        guard case .note(let id) = selection else { return }
        Task {
            await flush()
            try? await bridge.show(id)
        }
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Puts the store into a loaded state without talking to Notes (tests, previews).
    func setLoadedState(
        folders: [NotesFolder],
        notes: [NoteSummary],
        selection: Selection,
        text: String,
        readOnlyReason: String? = nil
    ) {
        self.folders = folders
        self.notes = notes
        selectedFolderID = folders.first?.id
        self.selection = selection
        self.text = text
        self.readOnlyReason = readOnlyReason
        access = .ready
        lastRefresh = Date()
    }

    // MARK: - Helpers

    func handle(_ error: Error) {
        if let error = error as? NotesBridgeError, error == .notAuthorized {
            access = .denied
        } else {
            access = .failed("\(error)")
        }
    }

    /// The account's default "Notes" folder, otherwise the first one.
    nonisolated static func defaultFolder(in folders: [NotesFolder]) -> NotesFolder? {
        folders.first { ["Notes", "Jegyzetek"].contains($0.name) } ?? folders.first
    }

    nonisolated static func readOnlyReason(for detail: NoteDetail) -> String? {
        if detail.locked {
            return "Locked note: open it in Notes"
        }
        if detail.attachments > 0 || NoteHTML.isRich(html: detail.body) {
            return "Read-only: contains a list, image or link"
        }
        return nil
    }
}
