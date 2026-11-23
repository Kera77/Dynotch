import SwiftUI

/// One source of notifications in the settings: on or off, and its own rules (spec E-15).
struct NotificationSourceRow: View {
    let app: NotificationApp
    @ObservedObject var service: NotificationService
    let isOn: Binding<Bool>

    @State private var isOpen = false
    @State private var name = ""

    /// Default, on or off.
    enum Choice: String, CaseIterable, Identifiable {
        case automatic
        case enabled
        case disabled

        var id: String { rawValue }

        init(_ value: Bool?) {
            switch value {
            case .some(true): self = .enabled
            case .some(false): self = .disabled
            case .none: self = .automatic
            }
        }

        var value: Bool? {
            switch self {
            case .automatic: nil
            case .enabled: true
            case .disabled: false
            }
        }
    }

    private var rule: NotificationRule { service.rule(for: app) }

    /// The site's address beside its name, unless the name is the address.
    private var siteDetail: String? {
        guard let site = app.site, WebNotificationSource.displayName(forSite: site) != site else { return nil }
        return site
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Toggle(isOn: isOn) {
                    SettingsRowLabel(title: app.name, detail: siteDetail) {
                        AppIconView(app: app, size: 18, monochrome: false)
                    }
                }
                Spacer()
                if !rule.isDefault {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Has its own rules")
                        .accessibilityLabel("Has its own rules")
                }
                Button {
                    withAnimation(Motion.quick) { isOpen.toggle() }
                } label: {
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Rules for \(app.name)")
            }
            if isOpen { options }
        }
        // Opened, it scrolls into view by itself (spec C-12).
        .revealWhenOpened(isOpen)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Name") {
                TextField(app.name, text: $name)
                    .focusOnClick()
                    .frame(width: 180)
                    .onSubmit(saveName)
                    .onAppear { name = rule.name ?? "" }
                    .onChange(of: name) { _, _ in saveName() }
            }
            picker("macOS banner", value: rule.hidesBanner, labels: ["Default", "Hide", "Show"]) { choice in
                var updated = rule
                updated.hidesBanner = choice.value
                service.setRule(updated, for: app)
            }
            if service.hidesBanner(for: app.identifier) {
                // Closing the banner takes it out of Notification Center too (spec E-13b).
                Text("Hidden banners leave Notification Center at once, so a message read elsewhere stays here. "
                    + "For chats, set this app's alert style to None in System Settings › Notifications and choose Show.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // The pop-up shows the name, or the message too (spec E-22b).
            Picker("Pop-up", selection: Binding(get: { rule.peekShowsMessage == true }, set: { shows in
                var updated = rule
                updated.peekShowsMessage = shows ? true : nil
                service.setRule(updated, for: app)
            })) {
                Text("Name only").tag(false)
                Text("With message").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            picker("Reply field", value: rule.showsReply, labels: ["Default (off)", "Show", "Hide"]) { choice in
                var updated = rule
                updated.showsReply = choice.value
                service.setRule(updated, for: app)
            }
            Toggle("Pop up during Focus", isOn: Binding(get: { rule.popsUpDuringFocus == true }, set: { allowed in
                var updated = rule
                updated.popsUpDuringFocus = allowed ? true : nil
                service.setRule(updated, for: app)
            }))
        }
        .font(.callout)
        .padding(.leading, 26)
        .disabled(!isOn.wrappedValue)
    }

    private func picker(
        _ title: String, value: Bool?, labels: [String], set: @escaping (Choice) -> Void
    ) -> some View {
        Picker(title, selection: Binding(get: { Choice(value) }, set: set)) {
            ForEach(Array(Choice.allCases.enumerated()), id: \.element) { index, choice in
                Text(labels[index]).tag(choice)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 320)
    }

    private func saveName() {
        var updated = rule
        updated.name = name
        service.setRule(updated, for: app)
    }
}
