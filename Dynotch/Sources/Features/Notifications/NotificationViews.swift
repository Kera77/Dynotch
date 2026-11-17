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

/// The closed notch opened just a little: who wrote, in which app, and how many are new (spec E-3).
struct NotificationPeekView: View {
    let app: NotificationApp
    let content: NotificationContent
    let notchHeight: CGFloat
    var newCount = 1

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
                if newCount > 1 {
                    Text("+\(newCount - 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                        .help("\(newCount) new notifications")
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
    /// Looking at the list counts as having seen the new notifications.
    var isActive = false
    /// Which notifications the tab lists (spec UM-8).
    var include: (AppNotification) -> Bool = { _ in true }
    /// Cards above the notifications, in the same list: the unread Beeper chats (spec UM-9).
    var leading: AnyView?

    /// The group whose messages and reply field are open (spec E-5b).
    @State private var expanded: String?

    var body: some View {
        Group { content }
            // A badge click builds the list anew, with only that app's notifications (spec B-6).
            .id(service.focus?.token)
            .onChange(of: isActive) { _, active in
                if active { service.markSeen() }
            }
    }

    @ViewBuilder private var content: some View {
        switch service.status {
        case .running:
            if service.recent.isEmpty, service.focus == nil, leading == nil {
                message(symbol: "bell", text: "No new notifications")
            } else {
                list
            }
        case .noAccess:
            prompt(
                text: "Reading notifications needs Full Disk Access.\nAdd Dynotch, then restart it.",
                button: "Open System Settings",
                action: service.openFullDiskAccessSettings
            )
        case .unsupported:
            message(symbol: "exclamationmark.triangle", text: "Notifications can't be read on this system.")
        case .disabled:
            message(symbol: "bell.slash", text: "Notifications are turned off")
        }
    }

    /// What is listed: everything, or one app's unopened notifications (spec B-6).
    private var shown: [AppNotification] {
        guard let focus = service.focus else { return service.recent.filter(include) }
        // Only what is still listed, and only that app's.
        let ids = Set(focus.notifications.map(\.id))
        return service.recent.filter { ids.contains($0.id) && include($0) }
    }

    private var list: some View {
        let groups = NotificationGroup.groups(of: shown)
        return VStack(spacing: 4) {
            listHeader
            if groups.isEmpty, let focus = service.focus {
                message(symbol: "bell", text: "No unopened notifications from \(focus.appName)")
            }
            ScrollView(.vertical) {
                VStack(spacing: 6) {
                    if service.focus == nil, let leading { leading }
                    ForEach(groups) { group in
                        // A single group is open right away.
                        NotificationGroupRow(service: service, group: group, isExpanded: expanded == group.id || groups.count == 1) {
                            withAnimation(Motion.quick) { expanded = expanded == group.id ? nil : group.id }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.never)
        }
    }

    private var listHeader: some View {
        HStack(spacing: 8) {
            if let focus = service.focus {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { service.clearFocus() }
                } label: {
                    Label("All", systemImage: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
                Text("\(focus.appName) · \(focus.notifications.count) unopened")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Button("Open \(focus.appName)") { service.openApp(bundleID: focus.bundleID) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
            } else {
                Text("\(service.recent.count) notification\(service.recent.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { service.clearAll() }
                } label: {
                    Label("Clear all", systemImage: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
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

/// Small round icon button (close, clear all).
struct NotificationHeaderButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
