@testable import Dynotch
import Foundation
import Testing

struct NoteHTMLTests {
    @Test func plainTextBecomesDivsWithEscaping() {
        let html = NoteHTML.html(fromPlainText: "Cím\n\n<b>&\"x\"</b>")
        #expect(html == "<div>Cím</div><div><br></div><div>&lt;b&gt;&amp;&quot;x&quot;&lt;/b&gt;</div>")
        #expect(NoteHTML.html(fromPlainText: "a\r\nb") == "<div>a</div><div>b</div>")
    }

    @Test(arguments: [
        "<div><ul><li>tej</li></ul></div>",
        "<div><ol><li>1</li></ol></div>",
        "<table><tr><td>x</td></tr></table>",
        "<div><img src=\"x\"></div>",
        "<div><a href=\"https://x\">link</a></div>",
        "<div><OBJECT></OBJECT></div>"
    ])
    func richContentIsDetected(_ html: String) {
        #expect(NoteHTML.isRich(html: html))
    }

    @Test(arguments: [
        "<div><b><span style=\"font-size: 24px\">Cím</span></b></div><div>sima szöveg</div>",
        "<div><h1>Cím</h1></div><div><br></div><div>abc</div>",
        "<div>&lt;ul&gt; nem lista</div>"
    ])
    func plainContentIsEditable(_ html: String) {
        #expect(!NoteHTML.isRich(html: html))
    }

    @Test func title() {
        #expect(NoteHTML.title(of: "\n  Bevásárlás \ntej") == "Bevásárlás")
        #expect(NoteHTML.title(of: "") == "New Note")
    }

    @Test func bridgeErrorClassification() {
        let denied = "execution error: Not authorized to send Apple events to Notes. (-1743)"
        #expect(NotesBridgeError.from(stderr: denied) == .notAuthorized)
        let missing = "execution error: Can't get object. (-1728)"
        #expect(NotesBridgeError.from(stderr: missing) == .failed(missing))
        #expect(NotesBridgeError.from(stderr: "  ") == .failed("Unknown error"))
    }

    @Test func scriptsAreJavaScriptRunFunctions() {
        for script in Scripts.all {
            #expect(script.hasPrefix("function run(argv) {"))
            #expect(script.contains("JSON.stringify") || script.contains("'true'"))
        }
    }

    @Test func decodesScriptOutput() throws {
        let json = #"{"id":"x-coredata://1/ICNote/p1","name":"Cím","modified":1763280000000,"locked":false,"#
            + #""attachments":0,"body":"<div>Cím</div>","text":"Cím"}"#
        let detail = try JSONDecoder().decode(NoteDetail.self, from: Data(json.utf8))
        #expect(detail.name == "Cím")
        #expect(NotesStore.readOnlyReason(for: detail) == nil)
        let summary = NoteSummary(id: "a", name: "b", modified: 1_763_280_000_000)
        #expect(summary.modifiedDate == Date(timeIntervalSince1970: 1_763_280_000))
    }
}

@MainActor
struct NotesStoreTests {
    private func makeStore() -> NotesStore {
        let suite = "DynotchTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return NotesStore(defaults: defaults)
    }

    private let folders = [
        NotesFolder(id: "f1", name: "Munka", account: "iCloud"),
        NotesFolder(id: "f2", name: "Notes", account: "iCloud"),
        NotesFolder(id: "f3", name: "Notes", account: "On My Mac")
    ]

    @Test func startsWithDraftAndDoesNotTouchNotes() {
        let store = makeStore()
        #expect(store.selection == .draft)
        #expect(store.access == .unknown)
        #expect(!store.isEditable)
    }

    @Test func defaultFolderAndGrouping() {
        #expect(NotesStore.defaultFolder(in: folders)?.id == "f2")
        #expect(NotesStore.defaultFolder(in: [folders[0]])?.id == "f1")
        let store = makeStore()
        store.setLoadedState(folders: folders, notes: [], selection: .draft, text: "")
        #expect(store.foldersByAccount.map(\.account) == ["iCloud", "On My Mac"])
        #expect(store.foldersByAccount[0].folders.map(\.id) == ["f1", "f2"])
    }

    @Test func draftEditsArePersistedLocally() {
        let suite = "DynotchTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let store = NotesStore(defaults: defaults)
        store.setLoadedState(folders: folders, notes: [], selection: .draft, text: "")
        store.edit("Teendők\nhívás")
        #expect(store.text == "Teendők\nhívás")
        #expect(store.saveState == .idle)
        #expect(NotesStore(defaults: defaults).text == "Teendők\nhívás")
    }

    @Test func editingANoteSchedulesASave() {
        let store = makeStore()
        store.setLoadedState(folders: folders, notes: [], selection: .note("n1"), text: "régi")
        store.edit("új")
        #expect(store.text == "új")
        #expect(store.saveState == .pending)
    }

    @Test func readOnlyNotesIgnoreEdits() {
        let store = makeStore()
        store.setLoadedState(folders: folders, notes: [], selection: .note("n1"), text: "lista", readOnlyReason: "x")
        #expect(!store.isEditable)
        store.edit("más")
        #expect(store.text == "lista")
        #expect(store.saveState == .idle)
    }

    @Test func readOnlyReasons() {
        func detail(locked: Bool = false, attachments: Int = 0, body: String = "<div>x</div>") -> NoteDetail {
            NoteDetail(id: "n", name: "n", modified: 0, locked: locked, attachments: attachments, body: body, text: "x")
        }
        #expect(NotesStore.readOnlyReason(for: detail()) == nil)
        #expect(NotesStore.readOnlyReason(for: detail(locked: true)) != nil)
        #expect(NotesStore.readOnlyReason(for: detail(attachments: 1)) != nil)
        #expect(NotesStore.readOnlyReason(for: detail(body: "<ul><li>a</li></ul>")) != nil)
    }
}
