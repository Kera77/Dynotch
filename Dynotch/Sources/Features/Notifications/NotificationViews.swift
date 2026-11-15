import SwiftUI

struct AppIconView: View {
    let app: NotificationApp
    let size: CGFloat

    var body: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "bell.fill")
                .font(.system(size: size * 0.6))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
    }
}

/// The closed notch opened just a little: who wrote, in which app (spec E-3).
struct NotificationPeekView: View {
    let app: NotificationApp
    let content: NotificationContent
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 6) {
                AppIconView(app: app, size: 16)
                Text(content.sender)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if content.sender != app.name {
                    Text(app.name)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)
                        .layoutPriority(-1)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Notifications feature: what arrived since launch, newest first (spec E-4, E-5).
struct NotificationsFeatureView: View {
    @ObservedObject var service: NotificationService

    var body: some View {
        switch service.status {
        case .running:
            if service.recent.isEmpty {
                message(symbol: "bell", text: "Nincs új értesítés")
            } else {
                list
            }
        case .noAccess:
            prompt(
                text: "Az értesítések olvasásához Teljes lemezelérés kell.\nAdd hozzá a Dynotch-ot, majd indítsd újra.",
                button: "Rendszerbeállítások megnyitása",
                action: service.openFullDiskAccessSettings
            )
        case .unsupported:
            message(symbol: "exclamationmark.triangle", text: "Az értesítések nem olvashatók ezen a rendszeren.")
        case .disabled:
            message(symbol: "bell.slash", text: "Az értesítések ki vannak kapcsolva")
        }
    }

    private var list: some View {
        ScrollView(.vertical) {
            VStack(spacing: 6) {
                ForEach(service.recent) { notification in
                    NotificationRow(
                        app: service.catalog.app(for: notification.appIdentifier),
                        content: service.content(for: notification),
                        date: notification.date
                    )
                    .onTapGesture { service.catalog.open(notification.appIdentifier) }
                }
            }
            .padding(.vertical, 6)
        }
        .scrollIndicators(.never)
    }

    private func message(symbol: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 16))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(Color.white.opacity(0.55))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func prompt(text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(button, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NotificationRow: View {
    let app: NotificationApp
    let content: NotificationContent
    let date: Date

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AppIconView(app: app, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(content.sender)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(app.name) · \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                }
                if !content.detail.isEmpty {
                    Text(content.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.07)))
        .contentShape(Rectangle())
        .help("Megnyitás: \(app.name)")
    }
}
