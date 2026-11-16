import AppKit
import SwiftUI

/// Gives the formatting toolbar access to the editor's text view.
@MainActor
final class RichNoteController: ObservableObject {
    weak var textView: NSTextView?

    func toggle(_ style: RichNoteFormat.InlineStyle) {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        RichNoteFormat.toggle(style, in: textView)
    }

    /// Turns the selected lines into to-do items and back (spec J-12).
    func toggleChecklist() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        Checklist.toggleList(in: textView)
    }

    func apply(_ style: RichNoteFormat.ParagraphStyle) {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        RichNoteFormat.apply(style, in: textView)
    }
}

/// Text view with Apple Notes' formatting shortcuts (spec J-11).
final class RichNoteTextView: EditingTextView {
    /// ⇧⌘ with these keys sets the paragraph style.
    private static let paragraphKeys: [String: RichNoteFormat.ParagraphStyle] = [
        "t": .title, "h": .heading, "j": .subheading, "b": .body
    ]

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, window?.firstResponder === self, isEditable else {
            return super.performKeyEquivalent(with: event)
        }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if modifiers == [.command, .shift], let style = Self.paragraphKeys[key] {
            RichNoteFormat.apply(style, in: self)
            return true
        }
        switch (modifiers, key) {
        case (.command, "b"): RichNoteFormat.toggle(.bold, in: self)
        case (.command, "i"): RichNoteFormat.toggle(.italic, in: self)
        case (.command, "u"): RichNoteFormat.toggle(.underline, in: self)
        case ([.command, .shift], "x"): RichNoteFormat.toggle(.strikethrough, in: self)
        case ([.command, .shift], "l"): Checklist.toggleList(in: self)
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    /// A click on an item's circle checks or unchecks it (spec J-12).
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if isEditable, let line = Checklist.markerLine(at: point, in: self) {
            Checklist.toggleItem(onLine: line, in: self)
            return
        }
        super.mouseDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        if isEditable, Checklist.handleReturn(in: self) { return }
        super.insertNewline(sender)
    }
}

/// Formatted note editor for SwiftUI.
struct RichNoteEditor: NSViewRepresentable {
    @Binding var content: NSAttributedString
    var isEditable = true
    var placeholder: String?
    var caretColor: NSColor = .white
    let controller: RichNoteController

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = RichNoteTextView(usingTextLayoutManager: false)
        textView.configurePlainText(font: .systemFont(ofSize: RichNoteFormat.bodySize), caretColor: caretColor, lineSpacing: 4)
        textView.isRichText = true
        textView.importsGraphics = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.placeholder = placeholder
        textView.isEditable = isEditable
        textView.textStorage?.setAttributedString(content)
        textView.typingAttributes = RichNoteFormat.baseAttributes
        textView.delegate = context.coordinator
        controller.textView = textView
        return textView.embedInScrollView()
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.content = $content
        guard let textView = scrollView.documentView as? RichNoteTextView else { return }
        controller.textView = textView
        if textView.isEditable != isEditable { textView.isEditable = isEditable }
        if textView.placeholder != placeholder {
            textView.placeholder = placeholder
            textView.needsDisplay = true
        }
        // Another editor or a reload changed the text.
        if !textView.attributedString().isEqual(to: content) {
            let selection = textView.selectedRange()
            textView.textStorage?.setAttributedString(content)
            textView.setSelectedRange(NSRange(location: min(selection.location, content.length), length: 0))
            textView.needsDisplay = true
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var content: Binding<NSAttributedString>

        init(content: Binding<NSAttributedString>) {
            self.content = content
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Typing may have made or unmade a to-do item: colour the circles again.
            if let storage = textView.textStorage {
                storage.beginEditing()
                Checklist.restyle(storage)
                storage.endEditing()
            }
            content.wrappedValue = NSAttributedString(attributedString: textView.attributedString())
        }
    }
}

/// Formatting bar above the editor: paragraph style menu and B, I, U, S (spec J-10).
struct RichNoteToolbar: View {
    let controller: RichNoteController
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 2) {
            Menu {
                ForEach(RichNoteFormat.ParagraphStyle.allCases) { style in
                    Button(style.name) { controller.apply(style) }
                }
            } label: {
                Text("Aa")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Title ⇧⌘T · Heading ⇧⌘H · Subheading ⇧⌘J · Body ⇧⌘B")

            Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 16)
            button("B", font: .system(size: 13, weight: .bold), help: "Bold ⌘B") { controller.toggle(.bold) }
            button("I", font: .system(size: 13).italic(), help: "Italic ⌘I") { controller.toggle(.italic) }
            button("U", font: .system(size: 13), underline: true, help: "Underline ⌘U") { controller.toggle(.underline) }
            button("S", font: .system(size: 13), strikethrough: true, help: "Strikethrough ⇧⌘X") { controller.toggle(.strikethrough) }
            Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 16)
            Button {
                controller.toggleChecklist()
            } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("To-do list ⇧⌘L · click a circle to check it off")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }

    private func button(
        _ title: String, font: Font, underline: Bool = false, strikethrough: Bool = false,
        help: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .underline(underline)
                .strikethrough(strikethrough)
                .foregroundStyle(.white)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
