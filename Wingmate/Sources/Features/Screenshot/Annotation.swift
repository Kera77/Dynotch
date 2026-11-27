import AppKit
import CoreImage

/// The editor's colours (spec SH-8).
enum EditorColor: String, CaseIterable, Identifiable, Sendable {
    case red, orange, yellow, green, blue, purple, white, black

    var id: String { rawValue }

    var nsColor: NSColor {
        switch self {
        case .red: NSColor(srgbRed: 1, green: 0.23, blue: 0.19, alpha: 1)
        case .orange: NSColor(srgbRed: 1, green: 0.58, blue: 0, alpha: 1)
        case .yellow: NSColor(srgbRed: 1, green: 0.84, blue: 0.04, alpha: 1)
        case .green: NSColor(srgbRed: 0.2, green: 0.78, blue: 0.35, alpha: 1)
        case .blue: NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
        case .purple: NSColor(srgbRed: 0.69, green: 0.32, blue: 0.87, alpha: 1)
        case .white: .white
        case .black: .black
        }
    }
}

/// One thing drawn on the shot, in the image's pixels from its top left (spec SH-8).
struct Annotation: Identifiable, Equatable {
    enum Shape: Equatable {
        case arrow(CGPoint, CGPoint)
        case line(CGPoint, CGPoint)
        case rectangle(CGRect)
        case ellipse(CGRect)
        case pencil([CGPoint])
        case highlighter([CGPoint])
        case pixelate(CGRect)
        case counter(CGPoint, Int)
        case text(CGPoint, String)
    }

    let id = UUID()
    var shape: Shape
    var color: EditorColor
    /// Line width in image pixels.
    var width: CGFloat

    nonisolated static func rect(_ start: CGPoint, _ end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
    }

    /// The two sides of an arrow's head at `tip`, coming from `tail`.
    nonisolated static func arrowHead(from tail: CGPoint, to tip: CGPoint, length: CGFloat) -> (CGPoint, CGPoint) {
        let angle = atan2(tip.y - tail.y, tip.x - tail.x)
        let spread = CGFloat.pi / 7
        return (
            CGPoint(x: tip.x - length * cos(angle - spread), y: tip.y - length * sin(angle - spread)),
            CGPoint(x: tip.x - length * cos(angle + spread), y: tip.y - length * sin(angle + spread))
        )
    }
}

/// Draws the shot and its annotations into a context whose origin is at the top left (y down):
/// the editor's canvas and the saved file use the same code (spec SH-8, SH-9).
enum AnnotationRenderer {
    /// The image with everything drawn on it, cut to `crop`.
    static func render(_ image: CGImage, annotations: [Annotation], crop: CGRect?, pixelated: CGImage?) -> CGImage? {
        let area = (crop ?? CGRect(x: 0, y: 0, width: image.width, height: image.height)).integral
        guard area.width >= 1, area.height >= 1, let context = CGContext(
            data: nil, width: Int(area.width), height: Int(area.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.translateBy(x: 0, y: area.height)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: -area.minX, y: -area.minY)
        draw(image, annotations: annotations, pixelated: pixelated, in: context)
        return context.makeImage()
    }

    static func draw(_ image: CGImage, annotations: [Annotation], pixelated: CGImage?, in context: CGContext) {
        let full = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        drawImage(image, in: full, context: context)
        for annotation in annotations { draw(annotation, pixelated: pixelated, full: full, in: context) }
    }

    /// CGImages are drawn bottom up: flip them for the top-left context.
    static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    static func draw(_ annotation: Annotation, pixelated: CGImage?, full: CGRect, in context: CGContext) {
        let color = annotation.color.nsColor.cgColor
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(annotation.width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        switch annotation.shape {
        case let .arrow(start, end):
            context.strokeLineSegments(between: [start, end])
            let head = Annotation.arrowHead(from: start, to: end, length: annotation.width * 4.5)
            context.addLines(between: [head.0, end, head.1])
            context.closePath()
            context.fillPath()
        case let .line(start, end):
            context.strokeLineSegments(between: [start, end])
        case let .rectangle(rect):
            context.stroke(rect)
        case let .ellipse(rect):
            context.strokeEllipse(in: rect)
        case let .pencil(points):
            stroke(points, in: context)
        case let .highlighter(points):
            context.setStrokeColor(annotation.color.nsColor.withAlphaComponent(0.35).cgColor)
            context.setLineWidth(annotation.width * 5)
            context.setLineCap(.butt)
            context.setBlendMode(.multiply)
            stroke(points, in: context)
        case let .pixelate(rect):
            guard let pixelated else { return }
            context.clip(to: rect)
            drawImage(pixelated, in: full, context: context)
        case let .counter(center, number):
            drawCounter(number, at: center, radius: annotation.width * 3.2, color: annotation.color, in: context)
        case let .text(origin, string):
            drawText(string, at: origin, size: annotation.width * 6, color: annotation.color.nsColor, in: context)
        }
    }

    private static func stroke(_ points: [CGPoint], in context: CGContext) {
        guard let first = points.first else { return }
        context.move(to: first)
        points.dropFirst().forEach { context.addLine(to: $0) }
        context.strokePath()
    }

    private static func drawCounter(_ number: Int, at center: CGPoint, radius: CGFloat, color: EditorColor, in context: CGContext) {
        context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        let text = "\(number)" as NSString
        let textColor: NSColor = color == .white || color == .yellow ? .black : .white
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: radius * 1.15, weight: .bold), .foregroundColor: textColor
        ]
        let size = text.size(withAttributes: attributes)
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        withAppKit(context) { text.draw(at: origin, withAttributes: attributes) }
    }

    private static func drawText(_ string: String, at origin: CGPoint, size: CGFloat, color: NSColor, in context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: color]
        withAppKit(context) { (string as NSString).draw(at: origin, withAttributes: attributes) }
    }

    /// AppKit text drawing into the top-left context.
    private static func withAppKit(_ context: CGContext, _ body: () -> Void) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        body()
        NSGraphicsContext.current = previous
    }

    /// The whole shot in large blocks, cut out where something is pixelated.
    static func pixelated(_ image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIPixellate") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(max(Double(max(image.width, image.height)) / 90, 8), forKey: kCIInputScaleKey)
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return nil }
        return CIContext().createCGImage(output, from: input.extent)
    }
}
