import Foundation

/// Tells when a download in `~/Downloads` has finished (spec PV-57). No polling and no progress:
/// the kernel wakes it when the folder changes (a browser renaming its `.crdownload` / `.download`
/// file to the finished name), and only then is the folder read.
@MainActor
final class DownloadWatcher {
    private let finished: (URL) -> Void
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []
    private var pending: Task<Void, Never>?

    /// A file counts as just downloaded this long after it was last written.
    nonisolated static let freshness: TimeInterval = 15

    init(finished: @escaping (URL) -> Void) {
        self.finished = finished
    }

    func start(folder: URL? = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first) {
        guard source == nil, let folder else { return }
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else {
            DiagnosticsLog.append("tray", "downloads: folder not readable, no download notices")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.folderChanged(folder) }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    /// Several changes in a row (the rename, the browser's own bookkeeping) are read once.
    private func folderChanged(_ folder: URL) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.check(folder)
        }
    }

    private func check(_ folder: URL) {
        let files = Self.finishedFiles(in: folder, now: Date())
        let new = files.filter { !known.contains($0.url.path) }
        known.formUnion(files.map(\.url.path))
        guard let newest = new.max(by: { $0.date < $1.date }) else { return }
        DiagnosticsLog.append("tray", "downloads: a download finished")
        finished(newest.url)
    }

    /// Finished files (not hidden, not folders, not half-done) written in the last moments.
    nonisolated static func finishedFiles(in folder: URL, now: Date) -> [(url: URL, date: Date)] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )) ?? []
        return files.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isDirectory != true,
                  !SmartOpening.partialExtensions.contains(url.pathExtension.lowercased()),
                  let date = values.contentModificationDate, now.timeIntervalSince(date) <= freshness
            else { return nil }
            return (url, date)
        }
    }
}
