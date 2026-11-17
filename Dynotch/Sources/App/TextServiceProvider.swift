import AppKit

/// "New Dynotch Note" in the Services menu of any app: the selected text goes to the notes
/// scratchpad and the notch opens on it (spec J-13).
@MainActor
final class TextServiceProvider: NSObject {
    private let received: (String) -> Void

    init(received: @escaping (String) -> Void) {
        self.received = received
    }

    @objc func makeNote(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "No text was selected." as NSString
            return
        }
        received(text)
    }
}
