import Foundation

/// The notes store's pure helpers.
extension NotesStore {
    /// The text as paragraphs after the existing HTML.
    nonisolated static func appending(_ text: String, to html: String) -> String {
        let paragraphs = text.components(separatedBy: .newlines).map { line in
            let escaped = line
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return "<div>\(escaped.isEmpty ? "<br>" : escaped)</div>"
        }
        return html + paragraphs.joined()
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
            return Checklist.hasOnlyLists(html: detail.body) && detail.attachments == 0
                ? "Read-only: contains an Apple Notes list" : "Read-only: contains an image, table or link"
        }
        return nil
    }
}
