import AppKit
import Quartz

/// Quick Look for the tray's files (spec FT-8): Space shows the chosen file, Space again closes.
@MainActor
final class TrayQuickLook: NSObject, QLPreviewPanelDataSource {
    static let shared = TrayQuickLook()

    private var urls: [URL] = []
    /// The preview opened or closed: the notch stays while it shows (spec FT-8b).
    var shownChanged: (Bool) -> Void = { _ in }
    private var watch: Timer?
    private var isShown = false

    /// Follows the panel, which also closes by itself (its X, Esc, a click elsewhere).
    private func follow() {
        set(true)
        watch?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let visible = QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared()?.isVisible == true
                if !visible {
                    self.watch?.invalidate()
                    self.watch = nil
                    self.set(false)
                }
            }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        watch = timer
    }

    private func set(_ shown: Bool) {
        guard shown != isShown else { return }
        isShown = shown
        shownChanged(shown)
    }

    func toggle(_ url: URL) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible, urls == [url] {
            panel.orderOut(nil)
            return
        }
        urls = [url]
        panel.dataSource = self
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        panel.makeKeyAndOrderFront(nil)
        follow()
    }

    func close() {
        guard QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
        panel.orderOut(nil)
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { urls.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        let url: URL? = MainActor.assumeIsolated { urls.indices.contains(index) ? urls[index] : nil }
        return url.map { $0 as NSURL }
    }
}

/// Follows a folder's changes, so an attached folder shows files added or removed elsewhere
/// (spec FT-9).
@MainActor
final class FolderWatcher {
    private var source: DispatchSourceFileSystemObject?
    private(set) var watched: URL?

    /// Watches `url` (nil: nothing); `changed` runs on the main thread. A file that is replaced
    /// (deleted or renamed) is watched again on the next call with `renew`.
    func watch(_ url: URL?, renew: Bool = false, changed: @escaping @MainActor () -> Void) {
        guard renew || url?.standardizedFileURL != watched?.standardizedFileURL else { return }
        source?.cancel()
        source = nil
        watched = url
        guard let url else { return }
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .rename, .delete, .extend], queue: .main
        )
        source.setEventHandler {
            MainActor.assumeIsolated { changed() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }
}
