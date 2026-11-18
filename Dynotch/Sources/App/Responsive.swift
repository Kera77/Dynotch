import SwiftUI

/// Helpers for modules that follow their resized size (spec RS-5).
enum Responsive {
    /// A part of the module's width (e.g. a list beside the content) within sensible bounds.
    nonisolated static func share(_ fraction: CGFloat, of width: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
        min(max((width * fraction).rounded(), range.lowerBound), range.upperBound)
    }
}

extension View {
    /// Keeps `width` equal to the view's width, without changing its layout.
    func readWidth(_ width: Binding<CGFloat>) -> some View {
        background(GeometryReader { proxy in
            Color.clear
                .onAppear { width.wrappedValue = proxy.size.width }
                .onChange(of: proxy.size.width) { _, new in width.wrappedValue = new }
        })
    }
}
