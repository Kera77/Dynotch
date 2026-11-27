import AppKit
import Foundation
import Testing
@testable import Wingmate

@MainActor
struct ChecklistTests {
    @Test func linesWithACircleAreItems() {
        #expect(Checklist.state(ofLine: "○ milk") == false)
        #expect(Checklist.state(ofLine: "◉ bread") == true)
        #expect(Checklist.state(ofLine: "○") == false)
        #expect(Checklist.state(ofLine: "milk") == nil)
        #expect(Checklist.state(ofLine: "○milk") == nil)
        #expect(Checklist.state(ofLine: "") == nil)
    }

    /// Spec J-12: a checked item goes to the end of its list, a reopened one after the open ones.
    @Test func checkedItemsSink() {
        // title, a, b, c(done), text, d
        let states: [Bool?] = [nil, false, false, true, nil, false]
        #expect(Checklist.orderAfterToggling(1, states: states) == [0, 2, 3, 1, 4, 5])
        #expect(Checklist.orderAfterToggling(3, states: states) == [0, 1, 2, 3, 4, 5])
        #expect(Checklist.orderAfterToggling(5, states: states) == [0, 1, 2, 3, 4, 5])
        #expect(Checklist.orderAfterToggling(0, states: states) == [0, 1, 2, 3, 4, 5])
        // Reopening the last of two done items puts it after the open one.
        #expect(Checklist.orderAfterToggling(2, states: [false, true, true]) == [0, 2, 1])
        #expect(Checklist.orderAfterToggling(1, states: [true, true]) == [1, 0])
    }

    @Test func togglingMovesTheLineAndKeepsItsFormatting() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        let text = NSMutableAttributedString(string: "List\n○ one\n○ two\n◉ old", attributes: RichNoteFormat.baseAttributes)
        let bold = RichNoteFormat.makeFont(size: 14, bold: true, italic: false)
        text.addAttribute(.font, value: bold, range: NSRange(location: 7, length: 3))
        textView.textStorage?.setAttributedString(text)

        Checklist.toggleItem(onLine: 1, in: textView)
        #expect(textView.string == "List\n○ two\n◉ old\n◉ one")
        let moved = (textView.string as NSString).range(of: "one")
        let font = textView.textStorage?.attribute(.font, at: moved.location, effectiveRange: nil) as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.bold) == true)

        Checklist.toggleItem(onLine: 3, in: textView)
        #expect(textView.string == "List\n○ two\n○ one\n◉ old")
        // Not an item: nothing happens.
        Checklist.toggleItem(onLine: 0, in: textView)
        #expect(textView.string == "List\n○ two\n○ one\n◉ old")
    }

    @Test func theToolbarTurnsLinesIntoItemsAndBack() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        textView.textStorage?.setAttributedString(RichNoteFormat.plain("a\nb\nc"))
        textView.setSelectedRange(NSRange(location: 0, length: 3))
        Checklist.toggleList(in: textView)
        #expect(textView.string == "○ a\n○ b\nc")
        textView.setSelectedRange(NSRange(location: 0, length: 7))
        Checklist.toggleList(in: textView)
        #expect(textView.string == "a\nb\nc")
    }

    @Test func itemsSurviveSavingAndLoading() {
        let html = RichNoteFormat.html(from: RichNoteFormat.plain("Shop\n○ milk\n◉ bread"))
        #expect(html == "<div>Shop</div><div>○ milk</div><div>◉ bread</div>")
        #expect(RichNoteFormat.attributed(fromHTML: html).string == "Shop\n○ milk\n◉ bread")
        #expect(!NoteHTML.isRich(html: html))
    }

    /// Spec J-12b: Apple Notes lists become to-do items so the note can be edited.
    @Test func appleNotesListsBecomeItems() {
        let html = "<div>Shop</div><ul><li>milk</li>\n<li>bread</li></ul><div>end</div>"
        #expect(Checklist.hasOnlyLists(html: html))
        let converted = Checklist.htmlByConvertingLists(html)
        #expect(converted == "<div>Shop</div><div>○ milk</div><div>○ bread</div><div>end</div>")
        #expect(!Checklist.hasOnlyLists(html: "<ul><li>a</li></ul><img src=\"x\">"))
        #expect(!Checklist.hasOnlyLists(html: "<div>plain</div>"))
    }
}
