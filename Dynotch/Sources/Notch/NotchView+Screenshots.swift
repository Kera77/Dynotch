import SwiftUI

/// The screenshot tool under the closed notch (spec SH-1, SH-6): the modes while the shortcut is
/// held, then the shot that was just made.
extension NotchView {
    var showsScreenshotPeek: Bool {
        screenshots.choosing != nil || (screenshots.peek != nil && !model.isScreenShared)
    }

    var screenshotPeekSize: CGSize {
        if screenshots.choosing != nil {
            let count = CGFloat(max(screenshots.settings.modes.count, 1))
            return CGSize(width: max(geometry.notchSize.width + 40, count * 84 + 24), height: geometry.notchSize.height + 74)
        }
        return CGSize(width: max(geometry.peekSize.width, 340), height: geometry.notchSize.height + 64)
    }

    @ViewBuilder var screenshotPeek: some View {
        if let choosing = screenshots.choosing {
            ScreenshotModeChooser(modes: screenshots.settings.modes, chosen: choosing, notchHeight: geometry.notchSize.height)
        } else if let shot = screenshots.peek {
            ScreenshotPeekView(shot: shot, notchHeight: geometry.notchSize.height)
        }
    }
}

/// The modes side by side; the chosen one is lit (spec SH-1).
struct ScreenshotModeChooser: View {
    let modes: [CaptureMode]
    let chosen: CaptureMode
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 6) {
                ForEach(modes) { mode in
                    VStack(spacing: 5) {
                        Image(systemName: mode.symbol).font(.system(size: 18, weight: .medium))
                        Text(mode.title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(mode == chosen ? Color.black : Color.white.opacity(0.75))
                    .frame(width: 78, height: 56)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(mode == chosen ? Color.white : Theme.fill))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

/// The shot just made: its picture, "Copied · Saved", and the hint to open the editor (spec SH-6).
struct ScreenshotPeekView: View {
    let shot: ScreenshotShot
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 12) {
                Group {
                    if let thumbnail = shot.thumbnail {
                        Image(nsImage: thumbnail).resizable().scaledToFill()
                    } else {
                        Color.white.opacity(0.1)
                    }
                }
                .frame(width: 64, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.2)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(shot.isVideo ? "Recording saved" : "Screenshot")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(shot.isVideo ? "Copied · in Screenshots" : "Copied · Saved · open the notch to edit")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.green)
            }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
        }
    }
}
