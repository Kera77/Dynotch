import AppKit

/// One calculated line: the formatted result and where its line is in the text view.
struct CalculatorResultRow {
    let text: String
    /// Line rect in the text view's coordinates.
    let lineRect: NSRect
}

/// Plain text editor of the calculator notepad. The results live in `resultsView`, a column
/// on its right edge that scrolls with the text (spec SZ-2).
final class CalculatorTextView: NSTextView {
    static let resultColumnWidth: CGFloat = 130
    private static let placeholder = "Írj be egy számítást, pl. 1200 * 1,27"

    static var editorFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    }

    let resultsView = CalculatorResultsView()

    /// Scroll view with a fully configured editor as its document view.
    static func makeScrollView(text: String) -> NSScrollView {
        // TextKit 1: the result rows come from the layout manager's line rects.
        let textView = CalculatorTextView(usingTextLayoutManager: false)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = editorFont
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = [
            .font: editorFont,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]

        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.string = text

        textView.resultsView.textView = textView
        textView.addSubview(textView.resultsView)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        return scrollView
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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Ready for typing as soon as its window has keyboard focus.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.editorFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.3)
        ]
        let origin = textContainerOrigin
        let padding = textContainer?.lineFragmentPadding ?? 0
        (Self.placeholder as NSString).draw(at: NSPoint(x: origin.x + padding, y: origin.y), withAttributes: attributes)
    }

    /// The lines that are calculations, with their results.
    func resultRows() -> [CalculatorResultRow] {
        guard let layoutManager, textContainer != nil else { return [] }
        let text = string as NSString
        let origin = textContainerOrigin
        var rows: [CalculatorResultRow] = []
        var location = 0
        while location < text.length {
            let range = text.paragraphRange(for: NSRange(location: location, length: 0))
            location = NSMaxRange(range)
            let line = text.substring(with: range).trimmingCharacters(in: .newlines)
            guard let result = CalculatorEngine.result(for: line) else { continue }

            let glyphIndex = layoutManager.glyphIndexForCharacter(at: range.location)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            rows.append(CalculatorResultRow(text: result, lineRect: lineRect.offsetBy(dx: origin.x, dy: origin.y)))
        }
        return rows
    }

    private func refreshResults() {
        resultsView.needsDisplay = true
        window?.invalidateCursorRects(for: resultsView)
    }
}

/// The result column: green results, right-aligned on their lines. Clicking a result copies
/// it to the clipboard (spec SZ-9).
final class CalculatorResultsView: NSView {
    static let resultColor = NSColor(srgbRed: 0.25, green: 0.86, blue: 0.45, alpha: 1)
    private static let copiedText = "Másolva ✓"
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
            let point = NSPoint(
                x: bounds.maxX - Self.trailingPadding - size.width,
                y: band.minY + (band.height - size.height) / 2
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
