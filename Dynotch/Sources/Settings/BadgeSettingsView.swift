import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Which apps show their unread count beside the notch, their icons and order (spec B-1, B-3).
struct BadgeSettingsView: View {
    var service: BadgeService

    @State private var installed: [InstalledApp] = []
    /// The row being dragged to a new place (spec SD-4).
    @State private var dragged: BadgeApp.ID?
    /// The icon chosen for an app before adding it (spec B-13).
    @State private var pendingIcons: [String: BadgeIcon] = [:]

    private var candidates: [InstalledApp] {
        let chosen = Set(service.apps.map(\.bundleID))
        return installed.filter { !chosen.contains($0.bundleID) }
    }

    var body: some View {
        Form {
            AccessSection(permissions: [.accessibility], footer: "Accessibility reads the badges of the Dock.")
            Section {
                if service.apps.isEmpty {
                    Text("No apps yet. Add one from the list below.")
                        .foregroundStyle(.secondary)
                }
                let ids = service.apps.map(\.id)
                ForEach(service.apps) { app in
                    BadgeAppRow(app: app, service: service)
                        .reorderable(app.id, in: ids, dragged: $dragged, id: app.bundleID) { service.move(from: $0, to: $1) }
                }
            } header: {
                Text("Next to the notch")
            } footer: {
                Text("An app appears left of the notch while its Dock icon has a badge; the icon pulses for 5 minutes "
                    + "after a new notification. Click it to open the app. Drag to reorder, here or at the notch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Closed until opened, with its own search (spec SD-2).
            CollapsibleListSection(title: "Add an app", count: candidates.count, prompt: "Search apps") { search in
                ForEach(candidates.filter { settingsSearchMatches(search, $0.name) }) { app in
                    candidateRow(app)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            installed = await Task.detached { InstalledApps.scan() }.value
        }
    }

    /// An app to add, with the icon it gets (spec B-13).
    private func candidateRow(_ app: InstalledApp) -> some View {
        let icon = pendingIcons[app.bundleID] ?? BadgePreset.suggestedIcon(bundleID: app.bundleID, name: app.name)
        return HStack(spacing: 8) {
            SettingsRowLabel(title: app.name) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable()
            }
            Spacer()
            BadgeIconPicker(
                icon: icon, bundleID: app.bundleID,
                choose: { pendingIcons[app.bundleID] = $0 },
                chooseImage: {
                    chooseBadgeImage(name: app.name) { url in
                        service.add(app, icon: icon)
                        service.importIcon(for: app.bundleID, from: url)
                    }
                }
            )
            Button("Add") {
                service.add(app, icon: icon)
                pendingIcons[app.bundleID] = nil
            }
            .controlSize(.small)
        }
    }
}

private struct BadgeAppRow: View {
    let app: BadgeApp
    var service: BadgeService

    var body: some View {
        HStack(spacing: 8) {
            DragHandle()
            Toggle(isOn: Binding(get: { app.isEnabled }, set: { service.setEnabled(app.bundleID, $0) })) {
                // Hidden from the notch for a while: how long, beside the name (spec B-11, SD-10).
                SettingsRowLabel(title: app.name, detail: service.hidden[app.bundleID]?.description(now: Date())) {
                    BadgeIconView(icon: .app, bundleID: app.bundleID, size: 18, tint: .primary, monochrome: false)
                }
            }
            // The eye brings a hidden badge back; its place stays when there is none (spec SD-10).
            TrailingSlot {
                if service.hidden[app.bundleID] != nil {
                    Button {
                        service.unhide(app.bundleID)
                    } label: {
                        Image(systemName: "eye")
                    }
                    .buttonStyle(.borderless)
                    .help("Show next to the notch again")
                    .accessibilityLabel("Show next to the notch again")
                }
            }
            BadgeIconPicker(
                icon: app.icon, bundleID: app.bundleID,
                choose: { service.setIcon(app.bundleID, $0) },
                chooseImage: { chooseBadgeImage(name: app.name) { service.importIcon(for: app.bundleID, from: $0) } }
            )
            Button {
                service.remove(app.bundleID)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove")
            .accessibilityLabel("Remove")
        }
    }
}

/// Asks for an image file to use as a badge icon (spec B-3).
@MainActor
func chooseBadgeImage(name: String, then use: (URL) -> Void) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = false
    panel.message = "Choose an icon for \(name)"
    NSApp.activate()
    if panel.runModal() == .OK, let url = panel.url { use(url) }
}

/// The search field above the app lists in the settings (spec C-5).
struct SettingsSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .focusOnClick()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear")
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.08)))
    }
}

/// A click focuses the text field even where the form around it would keep the click for itself
/// (spec C-5b).
private struct FocusOnClick: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .simultaneousGesture(TapGesture().onEnded { isFocused = true })
    }
}

extension View {
    func focusOnClick() -> some View {
        modifier(FocusOnClick())
    }
}
