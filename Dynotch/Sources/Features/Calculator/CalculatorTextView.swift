import AppKit

/// One calculated line: the formatted result and where its line is in the text view.
struct CalculatorResultRow {
    let text: String
    /// Line rect in the text view's coordinates.
    let lineRect: NSRect
    /// The line's baseline, in the text view's coordinates: results sit on it, so a line that
    /// gains its line spacing (a new line after it) does not move them (spec SZ-16).
    var baseline: CGFloat = 0
}

/// Plain text editor of the calculator notepad. The results live in `resultsView`, a column
/// on its right edge that scrolls with the text (spec SZ-2).
final class CalculatorTextView: EditingTextView {
    static let resultColumnWidth: CGFloat = 130

    static var editorFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    }

    let resultsView = CalculatorResultsView()

    /// Scroll view with a fully configured editor as its document view.
    static func makeScrollView(text: String) -> NSScrollView {
        // TextKit 1: the result rows come from the layout manager's line rects.
        let textView = CalculatorTextView(usingTextLayoutManager: false)
        textView.configurePlainText(font: editorFont, caretColor: CalculatorResultsView.resultColor, lineSpacing: 5)
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.widthTracksTextView = false
        textView.placeholder = "Type a calculation, e.g. 1200 * 1.27"
        textView.string = text

        textView.resultsView.textView = textView
        textView.addSubview(textView.resultsView)
        return textView.embedInScrollView()
    }

    override var string: String {
        didSet { refreshResults() }
    }

    override func didChangeText() {
        super.didChangeText()
        refreshResults()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // Keep the text out of the result column.
        let width = max(newSize.width - Self.resultColumnWidth, 60)
        if let textContainer, textContainer.containerSize.width != width {
            textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        }
        resultsView.frame = NSRect(
            x: max(newSize.width - Self.resultColumnWidth, 0), y: 0,
            width: Self.resultColumnWidth, height: newSize.height
        )
        refreshResults()
    }

    /// The lines that are calculations, with their results.
    func resultRows() -> [CalculatorResultRow] {
        guard let layoutManager, textContainer != nil else { return [] }
        let text = string as NSString
        let origin = textContainerOrigin
        var rows: [CalculatorResultRow] = []
        var ranges: [NSRange] = []
        var location = 0
        while location < text.length {
            let range = text.paragraphRange(for: NSRange(location: location, length: 0))
            location = NSMaxRange(range)
            ranges.append(range)
        }
        // The lines together: variables and totals depend on the lines above (spec SZ-12).
        let results = CalculatorSheet.results(for: ranges.map { text.substring(with: $0).trimmingCharacters(in: .newlines) })
        for (range, result) in zip(ranges, results) {
            guard let result else { continue }

            let glyphIndex = layoutManager.glyphIndexForCharacter(at: range.location)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let baseline = lineRect.minY + layoutManager.location(forGlyphAt: glyphIndex).y + origin.y
            rows.append(CalculatorResultRow(text: result, lineRect: lineRect.offsetBy(dx: origin.x, dy: origin.y), baseline: baseline))
        }
        return rows
    }

    /// Ready to type: the keyboard goes here and the caret waits on a new line at the end
    /// (spec SZ-10).
    func focusForTyping() {
        guard let window else { return }
        window.makeFirstResponder(self)
        if !string.isEmpty, !string.hasSuffix("\n"), let storage = textStorage {
            let end = NSRange(location: storage.length, length: 0)
            if shouldChangeText(in: end, replacementString: "\n") {
                storage.replaceCharacters(in: end, with: NSAttributedString(string: "\n", attributes: typingAttributes))
                didChangeText()
            }
        }
        setSelectedRange(NSRange(location: (string as NSString).length, length: 0))
        scrollRangeToVisible(selectedRange())
    }

    /// Scrolls only the calculator's own scroll view: the default one also moved the notch's
    /// content, sliding the top row out of view (spec SZ-17).
    override func scrollRangeToVisible(_ range: NSRange) {
        guard let clip = enclosingScrollView?.contentView, let layout = layoutManager, let container = textContainer else { return }
        let length = (string as NSString).length
        guard length > 0 else { return clip.scroll(to: .zero) }
        layout.ensureLayout(for: container)
        var rect = layout.extraLineFragmentRect
        if range.location < length || rect.isEmpty {
            let glyph = layout.glyphIndexForCharacter(at: min(range.location, length - 1))
            rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        }
        rect.origin.y += textContainerOrigin.y
        let visible = clip.documentVisibleRect
        var top = visible.minY
        if rect.maxY + textContainerInset.height > visible.maxY {
            top = rect.maxY + textContainerInset.height - visible.height
        } else if rect.minY < visible.minY {
            top = rect.minY
        }
        guard top != visible.minY else { return }
        clip.scroll(to: NSPoint(x: visible.minX, y: max(0, top)))
        enclosingScrollView?.reflectScrolledClipView(clip)
    }

    private func refreshResults() {
        resultsView.needsDisplay = true
        window?.invalidateCursorRects(for: resultsView)
    }
}

/// The result column: blue results, right-aligned on their lines. Clicking a result copies
/// it to the clipboard (spec SZ-9).
final class CalculatorResultsView: NSView {
    /// The standard blue of Dynotch's controls (spec SZ-11).
    static var resultColor: NSColor { Theme.nsBlue }
    private static let copiedText = "Copied ✓"
    private static let trailingPadding: CGFloat = 8

    weak var textView: CalculatorTextView?
    var pasteboard = NSPasteboard.general
    /// Line (by its vertical position) that currently shows the "copied" confirmation.
    private var copiedLineY: CGFloat?

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Result rows with their line band in this view's coordinates.
    private func rows() -> [(row: CalculatorResultRow, band: NSRect)] {
        guard let textView else { return [] }
        return textView.resultRows().map { row in
            let band = NSRect(x: 0, y: row.lineRect.minY - frame.minY, width: bounds.width, height: row.lineRect.height)
            return (row, band)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        for (row, band) in rows() where band.intersects(dirtyRect) {
            let isCopied = copiedLineY == band.minY
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: isCopied ? 12 : 14, weight: .semibold),
                .foregroundColor: isCopied ? NSColor.white.withAlphaComponent(0.8) : Self.resultColor
            ]
            let text = (isCopied ? Self.copiedText : row.text) as NSString
            let size = text.size(withAttributes: attributes)
            let font = attributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 14)
            // On the line's baseline, like the text beside it (flipped: draw(at:) takes the top).
            let point = NSPoint(
                x: bounds.maxX - Self.trailingPadding - size.width,
                y: row.baseline - frame.minY - font.ascender
            )
            text.draw(at: point, withAttributes: attributes)
        }
    }

    /// Only result rows take clicks; elsewhere the click goes to the text.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview else { return nil }
        let local = convert(point, from: superview)
        return rows().contains { $0.band.contains(local) } ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        copyResult(at: convert(event.locationInWindow, from: nil))
    }

    override func resetCursorRects() {
        for (_, band) in rows() {
            addCursorRect(band, cursor: .pointingHand)
        }
    }

    /// Copies the result on the clicked line; returns whether there was one.
    @discardableResult
    func copyResult(at point: NSPoint) -> Bool {
        guard let hit = rows().first(where: { $0.band.contains(point) }) else { return false }
        pasteboard.clearContents()
        pasteboard.setString(Self.clipboardText(for: hit.row.text), forType: .string)

        let lineY = hit.band.minY
        copiedLineY = lineY
        needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.copiedLineY == lineY else { return }
            self.copiedLineY = nil
            self.needsDisplay = true
        }
        return true
    }

    /// The number as shown, without the thousands separators: "1 524,5" → "1524,5".
    static func clipboardText(for result: String) -> String {
        result.replacingOccurrences(of: "\u{00A0}", with: "")
    }
}
