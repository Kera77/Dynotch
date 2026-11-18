import SwiftUI

extension NotchIndicatorView {
    /// A symbol, a title and grey details on one line.
    func simpleLabel(_ title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
    }

    /// E.g. Claude finished a task: stays until swiped up.
    func noticeLabel(_ notice: StickyNotice) -> some View {
        HStack(spacing: 7) {
            if let symbol = notice.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.blue)
            } else {
                BrandGlyphView(glyph: .claude, size: 14)
            }
            Text(notice.title)
                .font(.system(size: 12, weight: .semibold))
                // A question waits for an answer (spec CQ-2).
                .foregroundStyle(notice.isQuestion ? Color(red: 1, green: 0.62, blue: 0.1) : .white)
                .lineLimit(1)
            Text([notice.detail, notice.date.formatted(date: .omitted, time: .shortened)].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
            Spacer(minLength: 8)
            SwipeUpArrow()
                .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .miter))
                .frame(width: 8, height: 6)
                .padding(.horizontal, 2.5)
                .accessibilityElement()
                .help("Swipe up with two fingers to dismiss")
                .accessibilityLabel("Swipe up with two fingers to dismiss")
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
