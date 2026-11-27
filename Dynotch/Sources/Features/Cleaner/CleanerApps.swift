import SwiftUI

/// The installed apps (spec TT-4). A picked app's details slide in from the right as a second
/// column, or take the list's place when the Cleaner is narrow (spec TT-19).
struct CleanerAppsList: View {
    @Bindable var service: CleanerService

    @State private var width: CGFloat = 0
    /// Below this the details take the list's place (spec TT-19).
    static let twoColumnWidth: CGFloat = 480

    var body: some View {
        let twoColumns = width >= Self.twoColumnWidth
        HStack(alignment: .top, spacing: 10) {
            if service.app == nil || twoColumns {
                list(compact: service.app != nil)
                    .frame(width: service.app != nil ? Responsive.share(0.42, of: width, in: 200...320) : nil)
            }
            if let app = service.app {
                CleanerAppDetail(service: service, app: app, twoColumns: twoColumns)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.leading, twoColumns ? 10 : 0)
                    .overlay(alignment: .leading) {
                        if twoColumns { Rectangle().fill(Color.white.level(0.12)).frame(width: 0.75) }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .readWidth($width)
        .animation(Motion.spring, value: service.app)
    }

    /// The search, the order, and the apps; with the details open the rows leave out the size
    /// and Uninstall, shown in the details (spec TT-19).
    private func list(compact: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                TextField("Search apps", text: $service.appSearch)
                    .textFieldStyle(.plain)
                    .font(.notch(size: 13))
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.fill))
                if !compact {
                    CapsulePicker(items: CleanerService.AppSort.allCases, selection: $service.appSort, title: \.title)
                        .fixedSize()
                }
            }
            CleanerScroll(service: service, isEmpty: service.shownApps.isEmpty, empty: "No apps found") {
                ForEach(service.shownApps) { app in
                    CleanerAppRow(service: service, app: app, compact: compact)
                }
            }
        }
    }
}

/// One app: icon, name, when last used, size, red Uninstall (blue Quit while it runs) and the
/// arrow into its details (spec TT-17, TT-20).
struct CleanerAppRow: View {
    let service: CleanerService
    let app: CleanerApp
    let compact: Bool

    var body: some View {
        let isPicked = service.app == app
        HStack(spacing: 8) {
            AppIcon(url: app.url, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).font(.notch(size: 13, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                Text(Self.lastUsed(app.lastUsed, now: Date()))
                    .font(.notch(size: 12)).foregroundStyle(Color.white.level(0.45)).lineLimit(1)
            }
            Spacer(minLength: 4)
            if service.askingUninstall == app {
                confirmation
            } else if !compact {
                Text(CleanerService.format(app.size))
                    .font(.notch(size: 12)).monospacedDigit().foregroundStyle(Color.white.level(0.6))
                if service.isRunning(app) {
                    CleanerPill(title: "Quit", color: Theme.blue) { service.quit(app) }
                } else {
                    CleanerPill(title: "Uninstall", color: Theme.red) { service.askingUninstall = app }
                }
            }
            Image(systemName: "chevron.right")
                .font(.notch(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.level(0.45))
                .frame(width: 10)
        }
        .padding(.horizontal, 6)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(isPicked ? Theme.fill : .clear))
        .contentShape(Rectangle())
        .onTapGesture {
            service.askingUninstall = nil
            service.pick(isPicked ? nil : app)
        }
    }

    /// In place of the size and button: the question, Cancel and Uninstall (spec TT-17).
    private var confirmation: some View {
        HStack(spacing: 8) {
            Text("Uninstall with its files?")
                .font(.notch(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
            Button("Cancel") { service.askingUninstall = nil }
                .buttonStyle(.notch)
                .font(.notch(size: 12))
                .foregroundStyle(Color.white.level(0.7))
            CleanerPill(title: "Uninstall", color: Theme.red) {
                withAnimation(Motion.quick) { service.uninstallFromRow(app) }
            }
        }
    }

    /// "Opened 3 days ago", "Not opened for 4 months", "Never opened" (spec TT-20).
    static func lastUsed(_ date: Date?, now: Date) -> String {
        guard let date else { return "Never opened" }
        let days = now.timeIntervalSince(date) / 86_400
        if days < 1 { return "Opened today" }
        let relative = date.formatted(.relative(presentation: .numeric, unitsStyle: .wide))
        guard days >= 60 else { return "Opened " + relative }
        let months = Int(days / 30)
        return months >= 24 ? "Not opened for \(months / 12) years" : "Not opened for \(months) months"
    }
}

/// The picked app: icon, name, size, last used, Quit and Uninstall, and its files (spec TT-19).
struct CleanerAppDetail: View {
    @Bindable var service: CleanerService
    let app: CleanerApp
    let twoColumns: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if !twoColumns {
                    Button { service.pick(nil) } label: { Image(systemName: "chevron.left").font(.notch(size: 13)) }
                        .buttonStyle(.notch)
                        .foregroundStyle(Color.white.level(0.7))
                }
                AppIcon(url: app.url, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.notch(size: 14, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(CleanerService.format(app.size) + " · " + CleanerAppRow.lastUsed(app.lastUsed, now: Date()))
                        .font(.notch(size: 12)).monospacedDigit().foregroundStyle(Color.white.level(0.5)).lineLimit(1)
                }
                Spacer(minLength: 4)
                if service.isRunning(app) {
                    CleanerPill(title: "Quit", color: Theme.blue) { service.quit(app) }
                } else {
                    CleanerPill(title: "Uninstall", color: Theme.red) { service.asksToUninstall = true }
                }
                if twoColumns {
                    Button { service.pick(nil) } label: {
                        Image(systemName: "xmark").font(.notch(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.notch)
                    .foregroundStyle(Color.white.level(0.6))
                    .help("Close")
                }
            }
            Text("Removed with it").font(.notch(size: 12, weight: .semibold)).foregroundStyle(Color.white.level(0.5))
            CleanerScroll(service: service, isEmpty: service.appFiles.isEmpty, empty: "No other files found") {
                ForEach(service.appFiles) { item in
                    CleanerRow(service: service, urls: [item.url], title: item.url.lastPathComponent,
                               detail: CleanerCachesList.place(of: item.url), size: item.size)
                }
            }
        }
    }
}

/// A filled capsule button: red Uninstall, blue Quit (spec TT-17).
struct CleanerPill: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.notch)
            .font(.notch(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(color))
            .fixedSize()
    }
}
