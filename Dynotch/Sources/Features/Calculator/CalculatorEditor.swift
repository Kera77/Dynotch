import SwiftUI

/// The calculator notepad: type calculations on the left, results appear on the right.
struct CalculatorEditor: NSViewRepresentable {
    @Binding var text: String
    /// Shown and ready for typing: the caret goes to a new line (spec SZ-10).
    var isActive = true

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CalculatorTextView.makeScrollView(text: text)
        (scrollView.documentView as? CalculatorTextView)?.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        if isActive, !context.coordinator.wasActive, let textView = scrollView.documentView as? CalculatorTextView {
            // After this update, once the view is in its window.
            DispatchQueue.main.async { textView.focusForTyping() }
        }
        context.coordinator.wasActive = isActive
        // Another editor (other display, menu bar panel) changed the shared text.
        guard let textView = scrollView.documentView as? CalculatorTextView, textView.string != text else { return }
        textView.string = text
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var wasActive = false

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

/// Lock icon: gray when off, green when the panel is kept open (spec SZ-8).
struct PinButton: View {
    let isPinned: Bool
    let action: () -> Void

    /// Blue while pinned, like the keyboard lock (spec SZ-8).
    static let activeColor = ClaudeUsageView.blue

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "lock.fill" : "lock.open.fill")
                .font(.notch(size: 12, weight: .semibold))
                .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                .foregroundStyle(isPinned ? Self.activeColor : Color.white.level(0.45))
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .help(isPinned ? "Pinned: stays open" : "Pin: keep open")
    }
}

/// Calculator feature in the notch.
struct CalculatorFeatureView: View {
    @Bindable var store: CalculatorStore
    var isActive = false

    var body: some View {
        CalculatorEditor(text: $store.text, isActive: isActive)
            .padding(.top, 4)
    }
}
