import AppKit

/// Plain text editor that draws each line's result, in green, at the right edge (spec SZ-2).
final class CalculatorTextView: NSTextView {
    static let resultColumnWidth: CGFloat = 130
    private static let resultColor = NSColor(srgbRed: 0.25, green: 0.86, blue: 0.45, alpha: 1)
    private static let placeholder = "Írj be egy számítást, pl. 1200 * 1,27"

    static var editorFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // Keep the text out of the result column.
        let width = max(newSize.width - Self.resultColumnWidth, 60)
        if let textContainer, textContainer.containerSize.width != width {
            textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        }
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
        if string.isEmpty {
            drawPlaceholder()
        } else {
            drawResults(in: dirtyRect)
        }
    }

    private func drawPlaceholder() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.editorFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.3)
        ]
        let origin = textContainerOrigin
        let padding = textContainer?.lineFragmentPadding ?? 0
        (Self.placeholder as NSString).draw(at: NSPoint(x: origin.x + padding, y: origin.y), withAttributes: attributes)
    }

    private func drawResults(in dirtyRect: NSRect) {
        guard let layoutManager, textContainer != nil else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: Self.resultColor
        ]
        let text = string as NSString
        let origin = textContainerOrigin
        var location = 0
        while location < text.length {
            let range = text.paragraphRange(for: NSRange(location: location, length: 0))
            location = NSMaxRange(range)
            let line = text.substring(with: range).trimmingCharacters(in: .newlines)
            guard let result = CalculatorEngine.result(for: line) else { continue }

            let glyphIndex = layoutManager.glyphIndexForCharacter(at: range.location)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let size = (result as NSString).size(withAttributes: attributes)
            let point = NSPoint(
                x: bounds.maxX - 8 - size.width,
                y: origin.y + lineRect.minY + (lineRect.height - size.height) / 2
            )
            if dirtyRect.intersects(NSRect(origin: point, size: size)) {
                (result as NSString).draw(at: point, withAttributes: attributes)
            }
        }
    }
}
