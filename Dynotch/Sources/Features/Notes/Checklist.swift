import AppKit

/// To-do lists inside notes (spec J-12). Apple Notes does not let other apps read or write its
/// own checklists, so an item is a line that starts with a circle: "○ " open, "◉ " done. Dynotch
/// draws and toggles them; in Apple Notes they are ordinary lines with that circle.
enum Checklist {
    static let openMarker = "○"
    static let doneMarker = "◉"
    static let openPrefix = "○ "
    static let donePrefix = "◉ "

    /// nil: not an item; false: open; true: done.
    static func state(ofLine line: String) -> Bool? {
        if line.hasPrefix(openPrefix) || line == openMarker { return false }
        if line.hasPrefix(donePrefix) || line == doneMarker { return true }
        return nil
    }

    /// Where the lines go after the item at `index` was toggled: a done item moves to the end
    /// of its list, a reopened one to the end of the open items (as in Apple Notes).
    /// - Parameter states: the states before toggling.
    /// - Returns: for each new position, the old index of the line there.
    static func orderAfterToggling(_ index: Int, states: [Bool?]) -> [Int] {
        let identity = Array(states.indices)
        guard states.indices.contains(index), let wasDone = states[index] else { return identity }
        var first = index
        while first > 0, states[first - 1] != nil { first -= 1 }
        var last = index
        while last + 1 < states.count, states[last + 1] != nil { last += 1 }

        var block = Array(first...last).filter { $0 != index }
        if wasDone {
            // Reopened: after the last open item.
            let position = block.lastIndex { states[$0] == false }.map { $0 + 1 } ?? 0
            block.insert(index, at: position)
        } else {
            block.append(index)
        }
        return Array(identity[..<first]) + block + Array(identity[(last + 1)...])
    }

    /// Apple Notes' list items become open to-do items, so the note can be edited here.
    static func htmlByConvertingLists(_ html: String) -> String {
        var result = html
        let replacements: [(pattern: String, with: String)] = [
            (#"<li[^>]*>\s*"#, "<div>\(openPrefix)"),
            (#"\s*</li>\s*"#, "</div>"),
            (#"</?(ul|ol)[^>]*>"#, "")
        ]
        for replacement in replacements {
            result = result.replacingOccurrences(
                of: replacement.pattern, with: replacement.with, options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
    }

    /// True if lists are the only thing that keeps a note read-only.
    static func hasOnlyLists(html: String) -> Bool {
        NoteHTML.isRich(html: html) && !NoteHTML.isRich(html: htmlByConvertingLists(html))
    }
}

// MARK: - Editing

@MainActor
extension Checklist {
    static let accent = NSColor(red: 1, green: 0.62, blue: 0.1, alpha: 1)

    static func lines(of text: NSAttributedString) -> [NSAttributedString] {
        let string = text.string as NSString
        var lines: [NSAttributedString] = []
        var start = 0
        while start <= string.length {
            let found = string.range(of: "\n", range: NSRange(location: start, length: string.length - start))
            let end = found.location == NSNotFound ? string.length : found.location
            lines.append(text.attributedSubstring(from: NSRange(location: start, length: end - start)))
            if found.location == NSNotFound { break }
            start = end + 1
        }
        return lines
    }

    static func joined(_ lines: [NSAttributedString]) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for (index, line) in lines.enumerated() {
            if index > 0 { result.append(NSAttributedString(string: "\n", attributes: RichNoteFormat.baseAttributes)) }
            result.append(line)
        }
        return result
    }

    /// Number of the line a character position is in.
    static func lineIndex(at location: Int, in string: String) -> Int {
        let prefix = (string as NSString).substring(to: min(max(location, 0), (string as NSString).length))
        return prefix.components(separatedBy: "\n").count - 1
    }

    /// Colours the circles and dims done items. Colours are display only; they are not saved.
    static func restyle(_ text: NSMutableAttributedString) {
        let string = text.string as NSString
        guard string.length > 0 else { return }
        text.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: string.length))
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: [.byLines]) { line, range, _, _ in
            guard let line, let done = state(ofLine: line) else { return }
            let marker = NSRange(location: range.location, length: 1)
            text.addAttribute(.foregroundColor, value: done ? accent : NSColor.white.withAlphaComponent(0.55), range: marker)
            if done, range.length > 1 {
                let rest = NSRange(location: range.location + 1, length: range.length - 1)
                text.addAttribute(.foregroundColor, value: NSColor.white.withAlphaComponent(0.45), range: rest)
            }
        }
    }

    private static func replaceContents(of textView: NSTextView, with text: NSMutableAttributedString, caret: Int) {
        guard let storage = textView.textStorage else { return }
        restyle(text)
        guard textView.shouldChangeText(in: NSRange(location: 0, length: storage.length), replacementString: text.string) else { return }
        storage.setAttributedString(text)
        textView.didChangeText()
        textView.setSelectedRange(NSRange(location: min(max(caret, 0), text.length), length: 0))
    }

    private static func withMarker(_ marker: String?, _ line: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: line)
        if state(ofLine: line.string) != nil {
            result.deleteCharacters(in: NSRange(location: 0, length: min(2, result.length)))
        }
        if let marker {
            result.insert(NSAttributedString(string: marker + " ", attributes: RichNoteFormat.baseAttributes), at: 0)
        }
        return result
    }

    /// Checks or unchecks the item on a line and moves it to its place.
    static func toggleItem(onLine index: Int, in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        var lines = lines(of: storage)
        let states = lines.map { state(ofLine: $0.string) }
        guard lines.indices.contains(index), let wasDone = states[index] else { return }
        lines[index] = withMarker(wasDone ? openMarker : doneMarker, lines[index])
        let order = orderAfterToggling(index, states: states)
        replaceContents(of: textView, with: joined(order.map { lines[$0] }), caret: textView.selectedRange().location)
    }

    /// Turns the selected lines into to-do items, or back into plain lines if all are items.
    static func toggleList(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        var lines = lines(of: storage)
        let selection = textView.selectedRange()
        let first = lineIndex(at: selection.location, in: storage.string)
        let last = lineIndex(at: NSMaxRange(selection), in: storage.string)
        guard lines.indices.contains(first), lines.indices.contains(last) else { return }
        let allItems = (first...last).allSatisfy { state(ofLine: lines[$0].string) != nil }
        var caret = NSMaxRange(selection)
        for index in first...last {
            let wasItem = state(ofLine: lines[index].string) != nil
            if allItems {
                lines[index] = withMarker(nil, lines[index])
                caret -= 2
            } else if !wasItem {
                lines[index] = withMarker(openMarker, lines[index])
                caret += 2
            }
        }
        replaceContents(of: textView, with: joined(lines), caret: caret)
    }

    /// Return in an item starts the next item; in an empty item it ends the list.
    /// - Returns: false if the caret is not in an item (the text view handles Return itself).
    static func handleReturn(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage else { return false }
        let selection = textView.selectedRange()
        let string = storage.string as NSString
        let lineRange = string.lineRange(for: NSRange(location: selection.location, length: 0))
        let line = string.substring(with: lineRange).trimmingCharacters(in: .newlines)
        guard state(ofLine: line) != nil else { return false }
        if line.count <= 2 {
            // Empty item: remove the circle.
            let marker = NSRange(location: lineRange.location, length: min(line.utf16.count, lineRange.length))
            textView.insertText("", replacementRange: marker)
        } else {
            let next = NSAttributedString(string: "\n" + openPrefix, attributes: RichNoteFormat.baseAttributes)
            textView.insertText(next, replacementRange: selection)
        }
        return true
    }

    /// The line whose circle is at a point of the text view, if any.
    static func markerLine(at point: NSPoint, in textView: NSTextView) -> Int? {
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer,
              let storage = textView.textStorage, storage.length > 0
        else { return nil }
        let origin = textView.textContainerOrigin
        let location = NSPoint(x: point.x - origin.x, y: point.y - origin.y)
        let glyph = layoutManager.glyphIndex(for: location, in: container)
        let character = layoutManager.characterIndexForGlyph(at: glyph)
        let string = storage.string as NSString
        let lineRange = string.lineRange(for: NSRange(location: character, length: 0))
        guard character == lineRange.location, state(ofLine: string.substring(with: lineRange).trimmingCharacters(in: .newlines)) != nil
        else { return nil }
        // The click must be on the circle, not somewhere left or right of the line.
        let bounds = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        guard bounds.insetBy(dx: -4, dy: -2).contains(location) else { return nil }
        return lineIndex(at: character, in: storage.string)
    }
}
