import AppKit
import SwiftUI

/// Plain text view used by the calculator and the notes: edit shortcuts, placeholder,
/// focus on appearance.
class EditingTextView: NSTextView {
    var placeholder: String?
    var placeholderFont: NSFont = .systemFont(ofSize: 14)

    /// Dynotch has no main menu, so the usual Edit shortcuts would not reach the text view.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        switch (modifiers, key) {
        case (.command, "c"): copy(nil)
        case (.command, "x"): cut(nil)
        case (.command, "v"): pasteAsPlainText(nil)
        case (.command, "a"): selectAll(nil)
        case (.command, "z"): undoManager?.undo()
        case ([.command, .shift], "z"): undoManager?.redo()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Ready for typing as soon as its window has keyboard focus.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, self.isEditable else { return }
            window.makeFirstResponder(self)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, let placeholder else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: placeholderFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.3)
        ]
        let origin = textContainerOrigin
        let padding = textContainer?.lineFragmentPadding ?? 0
        (placeholder as NSString).draw(at: NSPoint(x: origin.x + padding, y: origin.y), withAttributes: attributes)
    }

    /// Common setup: white plain text on a transparent background, no smart substitutions.
    func configurePlainText(font: NSFont, caretColor: NSColor, lineSpacing: CGFloat) {
        isRichText = false
        allowsUndo = true
        self.font = font
        placeholderFont = font
        textColor = .white
        insertionPointColor = caretColor
        drawsBackground = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        defaultParagraphStyle = paragraph
        typingAttributes = [.font: font, .foregroundColor: NSColor.white, .paragraphStyle: paragraph]

        minSize = .zero
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
    }

    /// Wraps the text view in a transparent, overlay-scrolling scroll view.
    func embedInScrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.documentView = self
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        return scrollView
    }
}

/// Plain text editor for SwiftUI (notes).
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable = true
    var placeholder: String?
    var caretColor: NSColor = .white

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = EditingTextView(usingTextLayoutManager: false)
        textView.configurePlainText(font: .systemFont(ofSize: 14), caretColor: caretColor, lineSpacing: 4)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.placeholder = placeholder
        textView.isEditable = isEditable
        textView.string = text
        textView.delegate = context.coordinator
        return textView.embedInScrollView()
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let textView = scrollView.documentView as? EditingTextView else { return }
        if textView.isEditable != isEditable { textView.isEditable = isEditable }
        if textView.placeholder != placeholder {
            textView.placeholder = placeholder
            textView.needsDisplay = true
        }
        // Another editor or a reload changed the text.
        if textView.string != text {
            textView.string = text
            textView.needsDisplay = true
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
