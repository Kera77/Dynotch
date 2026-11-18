import AppKit
import SwiftUI

// MARK: - Screenshot editor (spec SH-6, SH-7, SH-11)

extension NotchController {
    /// Over the pop-up of a shot just made, the notch opens with the editor.
    func handleScreenshotPeek(at point: CGPoint) -> Bool {
        guard !model.isExpanded, let shot = screenshots.peek, !shot.isVideo,
              model.geometry.keepOpenZone(for: model.geometry.peekSize).contains(point)
        else { return false }
        openScreenshotEditor(shot.url, fromPeek: true)
        return true
    }

    func openScreenshotEditor(_ url: URL, fromPeek: Bool) {
        guard ScreenshotFiles.isEditable(url), let editor = ScreenshotEditor(url: url, tools: screenshots.settings.tools) else {
            NSWorkspace.shared.open(url)
            return
        }
        screenshots.clearPeek()
        hideStrip()
        setHoveredIndicator(nil)
        setHoveredBadge(nil)
        if !model.isExpanded { expand() }
        withAnimation(Self.animation) { model.setEditor(editor, closesNotch: fromPeek || !model.isExpanded) }
        // The editor types text and takes ⌘Z: the panel needs the keyboard.
        panel.allowsKey = true
        NSApp.activate()
        panel.makeKey()
    }

    func closeScreenshotEditor() {
        let closesNotch = model.editorClosesNotch
        withAnimation(Self.animation) { model.setEditor(nil) }
        if closesNotch { collapse() }
    }
}
