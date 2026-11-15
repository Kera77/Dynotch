import SwiftUI

/// The calculator notepad: type calculations on the left, results appear on the right.
struct CalculatorEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // TextKit 1: the results are drawn from the layout manager's line rects.
        let textView = CalculatorTextView(usingTextLayoutManager: false)
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = CalculatorTextView.editorFont
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
            .font: CalculatorTextView.editorFont,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]

        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        // Another editor (other display, menu bar panel) changed the shared text.
        guard let textView = scrollView.documentView as? CalculatorTextView, textView.string != text else { return }
        textView.string = text
        textView.needsDisplay = true
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
            // Results sit outside the text container, so redraw the whole view.
            textView.needsDisplay = true
        }
    }
}

/// Lock icon: gray when off, green when the panel is kept open (spec SZ-8).
struct PinButton: View {
    let isPinned: Bool
    let action: () -> Void

    static let activeColor = Color(red: 0.25, green: 0.86, blue: 0.45)

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 22)
                .foregroundStyle(isPinned ? Self.activeColor : Color.white.opacity(0.45))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isPinned ? "Rögzítve: nyitva marad" : "Rögzítés: maradjon nyitva")
    }
}

/// Calculator feature in the notch.
struct CalculatorFeatureView: View {
    @ObservedObject var store: CalculatorStore

    var body: some View {
        CalculatorEditor(text: $store.text)
            .padding(.top, 4)
    }
}
