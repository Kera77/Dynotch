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
        let scrollView = ContainedScrollView()
        scrollView.documentView = self
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        return scrollView
    }
}

/// A scroll view whose "make this visible" stops at itself: the caret scrolls the editor, never
/// the notch around it, so the top row stays in view (spec SZ-18).
final class ContainedScrollView: NSScrollView {
    override func scrollToVisible(_ rect: NSRect) -> Bool {
        // The clip view already scrolled the editor; nothing above it moves.
        true
    }
}
