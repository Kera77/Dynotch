import AppKit

/// The cover's dominant colour, for the ring around it (spec MU-3): the most common lively hue,
/// made bright enough to show on black. Greyish covers give a soft white.
enum ArtworkColor {
    struct RGB: Equatable, Sendable {
        var red: Double
        var green: Double
        var blue: Double
    }

    static let fallback = RGB(red: 0.92, green: 0.92, blue: 0.92)
    private static let side = 24
    private static let bins = 12

    static func dominant(of image: NSImage) -> RGB {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return fallback }
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return drawn ? dominant(rgba: pixels) : fallback
    }

    /// RGBA bytes in, the colour out.
    static func dominant(rgba pixels: [UInt8]) -> RGB {
        var weights = [Double](repeating: 0, count: bins)
        var sums = [RGB](repeating: RGB(red: 0, green: 0, blue: 0), count: bins)
        for start in stride(from: 0, to: pixels.count - 3, by: 4) {
            let color = NSColor(
                srgbRed: Double(pixels[start]) / 255, green: Double(pixels[start + 1]) / 255,
                blue: Double(pixels[start + 2]) / 255, alpha: 1
            )
            let saturation = color.saturationComponent, brightness = color.brightnessComponent
            // Grey, near-black and near-white pixels say little about the cover's colour.
            guard saturation > 0.25, brightness > 0.2 else { continue }
            let bin = min(Int(color.hueComponent * Double(bins)), bins - 1)
            let weight = saturation * brightness
            weights[bin] += weight
            sums[bin].red += color.redComponent * weight
            sums[bin].green += color.greenComponent * weight
            sums[bin].blue += color.blueComponent * weight
        }
        guard let best = weights.indices.max(by: { weights[$0] < weights[$1] }), weights[best] > 0.5 else { return fallback }
        let total = weights[best]
        return brightened(RGB(red: sums[best].red / total, green: sums[best].green / total, blue: sums[best].blue / total))
    }

    /// At least 75% brightness, so the ring shows on the black notch.
    static func brightened(_ rgb: RGB) -> RGB {
        let color = NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        let bright = NSColor(
            hue: color.hueComponent, saturation: min(color.saturationComponent, 0.85),
            brightness: max(color.brightnessComponent, 0.75), alpha: 1
        ).usingColorSpace(.sRGB) ?? color
        return RGB(red: bright.redComponent, green: bright.greenComponent, blue: bright.blueComponent)
    }
}
