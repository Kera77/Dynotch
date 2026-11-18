import CoreGraphics
import Foundation

/// Joins the frames of a scrolling capture (spec SH-4): each new frame is compared with the
/// previous one to find how far the page moved, and only the new rows are added below.
enum ScrollStitcher {
    /// One number per pixel row: its mean brightness over a few sampled columns.
    static func rowSignature(of image: CGImage) -> [Double] {
        let width = 48, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return [] }
        // The bitmap's first row is the image's top row.
        return (0..<height).map { row in
            let start = row * width
            return Double(pixels[start..<(start + width)].reduce(0) { $0 + Int($1) }) / Double(width)
        }
    }

    /// How many rows the content moved up from `previous` to `next`; 0 when it did not move,
    /// nil when no good match is found (the frame is skipped).
    nonisolated static func offset(previous: [Double], next: [Double], minimumOverlap: Double = 0.25) -> Int? {
        let height = min(previous.count, next.count)
        guard height > 8 else { return nil }
        let minRows = max(Int(Double(height) * minimumOverlap), 4)
        if meanDifference(previous, next, shift: 0, rows: height) < 0.5 { return 0 }
        var best: (shift: Int, error: Double)?
        for shift in 1...(height - minRows) {
            let error = meanDifference(previous, next, shift: shift, rows: height - shift)
            if best.map({ error < $0.error }) ?? true { best = (shift, error) }
        }
        guard let best, best.error < 2 else { return nil }
        return best.shift
    }

    /// Mean difference of `previous` from row `shift` on against `next` from its top.
    private nonisolated static func meanDifference(_ previous: [Double], _ next: [Double], shift: Int, rows: Int) -> Double {
        var total = 0.0
        // Every other row is enough and halves the work.
        var compared = 0
        var row = 0
        while row < rows {
            total += abs(previous[row + shift] - next[row])
            compared += 1
            row += 2
        }
        return compared == 0 ? .infinity : total / Double(compared)
    }

    /// The first frame, then each frame's new bottom rows, as one tall image.
    static func join(_ first: CGImage, additions: [(image: CGImage, rows: Int)], maxHeight: Int = 40_000) -> CGImage? {
        let width = first.width
        let height = min(first.height + additions.reduce(0) { $0 + $1.rows }, maxHeight)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // Drawing goes from the top down; the context's origin is at the bottom.
        var top = 0
        context.draw(first, in: CGRect(x: 0, y: height - first.height, width: width, height: first.height))
        top = first.height
        for addition in additions where top < height {
            let rows = min(addition.rows, height - top)
            let source = CGRect(x: 0, y: addition.image.height - rows, width: addition.image.width, height: rows)
            guard let strip = addition.image.cropping(to: source) else { continue }
            context.draw(strip, in: CGRect(x: 0, y: height - top - rows, width: width, height: rows))
            top += rows
        }
        return context.makeImage()
    }
}
