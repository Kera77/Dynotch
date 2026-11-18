import AppKit
import SwiftUI

/// Dragging a file out of the tray (spec FT-12b). A file promise: Dynotch writes the file into
/// the folder it is dropped in, under its own name, "name (1).ext" when that is taken. A tray
/// file is moved there (and leaves the tray), an attached folder's file is copied.
enum TrayFileTransfer {
    /// "report.pdf" → "report (1).pdf", "report (2).pdf"… until the name is free in `folder`.
    nonisolated static func freeURL(for name: String, in folder: URL, exists: (URL) -> Bool = {
        FileManager.default.fileExists(atPath: $0.path)
    }) -> URL {
        let wanted = folder.appendingPathComponent(name)
        guard exists(wanted) else { return wanted }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var number = 1
        while true {
            let candidate = folder.appendingPathComponent(ext.isEmpty ? "\(base) (\(number))" : "\(base) (\(number)).\(ext)")
            if !exists(candidate) { return candidate }
            number += 1
        }
    }

    /// Copies or moves `source` into `folder` under a free name.
    nonisolated static func transfer(_ source: URL, into folder: URL, move: Bool) throws -> URL {
        let target = freeURL(for: source.lastPathComponent, in: folder)
        if move {
            try FileManager.default.moveItem(at: source, to: target)
        } else {
            try FileManager.default.copyItem(at: source, to: target)
        }
        return target
    }
}

/// The promise for one file; the delegate writes it when the drop lands.
final class TrayFilePromise: NSObject, NSFilePromiseProviderDelegate {
    let source: URL
    let move: Bool
    let moved: @MainActor () -> Void

    init(source: URL, move: Bool, moved: @escaping @MainActor () -> Void) {
        self.source = source
        self.move = move
        self.moved = moved
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        source.lastPathComponent
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            // The destination's folder, with a free name there.
            _ = try TrayFileTransfer.transfer(source, into: url.deletingLastPathComponent(), move: move)
            if move {
                let done = moved
                DispatchQueue.main.async { MainActor.assumeIsolated { done() } }
            }
            DiagnosticsLog.append("tray", move ? "file moved out" : "file copied out")
            completionHandler(nil)
        } catch {
            DiagnosticsLog.append("tray", "drag out failed")
            completionHandler(error)
        }
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        Self.queue
    }

    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
}

/// Over a tray cell: a drag starts the file promise; clicks go to `click` (1 or 2); right
/// clicks fall through to the cell's context menu.
struct TrayDragSource: NSViewRepresentable {
    let url: URL
    let move: Bool
    let moved: @MainActor () -> Void
    let click: (Int) -> Void

    func makeNSView(context: Context) -> TrayDragSourceView {
        let view = TrayDragSourceView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: TrayDragSourceView, context: Context) {
        update(nsView)
    }

    private func update(_ view: TrayDragSourceView) {
        view.url = url
        view.move = move
        view.moved = moved
        view.click = click
    }
}

final class TrayDragSourceView: NSView, NSDraggingSource {
    var url: URL?
    var move = false
    var moved: @MainActor () -> Void = {}
    var click: (Int) -> Void = { _ in }

    private var downEvent: NSEvent?
    private var promise: TrayFilePromise?

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Right clicks belong to the SwiftUI context menu underneath.
        if let type = NSApp.currentEvent?.type, type == .rightMouseDown || type == .rightMouseUp { return nil }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        downEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let downEvent, let url else { return }
        let start = downEvent.locationInWindow
        let now = event.locationInWindow
        guard hypot(now.x - start.x, now.y - start.y) > 3 else { return }
        self.downEvent = nil
        let promise = TrayFilePromise(source: url, move: move, moved: moved)
        self.promise = promise
        let type = (try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier) ?? "public.data"
        let provider = NSFilePromiseProvider(fileType: type, delegate: promise)
        let item = NSDraggingItem(pasteboardWriter: provider)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        item.setDraggingFrame(NSRect(x: bounds.midX - 22, y: bounds.midY - 22, width: 44, height: 44), contents: icon)
        beginDraggingSession(with: [item], event: downEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard downEvent != nil else { return }
        downEvent = nil
        click(event.clickCount)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? (move ? .move : .copy) : .copy
    }
}
