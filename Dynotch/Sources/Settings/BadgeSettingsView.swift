import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Which apps show their unread count beside the notch, their icons and order (spec B-1, B-3).
struct BadgeSettingsView: View {
    @ObservedObject var service: BadgeService

    @State private var installed: [InstalledApp] = []
    @State private var search = ""

    private func matches(_ name: String) -> Bool {
        search.isEmpty || name.localizedCaseInsensitiveContains(search)
    }

    private var candidates: [InstalledApp] {
        let chosen = Set(service.apps.map(\.bundleID))
        return installed.filter {
            !chosen.contains($0.bundleID) && matches($0.name)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !service.isTrusted {
                Label("Dynotch needs Accessibility access to read the badges of the Dock.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            SettingsSearchField(text: $search, prompt: "Search apps")
            List {
                Section("Next to the notch") {
                    if service.apps.isEmpty {
                        Text("No apps yet. Add one from the list below.")
                            .foregroundStyle(.secondary)
                    }
                    // Reordering works on the whole list, so it is off while searching.
                    if search.isEmpty {
                        ForEach(service.apps) { app in
                            BadgeAppRow(app: app, service: service)
                        }
                        .onMove { service.move(from: $0, to: $1) }
                    } else {
                        ForEach(service.apps.filter { matches($0.name) }) { app in
                            BadgeAppRow(app: app, service: service)
                        }
                    }
                }
                Section("Add an app") {
                    ForEach(candidates) { app in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                .resizable()
                                .frame(width: 18, height: 18)
                            Text(app.name)
                            Spacer()
                            Button("Add") { service.add(app) }
                                .controlSize(.small)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Text("An app appears left of the notch while its Dock icon has a badge; the icon pulses for 5 minutes "
                + "after a new notification. Click it to open the app. Drag to reorder, here or at the notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .task {
            installed = await Task.detached { InstalledApps.scan() }.value
        }
    }
}

private struct BadgeAppRow: View {
    let app: BadgeApp
    @ObservedObject var service: BadgeService

    var body: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(get: { app.isEnabled }, set: { service.setEnabled(app.bundleID, $0) })) {
                HStack(spacing: 6) {
                    BadgeIconView(icon: .app, bundleID: app.bundleID, size: 18, tint: .primary, monochrome: false)
                    Text(app.name)
                }
            }
            // Hidden from the notch for a while: how long, and Show brings it back (spec B-11).
            if let hide = service.hidden[app.bundleID] {
                Text(hide.description(now: Date()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button("Show") { service.unhide(app.bundleID) }
                    .controlSize(.small)
            }
            Spacer()
            Menu {
                Button("App icon") { service.setIcon(app.bundleID, .app) }
                Divider()
                ForEach(BadgePreset.all) { preset in
                    Button {
                        service.setIcon(app.bundleID, .symbol(preset.symbol))
                    } label: {
                        Label(preset.title, systemImage: preset.menuSymbol)
                    }
                }
                Divider()
                Button("Choose image…", action: chooseImage)
            } label: {
                BadgeIconView(icon: app.icon, bundleID: app.bundleID, size: 16, tint: .primary, monochrome: false)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Icon shown next to the notch")
            .accessibilityLabel("Icon shown next to the notch")
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

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose an icon for \(app.name)"
        NSApp.activate()
        if panel.runModal() == .OK, let url = panel.url {
            service.importIcon(for: app.bundleID, from: url)
        }
    }
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
