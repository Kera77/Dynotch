import AppKit

extension NotchController {
    /// The current module's page as a picture, at 1× to keep it small (spec M-20).
    func snapshotPage(in hosting: NSView) -> NSImage? {
        guard model.isExpanded, !model.isShowingNotifications, let window = hosting.window else { return nil }
        let geometry = model.geometry
        let panel = hosting.convert(window.convertFromScreen(geometry.rect(for: model.openSize)), from: nil)
        // The page: the open panel below its top row (the hosting view is flipped).
        var rect = panel.integral
        let top = geometry.menuBarHeight
        if hosting.isFlipped { rect.origin.y += top }
        rect.size.height -= top
        guard rect.width >= 1, rect.height >= 1,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(rect.width), pixelsHigh: Int(rect.height),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
              )
        else { return nil }
        rep.size = rect.size
        hosting.cacheDisplay(in: rect, to: rep)
        let image = NSImage(size: rect.size)
        image.addRepresentation(rep)
        return image
    }
}
