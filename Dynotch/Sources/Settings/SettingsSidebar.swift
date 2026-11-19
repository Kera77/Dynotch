import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case features
    case calendar
    case notifications
    case badges
    case clipboard
    case tray
    case focus
    case switcher
    case screenshots
    case menuBar
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .features: "Modules"
        case .calendar: "Calendar"
        case .notifications: "Notifications"
        case .badges: "App badges"
        case .clipboard: "Clipboard"
        case .tray: "Tray"
        case .focus: "Focus"
        case .switcher: "Switcher"
        case .screenshots: "Screenshots"
        case .menuBar: "Menu bar"
        case .permissions: "Permissions"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .features: "square.grid.2x2"
        case .calendar: "calendar"
        case .notifications: "bell"
        case .badges: "app.badge"
        case .clipboard: "doc.on.clipboard"
        case .tray: "tray"
        case .focus: "cursorarrow.rays"
        case .switcher: "rectangle.stack"
        case .screenshots: "camera.viewfinder"
        case .menuBar: "menubar.rectangle"
        case .permissions: "lock.shield"
        case .about: "info.circle"
        }
    }

    /// Words the search finds the tab by (spec C-9).
    var keywords: String {
        switch self {
        case .general:
            "launch login hud volume brightness calls phone haptic ai claude chatgpt usage devices bluetooth drive close delay "
                + "tasks reminders counter"
        case .appearance: "design glass liquid pill notch rounded full screen preview wings hover strip smart opening"
        case .features: "modules order shortcuts menu bar pin"
        case .calendar: "meetings countdown lead time"
        case .notifications: "banner beeper token sources websites reply unread"
        case .badges: "dock badge unread apps icons"
        case .clipboard: "clipboard paste saved copy"
        case .tray: "tray files folder airdrop retention drop"
        case .focus: "focus follows mouse autoraise"
        case .switcher: "switcher alt tab windows apps swipe trackpad thumbnails"
        case .screenshots: "screenshot capture snip crop record video editor annotate scrolling"
        case .menuBar: "menu bar space spacer divider line gap"
        case .permissions: "privacy access full disk accessibility calendar reminders contacts bluetooth"
        case .about: "version update diagnostics quit"
        }
    }

    func matches(_ search: String) -> Bool {
        search.isEmpty || title.localizedCaseInsensitiveContains(search) || keywords.localizedCaseInsensitiveContains(search)
    }
}

/// The settings' sections in a list on the left, with a search (spec C-9).
struct SettingsSidebar: View {
    @Binding var selected: SettingsTab
    @Binding var search: String
    var warnings: Set<SettingsTab> = []

    static let width: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSearchField(text: $search, prompt: "Search")
            ScrollView(.vertical) {
                VStack(spacing: 2) {
                    ForEach(SettingsTab.allCases.filter { $0.matches(search) }) { tab in
                        Button {
                            selected = tab
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: tab.symbolName)
                                    .font(.system(size: 13, weight: .medium))
                                    .frame(width: 18)
                                Text(tab.title)
                                    .font(.system(size: 13))
                                Spacer(minLength: 0)
                                if warnings.contains(tab) {
                                    Circle().fill(Color.orange).frame(width: 7, height: 7)
                                        .help("A module in use is missing a permission")
                                }
                            }
                            .foregroundStyle(tab == selected ? Color.white : Color.primary)
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(tab == selected ? Color.accentColor : .clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(10)
        .frame(width: Self.width)
        .onChange(of: search) { _, text in
            // The first match opens, so typing a word goes straight to it.
            if let first = SettingsTab.allCases.first(where: { $0.matches(text) }), !selected.matches(text) { selected = first }
        }
    }
}

/// Settings › Permissions: every permission, granted or not, with a way to grant it (spec C-8).
struct PermissionsSettingsView: View {
    @ObservedObject var notifications: NotificationService
    @ObservedObject var settings: AppSettings
    @State private var refresh = 0

    var body: some View {
        Form {
            Section {
                ForEach(Permission.allCases) { permission in
                    HStack(spacing: 10) {
                        Image(systemName: permission.symbol)
                            .frame(width: 20)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(permission.title)
                            Text(permission.purpose).font(.caption).foregroundStyle(.secondary)
                            if isMissingInUse(permission) {
                                Label("A module you use needs it", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        status(permission)
                    }
                }
            } footer: {
                Text("Dynotch asks for each when a feature first needs it; here they are in one place.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .id(refresh)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in refresh += 1 }
    }

    private func isMissingInUse(_ permission: Permission) -> Bool {
        permission.isNeeded(by: settings) && permission.isGranted(notificationsReadable: notifications.status == .running) == false
    }

    @ViewBuilder private func status(_ permission: Permission) -> some View {
        switch permission.isGranted(notificationsReadable: notifications.status == .running) {
        case .some(true):
            Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green).labelStyle(.titleAndIcon)
        default:
            Button("Grant…") {
                let readable = notifications.status == .running
                Task { await permission.grant(notificationsReadable: readable) }
            }
        }
    }
}
