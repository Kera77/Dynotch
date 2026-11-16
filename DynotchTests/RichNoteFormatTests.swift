import AppKit
@testable import Dynotch
import Testing

@MainActor
struct RichNoteFormatTests {
    /// Spec J-10: bold, italic, underline, strikethrough and heading sizes survive a save.
    @Test func roundTripKeepsFormatting() {
        let html = #"<div><b><span style="font-size: 24px">Title</span></b></div><div><br></div>"#
            + #"<div>a <b>b</b> <i>c</i> <u>d</u> <strike>e</strike> &amp; &lt;x&gt;</div>"#
        let rich = RichNoteFormat.attributed(fromHTML: html)
        #expect(rich.string == "Title\n\na b c d e & <x>")
        let out = RichNoteFormat.html(from: rich)
        #expect(out.contains("<b>b</b>"))
        #expect(out.contains("<i>c</i>"))
        #expect(out.contains("<u>d</u>"))
        #expect(out.contains("<strike>e</strike>"))
        #expect(out.contains("font-size: 24px"))
        #expect(out.contains("&amp; &lt;x&gt;"))
        #expect(out.contains("<div><br></div>"))
        #expect(RichNoteFormat.html(from: RichNoteFormat.attributed(fromHTML: out)) == out)
    }

    @Test func toggleBoldOnSelection() {
        let textView = NSTextView()
        textView.textStorage?.setAttributedString(RichNoteFormat.plain("hello world"))
        textView.setSelectedRange(NSRange(location: 0, length: 5))
        RichNoteFormat.toggle(.bold, in: textView)
        #expect(RichNoteFormat.html(from: textView.attributedString()) == "<div><b>hello</b> world</div>")
        RichNoteFormat.toggle(.bold, in: textView)
        #expect(RichNoteFormat.html(from: textView.attributedString()) == "<div>hello world</div>")
    }

    @Test func headingStyleAppliesToTheParagraph() {
        let textView = NSTextView()
        textView.textStorage?.setAttributedString(RichNoteFormat.plain("one\ntwo"))
        textView.setSelectedRange(NSRange(location: 5, length: 0))
        RichNoteFormat.apply(.heading, in: textView)
        let html = RichNoteFormat.html(from: textView.attributedString())
        #expect(html == #"<div>one</div><div><span style="font-size: 18px"><b>two</b></span></div>"#)
    }

    /// Plain-text drafts from older versions open unchanged.
    @Test func plainText() {
        #expect(RichNoteFormat.html(from: RichNoteFormat.plain("a\n\nb")) == "<div>a</div><div><br></div><div>b</div>")
    }
}
