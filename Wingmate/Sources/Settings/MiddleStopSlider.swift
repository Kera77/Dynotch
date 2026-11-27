import AppKit
import SwiftUI

/// Where the middle colour stands (spec MB-17): the bar shows the gradient, the knob is the middle
/// colour, small marks under it at the thirds and the half pull the knob onto them.
struct MiddleStopSlider: View {
    @Binding var style: MenuBarTintStyle
    @Environment(\.colorScheme) private var colorScheme

    private let knob: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let track = max(proxy.size.width - knob, 1)
            let range = MenuBarTintStyle.middleStopRange
            ZStack(alignment: .topLeading) {
                LinearGradient(stops: style.stops(dark: colorScheme == .dark), startPoint: .leading, endPoint: .trailing)
                    .frame(height: 8)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(.secondary.opacity(0.4), lineWidth: 0.5))
                    .padding(.horizontal, knob / 2)
                    .offset(y: (knob - 8) / 2)
                ForEach(MenuBarTintStyle.middleMarks, id: \.self) { mark in
                    Capsule()
                        .fill(.secondary)
                        .frame(width: 1.5, height: 4)
                        .offset(x: knob / 2 + track * mark - 0.75, y: knob + 2)
                }
                Circle()
                    .fill(TintColor.color(style.colors(dark: colorScheme == .dark)[1]))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                    .frame(width: knob, height: knob)
                    .offset(x: track * style.middleLocation)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let raw = Double((drag.location.x - knob / 2) / track)
                let value = MenuBarTintStyle.snapped(min(max(raw, range.lowerBound), range.upperBound))
                guard value != style.middleLocation else { return }
                if MenuBarTintStyle.middleMarks.contains(value) {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                style.middleStop = value
            })
        }
        .frame(height: knob + 6)
        .accessibilityElement()
        .accessibilityLabel("Middle color position")
        .accessibilityValue("\(Int((style.middleLocation * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 0.05 : -0.05
            style.middleStop = MenuBarTintStyle.snapped(style.middleLocation + step)
        }
    }
}
