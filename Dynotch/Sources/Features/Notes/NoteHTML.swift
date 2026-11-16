import Foundation

/// Conversion between the editor's plain text and the HTML body Apple Notes stores.
enum NoteHTML {
    /// Each line becomes a `<div>`; Notes uses the first line as the title.
    static func html(fromPlainText text: String) -> String {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        return lines
            .map { $0.isEmpty ? "<div><br></div>" : "<div>\(escape($0))</div>" }
            .joined()
    }

    /// True if saving plain text would lose content: lists or checklists, tables, images,
    /// links or embedded objects (spec J-6).
    static func isRich(html: String) -> Bool {
        html.range(of: #"<\s*(ul|ol|li|table|img|a|object|iframe)[\s>/]"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// First non-empty line, used as the title of notes not yet reloaded from Notes.
    static func title(of text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "Új jegyzet"
    }
}
