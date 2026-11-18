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
            // The small X like everywhere else; a swipe up still works too (spec CN-5b).
            Button(action: dismissNotice) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Dismiss (or swipe up with two fingers)")
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A low device: its name, level, history and estimate (spec BT-3, BT-6).
    func batteryLabel(_ device: BatteryDevice, item: IndicatorItem) -> some View {
        HStack(spacing: 7) {
            Text(device.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("battery at \(device.level)%")
                .font(.system(size: 11))
                .foregroundStyle(BatteryFeatureView.red)
            let samples = batterySamples(device.id)
            if samples.count > 1 {
                BatterySparkline(samples: samples)
                    .frame(width: 64, height: 16)
            }
            if let left = BatteryHistory.estimate(from: samples) {
                Text(BatteryHistory.estimateText(left))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.55))
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
                MusicArtwork(image: glance.artwork, cornerRadius: 5).frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(glance.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(glance.artist).font(.system(size: 11)).foregroundStyle(glance.tint.color).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: IndicatorLayout.musicAnnounceHeight - 4)
        }
    }

    /// The stats' warnings, Open and the X that hides them until they clear (spec SY-10).
    func statsLabel(_ item: IndicatorItem) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.red)
            Text((stats?.indicator.warnings ?? []).joined(separator: " · "))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Open", action: openStats)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .frame(height: 18)
                .background(Capsule().fill(Color.white.opacity(0.16)))
            dismissButton(for: item, help: "Hide until it clears")
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
    }

    /// A recording is running: Stop ends it (spec SH-5).
    var recordingLabel: some View {
        HStack(spacing: 7) {
            Circle().fill(Theme.red).frame(width: 8, height: 8)
            Text("Recording the screen").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            Spacer(minLength: 8)
            Button("Stop", action: stopRecording)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 20)
                .background(Capsule().fill(Theme.red))
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
    }
}

/// A red dot and the time recorded so far (spec SH-5).
struct RecordingSlot: View {
    let since: Date
    let now: Date

    var body: some View {
        let seconds = max(Int(now.timeIntervalSince(since)), 0)
        HStack(spacing: 4) {
            Circle().fill(Theme.red).frame(width: 7, height: 7)
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: IndicatorLayout.slotWidth, height: IndicatorLayout.capsuleHeight)
    }
}
