import SwiftUI

/// The Notes wings: the latest note's name at the left, its text at the right (spec PV-34). It
/// watches the notes itself, so the latest note shows as soon as it has loaded (spec PV-60).
struct NotesWing: View {
    enum Side { case left, right }

    @ObservedObject var notes: NotesStore
    let side: Side

    var body: some View {
        switch side {
        case .left:
            Group {
                if let latest = notes.latest {
                    HStack(spacing: 6) {
                        WingSymbol("note.text")
                        WingText(latest.name, bold: true)
                    }
                } else {
                    WingLabel(symbol: "note.text", text: firstLine ?? "Notes")
                }
            }
            .onAppear { notes.refreshLatest() }
        case .right:
            // Before the latest note has loaded, the same note the left side names (spec PV-56).
            let body = notes.latest.map { NotchView.noteBody($0.text) } ?? NotchView.noteBody(notes.text)
            if !body.isEmpty {
                // Runs once to its end and stays there.
                WingsMarquee(text: body, dim: true, repeats: false)
            }
        }
    }

    private var firstLine: String? {
        notes.text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
    }
}
