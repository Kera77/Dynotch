import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// v0.61: sharp screenshot parts (spec SH-3d) and tab colours for Tray and Screenshots (spec FT-4c).
struct V061Tests {
    private func image(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return try #require(context.makeImage())
    }

    @Test func aPartIsCutOnWholePixels() throws {
        let full = try image(width: 200, height: 100)
        // Half points on a 1x display land on whole pixels.
        let part = try #require(ScreenCapture.crop(full, to: CGRect(x: 10.4, y: 5.6, width: 50.2, height: 20.4), scale: 1))
        #expect(part.width == 50)
        #expect(part.height == 20)
        let retina = try #require(ScreenCapture.crop(full, to: CGRect(x: 10, y: 5, width: 30, height: 20), scale: 2))
        #expect(retina.width == 60)
        #expect(retina.height == 40)
        // Outside the display it is clipped, never bigger than the display.
        let edge = try #require(ScreenCapture.crop(full, to: CGRect(x: 190, y: 0, width: 50, height: 10), scale: 1))
        #expect(edge.width == 10)
        #expect(ScreenCapture.crop(full, to: CGRect(x: 300, y: 0, width: 5, height: 5), scale: 1) == nil)
    }

    @MainActor @Test func trayAndScreenshotsKeepTheirColour() {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("V061Tray-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "V061Tray-\(UUID().uuidString)") ?? .standard
        let store = TrayStore(defaults: defaults, folder: folder)
        #expect(store.colour(ofFixed: "tray") == 2)
        #expect(store.colour(ofFixed: "screenshots") == 3)
        store.setColour(6, ofFixed: "screenshots")
        let reopened = TrayStore(defaults: defaults, folder: folder)
        #expect(reopened.colour(ofFixed: "screenshots") == 6)
        #expect(reopened.colour(ofFixed: "tray") == 2)
    }
}
