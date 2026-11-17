import AppKit
import Quartz

/// Quick Look for the tray's files (spec FT-8): Space shows the chosen file, Space again closes.
@MainActor
final class TrayQuickLook: NSObject, QLPreviewPanelDataSource {
    static let shared = TrayQuickLook()

    private var urls: [URL] = []

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

    /// Watches `url` (nil: nothing); `changed` runs on the main thread.
    func watch(_ url: URL?, changed: @escaping @MainActor () -> Void) {
        guard url?.standardizedFileURL != watched?.standardizedFileURL else { return }
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
