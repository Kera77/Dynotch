import SwiftUI

extension NotchIndicatorView {
    /// A symbol, a title and grey details on one line.
    func simpleLabel(_ title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(detail)
                .font(.notch(size: 11))
                .foregroundStyle(Color.white.level(0.6))
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
                    .font(.notch(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.blue)
            } else if let iconApp = notice.iconApp, let icon = BadgeIconCache.appIcon(bundleID: iconApp) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                BrandGlyphView(glyph: .claude, size: 14)
            }
            Text(notice.title)
                .font(.notch(size: 12, weight: .semibold))
                // A question waits for an answer (spec CQ-2).
                .foregroundStyle(notice.isQuestion ? Color(red: 1, green: 0.62, blue: 0.1).apple(.orange) : .white)
                .lineLimit(1)
            Text([notice.detail, notice.date.formatted(date: .omitted, time: .shortened)].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.notch(size: 11))
                .monospacedDigit()
                .foregroundStyle(Color.white.level(0.6))
                .lineLimit(1)
            Spacer(minLength: 8)
            // The small X like everywhere else; a swipe up still works too (spec CN-5b).
            Button(action: dismissNotice) {
                Image(systemName: "xmark.circle.fill")
                    .font(.notch(size: 13))
                    .foregroundStyle(Color.white.level(0.55))
                    .contentShape(Circle())
            }
            .buttonStyle(.notch)
            .help("Dismiss (or swipe up with two fingers)")
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A click brings forward the app the work ran in (spec CN-6).
        .contentShape(Rectangle())
        .onTapGesture(perform: openNotice)
    }

    /// A low device: its name, level, history and estimate (spec BT-3, BT-6).
    func batteryLabel(_ device: BatteryDevice, item: IndicatorItem) -> some View {
        HStack(spacing: 7) {
            Text(device.name)
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("battery at \(device.level)%")
                .font(.notch(size: 11))
                .foregroundStyle(BatteryFeatureView.red)
            let samples = batterySamples(device.id)
            if samples.count > 1 {
                BatterySparkline(samples: samples)
                    .frame(width: 64, height: 16)
            }
            if let left = BatteryHistory.estimate(from: samples) {
                Text(BatteryHistory.estimateText(left))
                    .font(.notch(size: 10))
                    .foregroundStyle(Color.white.level(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            dismissButton(for: item, help: "Hide until it has been recharged")
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
    }

    /// Hovered: the player drops down; announced: the new track's name (spec MU-2, MU-4).
    @ViewBuilder
    func musicLabel(_ glance: MusicIndicator.Glance) -> some View {
        if let music, showsMusicPlayer {
            MusicDropdown(service: music)
        } else {
            // A new track: its cover, title and artist (spec MU-4).
            HStack(spacing: 10) {
                MusicArtwork(image: glance.artwork, cornerRadius: AppleStyle.corner(5)).frame(width: 30, height: 30)
                // Title, then every artist; a long line runs through, then it closes (spec MU-4b).
                MusicMarquee(title: glance.title, artist: glance.artist, tint: glance.tint.color) { seconds in
                    music?.endAnnouncement(after: seconds)
                }
                .id(glance.trackID)
            }
            .padding(.horizontal, 12)
            .frame(height: IndicatorLayout.musicAnnounceHeight - 4)
        }
    }

    /// The stats' warnings, Open and the X that hides them until they clear (spec SY-10).
    func statsLabel(_ item: IndicatorItem) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill").font(.notch(size: 11, weight: .semibold)).foregroundStyle(Theme.red)
            Text((stats?.indicator.warnings ?? []).joined(separator: " · "))
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Open", action: openStats)
                .buttonStyle(.notch)
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .frame(height: 18)
                .background(Capsule().fill(Color.white.level(0.16)))
            dismissButton(for: item, help: "Hide until it clears")
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
    }
}

/// A red dot and the time recorded so far (spec SH-5). Hovered, the dot grows into a red
/// circle with a white square that stops the recording, like the iPhone's (spec SH-5b).
struct RecordingSlot: View {
    let since: Date
    let now: Date
    var isHovered = false
    var stop: () -> Void = {}

    var body: some View {
        let seconds = max(Int(now.timeIntervalSince(since)), 0)
        HStack(spacing: 4) {
            Button(action: stop) {
                ZStack {
                    Circle().fill(Theme.red)
                        .frame(width: isHovered ? 18 : 7, height: isHovered ? 18 : 7)
                    RoundedRectangle(cornerRadius: AppleStyle.corner(1.5), style: .continuous)
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .scaleEffect(isHovered ? 1 : 0.01)
                        .opacity(isHovered ? 1 : 0)
                }
                .frame(width: 18, height: 18)
                .contentShape(Circle())
            }
            .buttonStyle(.notch)
            .help("Stop recording")
            .accessibilityLabel("Stop recording")
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(.notch(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .animation(AppleStyle.spring(response: 0.32, dampingFraction: 0.62), value: isHovered)
        .frame(width: IndicatorLayout.slotWidth, height: IndicatorLayout.capsuleHeight)
    }
}
