import AppKit
import UniformTypeIdentifiers

/// Where shots and recordings go, and the clipboard (spec SH-3, SH-11).
enum ScreenshotFiles {
    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/Screenshots", isDirectory: true)
    }

    /// "Screenshot 2026-11-18 at 17.45.12.png", like macOS names its own.
    nonisolated static func name(prefix: String, date: Date, ext: String, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let time = String(format: "%02d.%02d.%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
        return "\(prefix) \(day) at \(time).\(ext)"
    }

    /// A free file name in the folder, made if missing.
    @MainActor
    static func newURL(prefix: String, ext: String, date: Date = Date()) -> URL {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return TrayStore.freeName(for: name(prefix: prefix, date: date, ext: ext), in: folder)
    }

    static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// Saves a shot; nil if it could not be written.
    static func save(_ image: CGImage, to url: URL) -> Bool {
        guard let data = pngData(image) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            DiagnosticsLog.append("screenshots", "save failed: \(error.localizedDescription)")
            return false
        }
    }

    /// The image and its file on the clipboard, so it pastes into chats and Finder alike.
    @MainActor
    static func copy(_ image: CGImage, file: URL?) {
        let board = NSPasteboard.general
        board.clearContents()
        let item = NSPasteboardItem()
        if let data = pngData(image) { item.setData(data, forType: .png) }
        if let file { item.setString(file.absoluteString, forType: .fileURL) }
        board.writeObjects([item])
    }

    /// A recording goes on the clipboard as its file.
    @MainActor
    static func copyFile(_ url: URL) {
        let board = NSPasteboard.general
        board.clearContents()
        board.writeObjects([url as NSURL])
    }

    /// The newest images and recordings, newest first (spec SH-11).
    static func recent(_ limit: Int = 10, in directory: URL = folder) -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let found = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )) ?? []
        let wanted: Set<String> = ["png", "jpg", "jpeg", "heic", "mov", "mp4"]
        func date(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        return Array(found.filter { wanted.contains($0.pathExtension.lowercased()) }.sorted { date($0) > date($1) }.prefix(limit))
    }

    static func isEditable(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "heic"].contains(url.pathExtension.lowercased())
    }
}
