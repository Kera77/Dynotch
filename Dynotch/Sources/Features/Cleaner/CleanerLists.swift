import SwiftUI

/// Leftovers of apps no longer on the Mac, per app (spec TT-2).
struct CleanerLeftoversList: View {
    @Bindable var service: CleanerService
    @State private var open: Set<String> = []

    var body: some View {
        CleanerScroll(service: service, isEmpty: service.result.leftovers.isEmpty,
                      empty: "No leftovers of removed apps") {
            ForEach(service.result.leftovers) { group in
                CleanerRow(
                    service: service, urls: group.items.map(\.url), symbol: "shippingbox",
                    title: group.bundleID, detail: "\(group.items.count) \(group.items.count == 1 ? "item" : "items")",
                    size: group.size, disclosed: open.contains(group.id)
                ) { open.formSymmetricDifference([group.id]) }
                if open.contains(group.id) {
                    ForEach(group.items) { item in
                        CleanerRow(service: service, urls: [item.url], title: item.url.lastPathComponent,
                                   detail: item.url.deletingLastPathComponent().lastPathComponent, size: item.size)
                            .padding(.leading, 22)
                    }
                }
            }
        }
    }
}

/// Caches per app and the developer tools' caches (spec TT-3).
struct CleanerCachesList: View {
    @Bindable var service: CleanerService

    var body: some View {
        CleanerScroll(service: service, isEmpty: service.result.caches.isEmpty, empty: "No caches worth cleaning") {
            ForEach(service.result.caches) { item in
                CleanerRow(
                    service: service, urls: [item.url], title: item.url.lastPathComponent,
                    detail: item.inUse ? "in use" : CleanerCachesList.place(of: item.url), size: item.size
                )
            }
        }
    }

    static func place(of url: URL) -> String {
        url.path.replacingOccurrences(of: CleanerScan.home.path, with: "~")
            .split(separator: "/").dropLast().suffix(2).joined(separator: "/")
    }
}

/// The installed apps; one picked shows its files to remove with it (spec TT-4).
struct CleanerAppsList: View {
    @Bindable var service: CleanerService

    var body: some View {
        if let app = service.app {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Button { service.pick(nil) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.notch)
                        .foregroundStyle(Color.white.level(0.7))
                    AppIcon(url: app.url, size: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name).font(.notch(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                        Text(CleanerService.format(app.size)).font(.notch(size: 11)).foregroundStyle(Color.white.level(0.5))
                    }
                    Spacer()
                    if service.isRunning(app) {
                        Text("Running").font(.notch(size: 11)).foregroundStyle(Color.white.level(0.55))
                        Button("Quit") { service.quit(app) }
                            .buttonStyle(.notch)
                            .font(.notch(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                CleanerScroll(service: service, isEmpty: service.appFiles.isEmpty, empty: "No other files found") {
                    ForEach(service.appFiles) { item in
                        CleanerRow(service: service, urls: [item.url], title: item.url.lastPathComponent,
                                   detail: CleanerCachesList.place(of: item.url), size: item.size)
                    }
                }
            }
        } else {
            VStack(spacing: 6) {
                TextField("Search apps", text: $service.appSearch)
                    .textFieldStyle(.plain)
                    .font(.notch(size: 12))
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.fill))
                CleanerScroll(service: service, isEmpty: service.shownApps.isEmpty, empty: "No apps found") {
                    ForEach(service.shownApps) { app in
                        HStack(spacing: 8) {
                            AppIcon(url: app.url, size: 18)
                            Text(app.name).font(.notch(size: 12, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                            Spacer()
                            Text(CleanerService.format(app.size))
                                .font(.notch(size: 11)).monospacedDigit().foregroundStyle(Color.white.level(0.55))
                        }
                        .padding(.horizontal, 6)
                        .frame(height: 26)
                        .contentShape(Rectangle())
                        .onTapGesture { service.pick(app) }
                    }
                }
            }
        }
    }
}

/// A list that grows with the module, with the Full Disk Access hint at its end (spec TT-6).
struct CleanerScroll<Content: View>: View {
    let service: CleanerService
    let isEmpty: Bool
    let empty: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if isEmpty {
                    Text(service.hasScanned ? empty : "Click Scan to look through your Mac")
                        .font(.notch(size: 12))
                        .foregroundStyle(Color.white.level(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else {
                    content()
                }
                if service.result.needsFullDiskAccess {
                    Button {
                        let link = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
                        if let url = URL(string: link) { NSWorkspace.shared.open(url) }
                    } label: {
                        Label("Some folders need Full Disk Access", systemImage: "lock.shield")
                            .font(.notch(size: 11))
                            .foregroundStyle(Color.white.level(0.55))
                    }
                    .buttonStyle(.notch)
                    .padding(.top, 8)
                }
            }
        }
        .scrollIndicators(.never)
    }
}

/// One row with a tick box: a file, or an app's group of files (spec TT-2, TT-3).
struct CleanerRow: View {
    let service: CleanerService
    let urls: [URL]
    var symbol: String?
    let title: String
    let detail: String
    let size: Int64
    var disclosed: Bool?
    var disclose: () -> Void = {}

    var body: some View {
        let ticked = urls.allSatisfy(service.selected.contains)
        let some = !ticked && urls.contains(where: service.selected.contains)
        HStack(spacing: 8) {
            Button { service.toggle(urls) } label: {
                // Round, not square (spec TT-11).
                Image(systemName: ticked ? "checkmark.circle.fill" : some ? "minus.circle.fill" : "circle")
                    .font(.notch(size: 13))
                    .foregroundStyle(ticked || some ? Theme.blue : Color.white.level(0.45))
            }
            .buttonStyle(.notch)
            if let symbol { Image(systemName: symbol).font(.notch(size: 11)).foregroundStyle(Color.white.level(0.55)) }
            Text(title).font(.notch(size: 12, weight: .medium)).foregroundStyle(.white).lineLimit(1).truncationMode(.middle)
            Text(detail).font(.notch(size: 11)).foregroundStyle(Color.white.level(0.45)).lineLimit(1).layoutPriority(-1)
            Spacer(minLength: 4)
            Text(CleanerService.format(size)).font(.notch(size: 11)).monospacedDigit().foregroundStyle(Color.white.level(0.6))
            if let disclosed {
                Image(systemName: disclosed ? "chevron.down" : "chevron.right")
                    .font(.notch(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.level(0.45))
                    .frame(width: 10)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 24)
        .contentShape(Rectangle())
        .onTapGesture { if disclosed != nil { disclose() } else { service.toggle(urls) } }
    }
}

/// An app's own icon from its bundle.
private struct AppIcon: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .frame(width: size, height: size)
    }
}
