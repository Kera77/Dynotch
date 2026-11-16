import Foundation

struct NotesFolder: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let account: String
}

struct NoteSummary: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    /// Milliseconds since 1970.
    let modified: Double

    var modifiedDate: Date { Date(timeIntervalSince1970: modified / 1000) }
}

struct NoteDetail: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let modified: Double
    let locked: Bool
    let attachments: Int
    let body: String
    let text: String
}

struct NoteSaveResult: Decodable, Equatable, Sendable {
    let conflict: Bool
    let modified: Double
    let name: String?
}

enum NotesBridgeError: Error, Equatable, CustomStringConvertible {
    /// Automation permission for Notes is missing.
    case notAuthorized
    case failed(String)

    var description: String {
        switch self {
        case .notAuthorized: "Nincs engedély a Jegyzetek vezérlésére"
        case .failed(let message): message
        }
    }

    /// Classifies an `osascript` error output.
    static func from(stderr: String) -> NotesBridgeError {
        let lowered = stderr.lowercased()
        if lowered.contains("-1743") || lowered.contains("not authorized") || lowered.contains("not allowed") {
            return .notAuthorized
        }
        let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return .failed(message.isEmpty ? "Ismeretlen hiba" : String(message.prefix(300)))
    }
}

/// Talks to Apple Notes through JavaScript for Automation (`osascript`). Calls run one at a
/// time on a background queue.
struct NotesBridge: Sendable {
    private static let queue = DispatchQueue(label: "Dynotch.NotesBridge")
    /// Localized names of the trash folder, which is not offered for editing.
    static let trashFolderNames: Set<String> = ["Recently Deleted", "Nemrég törölt"]

    func folders() async throws -> [NotesFolder] {
        try await run(Scripts.folders, [], as: [NotesFolder].self)
            .filter { !Self.trashFolderNames.contains($0.name) }
    }

    func notes(inFolder folderID: String) async throws -> [NoteSummary] {
        try await run(Scripts.notes, [folderID], as: [NoteSummary].self)
            .sorted { $0.modified > $1.modified }
    }

    func note(_ id: String) async throws -> NoteDetail {
        try await run(Scripts.note, [id], as: NoteDetail.self)
    }

    /// Replaces the note's body unless it changed in Notes since `expectedModified`.
    func save(_ id: String, html: String, expectedModified: Double?) async throws -> NoteSaveResult {
        let expected = expectedModified.map { String(Int64($0)) } ?? ""
        return try await run(Scripts.save, [id, html, expected], as: NoteSaveResult.self)
    }

    func create(inFolder folderID: String, html: String) async throws -> NoteSummary {
        try await run(Scripts.create, [folderID, html], as: NoteSummary.self)
    }

    func show(_ id: String) async throws {
        _ = try await run(Scripts.show, [id], as: Bool.self)
    }

    // MARK: - Running scripts

    private func run<Value: Decodable & Sendable>(_ script: String, _ arguments: [String], as type: Value.Type) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            Self.queue.async {
                do {
                    let output = try Self.runSync(script: script, arguments: arguments)
                    continuation.resume(returning: try JSONDecoder().decode(Value.self, from: output))
                } catch let error as NotesBridgeError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: NotesBridgeError.failed("Érvénytelen válasz: \(error)"))
                }
            }
        }
    }

    private static func runSync(script: String, arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", script] + arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
        } catch {
            throw NotesBridgeError.failed("osascript: \(error.localizedDescription)")
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NotesBridgeError.from(stderr: String(bytes: errorData, encoding: .utf8) ?? "")
        }
        return data
    }
}

/// JavaScript for Automation scripts; each returns JSON on stdout.
enum Scripts {
    static let folders = """
    function run(argv) {
      const Notes = Application('Notes');
      const out = [];
      Notes.accounts().forEach(function (account) {
        const accountName = account.name();
        const ids = account.folders.id();
        const names = account.folders.name();
        for (let i = 0; i < ids.length; i++) out.push({ id: ids[i], name: names[i], account: accountName });
      });
      return JSON.stringify(out);
    }
    """

    static let notes = """
    function run(argv) {
      const folder = Application('Notes').folders.byId(argv[0]);
      const ids = folder.notes.id();
      const names = folder.notes.name();
      const dates = folder.notes.modificationDate();
      const out = [];
      for (let i = 0; i < ids.length; i++) out.push({ id: ids[i], name: names[i], modified: dates[i].getTime() });
      return JSON.stringify(out);
    }
    """

    static let note = """
    function run(argv) {
      const note = Application('Notes').notes.byId(argv[0]);
      const locked = note.passwordProtected();
      return JSON.stringify({
        id: note.id(),
        name: note.name(),
        modified: note.modificationDate().getTime(),
        locked: locked,
        attachments: locked ? 0 : note.attachments.length,
        body: locked ? '' : note.body(),
        text: locked ? '' : note.plaintext()
      });
    }
    """

    static let save = """
    function run(argv) {
      const note = Application('Notes').notes.byId(argv[0]);
      const current = note.modificationDate().getTime();
      if (argv[2] !== '' && Math.abs(current - Number(argv[2])) > 1500) {
        return JSON.stringify({ conflict: true, modified: current, name: note.name() });
      }
      note.body = argv[1];
      return JSON.stringify({ conflict: false, modified: note.modificationDate().getTime(), name: note.name() });
    }
    """

    static let create = """
    function run(argv) {
      const Notes = Application('Notes');
      const note = Notes.Note({ body: argv[1] });
      Notes.folders.byId(argv[0]).notes.push(note);
      return JSON.stringify({ id: note.id(), name: note.name(), modified: note.modificationDate().getTime() });
    }
    """

    static let show = """
    function run(argv) {
      const Notes = Application('Notes');
      Notes.show(Notes.notes.byId(argv[0]));
      Notes.activate();
      return 'true';
    }
    """

    static let all = [folders, notes, note, save, create, show]
}
