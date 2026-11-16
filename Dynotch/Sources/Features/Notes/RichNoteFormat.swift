import AppKit

/// Formatted note text: import from and export to the simple HTML Apple Notes stores, and the
/// formatting commands of the editor (spec J-10, J-11).
@MainActor
enum RichNoteFormat {
    nonisolated static let bodySize: CGFloat = 14

    /// Paragraph styles, as in Apple Notes.
    enum ParagraphStyle: String, CaseIterable, Identifiable {
        case title
        case heading
        case subheading
        case body

        var id: String { rawValue }

        var name: String {
            switch self {
            case .title: "Title"
            case .heading: "Heading"
            case .subheading: "Subheading"
            case .body: "Body"
            }
        }

        var size: CGFloat {
            switch self {
            case .title: 24
            case .heading: 18
            case .subheading: 16
            case .body: RichNoteFormat.bodySize
            }
        }

        var isBold: Bool { self != .body }
    }

    enum InlineStyle {
        case bold
        case italic
        case underline
        case strikethrough
    }

    static var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        return [.font: NSFont.systemFont(ofSize: bodySize), .foregroundColor: NSColor.white, .paragraphStyle: paragraph]
    }

    static func plain(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: baseAttributes)
    }

    // MARK: - HTML → formatted text

    /// Keeps bold, italic, underline, strikethrough and larger sizes; everything else becomes the
    /// editor's base style (white system font).
    static func attributed(fromHTML html: String) -> NSAttributedString {
        guard let data = html.data(using: .utf8),
              let imported = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
              )
        else { return plain(html) }

        var string = imported.string
        while string.hasSuffix("\n") { string.removeLast() }
        let result = NSMutableAttributedString(string: string, attributes: baseAttributes)
        let length = (string as NSString).length
        imported.enumerateAttributes(in: NSRange(location: 0, length: min(length, imported.length))) { attributes, range, _ in
            let importedFont = attributes[.font] as? NSFont
            let traits = importedFont?.fontDescriptor.symbolicTraits ?? []
            let size = importedFont.map { snappedSize($0.pointSize) } ?? bodySize
            let font = makeFont(size: size, bold: traits.contains(.bold), italic: traits.contains(.italic))
            result.addAttribute(.font, value: font, range: range)
            if let underline = attributes[.underlineStyle] as? Int, underline != 0 {
                result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            if let strike = attributes[.strikethroughStyle] as? Int, strike != 0 {
                result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
        Checklist.restyle(result)
        return result
    }

    /// Imported sizes snap to the paragraph styles.
    private static func snappedSize(_ size: CGFloat) -> CGFloat {
        if size >= 21 { return ParagraphStyle.title.size }
        if size >= 17 { return ParagraphStyle.heading.size }
        if size >= 15 { return ParagraphStyle.subheading.size }
        return bodySize
    }

    // MARK: - Formatted text → HTML

    /// One `<div>` per line; inline `<b>`, `<i>`, `<u>`, `<strike>` and a font size for headings.
    static func html(from text: NSAttributedString) -> String {
        let string = text.string as NSString
        var html = ""
        var location = 0
        repeat {
            let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
            var contentRange = lineRange
            while contentRange.length > 0,
                  let scalar = UnicodeScalar(string.character(at: NSMaxRange(contentRange) - 1)),
                  CharacterSet.newlines.contains(scalar) {
                contentRange.length -= 1
            }
            html += contentRange.length == 0 ? "<div><br></div>" : "<div>\(inlineHTML(text, range: contentRange))</div>"
            location = NSMaxRange(lineRange)
        } while location < string.length
        return html
    }

    private static func inlineHTML(_ text: NSAttributedString, range: NSRange) -> String {
        var html = ""
        text.enumerateAttributes(in: range) { attributes, runRange, _ in
            var run = NoteHTML.escape((text.string as NSString).substring(with: runRange))
            let font = attributes[.font] as? NSFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            if (attributes[.strikethroughStyle] as? Int ?? 0) != 0 { run = "<strike>\(run)</strike>" }
            if (attributes[.underlineStyle] as? Int ?? 0) != 0 { run = "<u>\(run)</u>" }
            if traits.contains(.italic) { run = "<i>\(run)</i>" }
            if traits.contains(.bold) { run = "<b>\(run)</b>" }
            if let size = font?.pointSize, size > bodySize + 0.5 {
                run = "<span style=\"font-size: \(Int(size.rounded()))px\">\(run)</span>"
            }
            html += run
        }
        return html
    }

    // MARK: - Commands

    static func makeFont(size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        var font = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        if italic {
            let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.italic))
            font = NSFont(descriptor: descriptor, size: size) ?? font
        }
        return font
    }

    /// Toggles a style on the selection (or for what is typed next when nothing is selected).
    static func toggle(_ style: InlineStyle, in textView: NSTextView) {
        let range = textView.selectedRange()
        guard range.length > 0, let storage = textView.textStorage else {
            textView.typingAttributes = toggled(style, in: textView.typingAttributes, turnOn: !has(style, textView.typingAttributes))
            return
        }
        // On if any part lacks it, off if all of it has it.
        var allHave = true
        storage.enumerateAttributes(in: range) { attributes, _, stop in
            if !has(style, attributes) { allHave = false; stop.pointee = true }
        }
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        storage.enumerateAttributes(in: range) { attributes, runRange, _ in
            storage.setAttributes(toggled(style, in: attributes, turnOn: !allHave), range: runRange)
        }
        storage.endEditing()
        textView.didChangeText()
    }

    /// Applies a paragraph style to every paragraph the selection touches.
    static func apply(_ style: ParagraphStyle, in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let range = (storage.string as NSString).paragraphRange(for: textView.selectedRange())
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, runRange, _ in
            let italic = (value as? NSFont)?.fontDescriptor.symbolicTraits.contains(.italic) ?? false
            storage.addAttribute(.font, value: makeFont(size: style.size, bold: style.isBold, italic: italic), range: runRange)
        }
        storage.endEditing()
        var typing = textView.typingAttributes
        typing[.font] = makeFont(size: style.size, bold: style.isBold, italic: false)
        textView.typingAttributes = typing
        textView.didChangeText()
    }

    static func has(_ style: InlineStyle, _ attributes: [NSAttributedString.Key: Any]) -> Bool {
        let traits = (attributes[.font] as? NSFont)?.fontDescriptor.symbolicTraits ?? []
        switch style {
        case .bold: return traits.contains(.bold)
        case .italic: return traits.contains(.italic)
        case .underline: return (attributes[.underlineStyle] as? Int ?? 0) != 0
        case .strikethrough: return (attributes[.strikethroughStyle] as? Int ?? 0) != 0
        }
    }

    private static func toggled(
        _ style: InlineStyle, in attributes: [NSAttributedString.Key: Any], turnOn: Bool
    ) -> [NSAttributedString.Key: Any] {
        var result = attributes
        let font = attributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: bodySize)
        let traits = font.fontDescriptor.symbolicTraits
        switch style {
        case .bold:
            result[.font] = makeFont(size: font.pointSize, bold: turnOn, italic: traits.contains(.italic))
        case .italic:
            result[.font] = makeFont(size: font.pointSize, bold: traits.contains(.bold), italic: turnOn)
        case .underline:
            result[.underlineStyle] = turnOn ? NSUnderlineStyle.single.rawValue : nil
        case .strikethrough:
            result[.strikethroughStyle] = turnOn ? NSUnderlineStyle.single.rawValue : nil
        }
        return result
    }
}
