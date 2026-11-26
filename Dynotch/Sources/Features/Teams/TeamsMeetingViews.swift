import AppKit
import SwiftUI

extension IndicatorLayout {
    /// The microphone and "12:34" (or "1:02:03") beside the notch (spec MT-6).
    static func teamsWidth(since: Date, now: Date = Date()) -> CGFloat {
        let sample = now.timeIntervalSince(since) >= 3600 ? "0:00:00" : "00:00"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        return 4 + 14 + 4 + ceil((sample as NSString).size(withAttributes: [.font: font]).width) + 6
    }
}

extension NotchIndicatorView {
    /// The Tools' or the Teams meeting's capsule (spec TM-3, MT-6).
    @ViewBuilder
    func controlsCapsule(_ item: IndicatorItem, now: Date) -> some View {
        switch item {
        case .tools(let glance): toolsCapsule(glance, now: now)
        case .teams(let meeting, let since): TeamsMeetingSlot(meeting: meeting, since: since, now: now)
        default: EmptyView()
        }
    }

    /// Their controls under the notch (spec TM-19, MT-6).
    @ViewBuilder
    func controlsLabel(_ item: IndicatorItem, now: Date) -> some View {
        switch item {
        case .tools(let glance): toolsLabel(glance, now: now)
        case .teams(let meeting, _): TeamsMeetingLabel(meeting: meeting, teams: .shared)
        default: EmptyView()
        }
    }
}

/// The meeting beside the notch: white microphone live, red slashed muted (spec MT-6).
struct TeamsMeetingSlot: View {
    let meeting: TeamsMeeting
    let since: Date
    let now: Date

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: meeting.isMuted == true ? "mic.slash.fill" : "mic.fill")
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(meeting.isMuted == true ? Theme.red : .white)
                .frame(width: 14)
            Text(ClockText.text(max(now.timeIntervalSince(since), 0), tenths: false))
                .font(.notch(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(meeting.isMuted == true ? "Teams meeting, muted" : "Teams meeting")
    }
}

/// The meeting's name and its toolbar under the notch (spec MT-6).
struct TeamsMeetingLabel: View {
    let meeting: TeamsMeeting
    var teams: TeamsService

    var body: some View {
        HStack(spacing: 7) {
            Text(meeting.title)
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            ForEach(TeamsControl.allCases.filter { meeting.controls.contains($0) }, id: \.self) { control in
                button(control)
            }
            OpenModuleButton(help: "Open Teams") { teams.openInBrowser(chat: nil) }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(height: IndicatorLayout.labelHeight - 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func button(_ control: TeamsControl) -> some View {
        if control == .leave, teams.confirmsLeave {
            Button("Leave?") { teams.perform(.leave) }
                .buttonStyle(.notch)
                .font(.notch(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: IndicatorLayout.toolsControlSize)
                .background(Capsule().fill(Theme.red))
        } else {
            Button { teams.perform(control) } label: {
                Image(systemName: symbol(control))
                    .font(.notch(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: IndicatorLayout.toolsControlSize, height: IndicatorLayout.toolsControlSize)
                    .background(Circle().fill(fill(control)))
                    .contentShape(Circle())
            }
            .buttonStyle(.notch)
            .help(control.help)
            .accessibilityLabel(control.help)
        }
    }

    private func symbol(_ control: TeamsControl) -> String {
        switch control {
        case .mic: meeting.isMuted == true ? "mic.slash.fill" : "mic.fill"
        case .camera: meeting.isCameraOn == true ? "video.fill" : "video.slash.fill"
        case .hand: "hand.raised.fill"
        case .share: "rectangle.on.rectangle"
        case .leave: "phone.down.fill"
        }
    }

    private func fill(_ control: TeamsControl) -> Color {
        switch control {
        case .mic where meeting.isMuted == true: Theme.red.opacity(0.8)
        case .hand where meeting.isHandRaised: Color.yellow.opacity(0.7)
        case .leave: Theme.red
        default: Color.white.level(0.16)
        }
    }
}
