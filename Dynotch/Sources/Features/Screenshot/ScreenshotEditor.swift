import AppKit
import ImageIO

/// The open shot in the editor (spec SH-7…SH-10): its annotations and crop, undo and redo, and
/// writing the result back to the file.
@MainActor
final class ScreenshotEditor: ObservableObject {
    let url: URL
    let image: CGImage
    @Published private(set) var annotations: [Annotation] = []
    @Published private(set) var crop: CGRect?
    @Published var tool: EditorTool
    @Published var color = EditorColor.red
    /// 0, 1, 2: thin, medium, thick.
    @Published var widthLevel = 1
    /// Being drawn right now.
    @Published var draft: Annotation?
    @Published var cropDraft: CGRect?
    /// Where a text is being typed, in image pixels.
    @Published var textAnchor: CGPoint?
    @Published var typedText = ""
    @Published private(set) var message: String?

    private var undoStack: [(annotations: [Annotation], crop: CGRect?)] = []
    private var redoStack: [(annotations: [Annotation], crop: CGRect?)] = []
    private lazy var pixelatedImage: CGImage? = AnnotationRenderer.pixelated(image)

    init?(url: URL, tools: [EditorTool]) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        self.url = url
        self.image = image
        tool = tools.first { !$0.isAction } ?? .arrow
    }

    var pixelated: CGImage? { pixelatedImage }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var hasChanges: Bool { !annotations.isEmpty || crop != nil }

    /// The part shown and saved.
    var visibleRect: CGRect { crop ?? CGRect(x: 0, y: 0, width: image.width, height: image.height) }

    /// Line widths grow with the image, so they look alike on small and large shots.
    var lineWidth: CGFloat {
        let unit = min(max(CGFloat(max(image.width, image.height)) / 1000, 1), 4)
        return [2, 4, 7][min(max(widthLevel, 0), 2)] * unit
    }

    var nextCounter: Int {
        annotations.reduce(1) { count, item in if case .counter = item.shape { count + 1 } else { count } }
    }

    // MARK: - Drawing

    /// A drag in image pixels: the shape follows it until the mouse is let go.
    func drag(from start: CGPoint, to end: CGPoint) {
        let width = lineWidth
        switch tool {
        case .arrow: draft = Annotation(shape: .arrow(start, end), color: color, width: width)
        case .line: draft = Annotation(shape: .line(start, end), color: color, width: width)
        case .rectangle: draft = Annotation(shape: .rectangle(Annotation.rect(start, end)), color: color, width: width)
        case .ellipse: draft = Annotation(shape: .ellipse(Annotation.rect(start, end)), color: color, width: width)
        case .pixelate: draft = Annotation(shape: .pixelate(Annotation.rect(start, end)), color: color, width: width)
        case .pencil, .highlighter: extendStroke(to: end, from: start)
        case .crop: cropDraft = Annotation.rect(start, end).intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        case .counter, .text, .copy, .save: break
        }
    }

    private func extendStroke(to point: CGPoint, from start: CGPoint) {
        if case .pencil(let points)? = draft?.shape {
            draft?.shape = .pencil(points + [point])
        } else if case .highlighter(let points)? = draft?.shape {
            draft?.shape = .highlighter(points + [point])
        } else {
            let points = [start, point]
            draft = Annotation(shape: tool == .pencil ? .pencil(points) : .highlighter(points), color: color, width: lineWidth)
        }
    }

    func endDrag(at end: CGPoint, start: CGPoint) {
        let moved = hypot(end.x - start.x, end.y - start.y) > 3
        switch tool {
        case .counter:
            add(Annotation(shape: .counter(end, nextCounter), color: color, width: lineWidth))
        case .text:
            textAnchor = end
            typedText = ""
        case .crop:
            if let cropDraft, cropDraft.width > 8, cropDraft.height > 8 { record { crop = cropDraft.integral } }
            cropDraft = nil
        default:
            if let draft, moved { add(draft) }
        }
        draft = nil
    }

    func commitText() {
        let text = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let anchor = textAnchor, !text.isEmpty {
            add(Annotation(shape: .text(anchor, text), color: color, width: lineWidth))
        }
        textAnchor = nil
        typedText = ""
    }

    private func add(_ annotation: Annotation) {
        record { annotations.append(annotation) }
    }

    private func record(_ change: () -> Void) {
        undoStack.append((annotations, crop))
        redoStack = []
        change()
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append((annotations, crop))
        annotations = last.annotations
        crop = last.crop
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append((annotations, crop))
        annotations = next.annotations
        crop = next.crop
    }

    // MARK: - Result (spec SH-9)

    func rendered() -> CGImage? {
        AnnotationRenderer.render(image, annotations: annotations, crop: crop, pixelated: pixelated)
    }

    func copy() {
        guard let result = rendered() else { return }
        ScreenshotFiles.copy(result, file: nil)
        flash("Copied")
    }

    /// Overwrites the file and puts the result on the clipboard.
    @discardableResult
    func save() -> Bool {
        commitText()
        guard let result = rendered(), ScreenshotFiles.save(result, to: url) else {
            flash("Couldn't save")
            return false
        }
        ScreenshotFiles.copy(result, file: url)
        flash("Saved")
        return true
    }

    private func flash(_ text: String) {
        message = text
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            if self?.message == text { self?.message = nil }
        }
    }
}
