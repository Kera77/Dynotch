import SwiftUI

/// Usage like Claude's own usage screen (spec CL-3).
struct ClaudeUsageView: View {
    @ObservedObject var service: ClaudeUsageService
    let isActive: Bool

    static let blue = Color(red: 0.04, green: 0.52, blue: 1)

    var body: some View {
        Group {
            switch service.state {
            case .loaded:
                list
            case .idle, .loading:
                message("Fogyasztás betöltése…", showsProgress: true)
            case .noCredentials:
                message("Nem található Claude Code-bejelentkezés, vagy a kulcskarika-hozzáférést elutasítottad.\n"
                    + "Jelentkezz be a Claude Code-ba, majd frissíts.", showsRetry: true)
            case .signedOut:
                message("A Claude Code tokenje lejárt. Használd egyszer a Claude Code-ot (frissíti), majd frissíts.",
                        showsRetry: true)
            case .failed(let error):
                message("A fogyasztás nem kérhető le: \(error)", showsRetry: true)
            }
        }
        .onAppear { if isActive { service.refreshIfStale() } }
        .onChange(of: isActive) { _, active in
            if active { service.refreshIfStale() }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("HASZNÁLAT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45))
                Spacer()
                if let updated = service.lastUpdated {
                    Text("Frissítve \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                Button(action: service.refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Frissítés")
            }
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(service.limits) { UsageRow(limit: $0) }
                }
            }
            .scrollIndicators(.never)
        }
    }

    private func message(_ text: String, showsProgress: Bool = false, showsRetry: Bool = false) -> some View {
        VStack(spacing: 10) {
            if showsProgress { ProgressView().controlSize(.small) }
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if showsRetry {
                Button("Frissítés", action: service.refresh)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct UsageRow: View {
    let limit: UsageLimit

    private var color: Color {
        switch limit.level {
        case .normal: ClaudeUsageView.blue
        case .high: Color(red: 1, green: 0.62, blue: 0.1)
        case .critical: Color(red: 1, green: 0.3, blue: 0.3)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(limit.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(limit.utilization.rounded()))%")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(limit.level == .normal ? Color.white : color)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * limit.utilization / 100)
                }
            }
            .frame(height: 6)
            if let reset = limit.resetsAt {
                Text("Visszaáll: \(UsageAlerts.resetText(reset, now: Date()))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
    }
}

/// Claude usage in the notch.
struct ClaudeUsageFeatureView: View {
    @ObservedObject var service: ClaudeUsageService
    let isActive: Bool

    var body: some View {
        ClaudeUsageView(service: service, isActive: isActive)
            .padding(.top, 6)
    }
}

/// Content of the Claude usage menu bar panel.
struct ClaudeUsageMenuBarView: View {
    @ObservedObject var service: ClaudeUsageService
    @ObservedObject var state: MenuBarPanelState

    var body: some View {
        ClaudeUsageView(service: service, isActive: true)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .popoverChrome(arrowX: state.arrowX)
    }
}

/// Small ring for the menu bar icon (spec CL-6).
enum UsageRing {
    static func image(utilization: Double) -> NSImage {
        let fraction = min(max(utilization / 100, 0), 1)
        let level = UsageLevel(utilization: utilization)
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let ring = rect.insetBy(dx: 2.5, dy: 2.5)
            let track = NSBezierPath(ovalIn: ring)
            track.lineWidth = 2.5
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()
            track.stroke()

            let progressColor: NSColor = switch level {
            case .normal: .labelColor
            case .high: .systemOrange
            case .critical: .systemRed
            }
            let arc = NSBezierPath()
            let center = NSPoint(x: ring.midX, y: ring.midY)
            arc.appendArc(withCenter: center, radius: ring.width / 2, startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
            arc.lineWidth = 2.5
            arc.lineCapStyle = .round
            progressColor.setStroke()
            arc.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }
}
