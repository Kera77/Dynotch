import SwiftUI

/// The Cleaner on the Stats: leftovers of removed apps, caches, and removing an app with its files
/// (spec TT-1…TT-6, TT-8).
struct CleanerView: View {
    @Bindable var service: CleanerService
    let isActive: Bool
    /// ‹ Stats (spec TT-8); nil when the Cleaner was not opened from the Stats (spec TT-33).
    let back: (() -> Void)?

    @State private var confirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            CleanerDiskBar(service: service)
            Group {
                if service.isScanning && !service.hasScanned {
                    scanning
                } else {
                    switch service.tab {
                    case .leftovers: CleanerLeftoversList(service: service)
                    case .caches: CleanerCachesList(service: service)
                    case .apps: CleanerAppsList(service: service)
                    case .large: CleanerLargeList(service: service)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Buttons grow a little on hover instead of the grey highlight (spec TT-30).
        .environment(\.notchHover, .grow)
        .overlay { if service.isCleaning { busy } }
        .onChange(of: isActive, initial: true) { _, active in
            service.isViewed = active
            if active { service.scanIfNeeded(); service.refreshSpace() }
        }
        .onDisappear { service.isViewed = false }
        .onChange(of: service.tab) { confirming = false }
        .onChange(of: service.asksToUninstall) { _, asks in
            guard asks else { return }
            confirming = true
            service.asksToUninstall = false
        }
    }

    private func backButton(_ back: @escaping () -> Void) -> some View {
        Button(action: back) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left").font(.notch(size: 12, weight: .semibold))
                Text("Stats").font(.notch(size: 13, weight: .medium))
            }
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Capsule().fill(Theme.fill))
            .contentShape(Capsule())
        }
        .buttonStyle(.notch)
        .foregroundStyle(Color.white.level(0.8))
        .help("Back to the Stats")
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let back { backButton(back) }
            Text("Cleaner")
                .font(.notch(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 4)
            CapsulePicker(items: CleanerService.Tab.allCases, selection: $service.tab, title: \.title)
            if service.isScanning {
                ProgressView().controlSize(.mini).frame(width: 40)
            } else {
                Button("Scan") { service.scan() }
                    .buttonStyle(.notch)
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.level(0.75))
                    .frame(width: 40)
            }
        }
    }

    /// Over the whole Cleaner while it cleans: nothing in it can be clicked (spec TT-12).
    private var busy: some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Cleaning…").font(.notch(size: 13, weight: .medium)).foregroundStyle(Color.white.level(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Color.black.opacity(0.6)))
        .contentShape(Rectangle())
        .onTapGesture {}
        .transition(.opacity)
    }

    private var scanning: some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Scanning…").font(.notch(size: 13)).foregroundStyle(Color.white.level(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var footer: some View {
        let pending = service.pending
        let size = pending.reduce(Int64(0)) { $0 + $1.size }
        HStack(spacing: 8) {
            if confirming {
                let quits = service.tab == .apps && service.app.map(service.isRunning) == true
                Text((quits ? "Quit and move " : "Move ")
                     + "\(pending.count) \(pending.count == 1 ? "item" : "items") (\(CleanerService.format(size))) to the Trash?")
                    .font(.notch(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button("Cancel") { confirming = false }
                    .buttonStyle(.notch)
                    .font(.notch(size: 12))
                    .foregroundStyle(Color.white.level(0.7))
                pill("Move to Trash", color: Theme.red) {
                    confirming = false
                    // A running app quits first, then goes (spec TT-26).
                    withAnimation(Motion.quick) { if service.tab == .apps { service.uninstallPicked() } else { service.trashPending() } }
                }
            } else {
                status
                Spacer(minLength: 4)
                // On the Apps tab Uninstall is in the row or the details (spec TT-17, TT-19).
                if !pending.isEmpty, service.tab != .apps {
                    Text("\(pending.count) selected · \(CleanerService.format(size))")
                        .font(.notch(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.level(0.6))
                    pill("Clean", color: Theme.blue) { confirming = true }
                }
            }
        }
        .frame(height: 26)
    }

    @ViewBuilder private var status: some View {
        if let freed = service.freed {
            Label {
                Text("Freed \(CleanerService.format(freed))"
                     + (service.failed > 0 ? " · \(service.failed) could not be moved" : ""))
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            }
            .font(.notch(size: 12, weight: .medium))
            .foregroundStyle(Color.white.level(0.75))
            .lineLimit(1)
        }
    }

    private func pill(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        // The capsule is in the label, so the whole pill grows on hover (spec TT-30).
        Button(action: action) {
            Text(title)
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(color))
                .contentShape(Capsule())
        }
        .buttonStyle(.notch)
    }
}

/// Clean on the Stats' Disk card and on the disk tiles: opens the Cleaner (spec TT-8, TT-10).
struct CleanButton: View {
    /// The tile it sits on, so the Stats grow from it; nil on the Disk card.
    var tile: HomeTile?

    @Environment(\.openCleaner) private var openCleaner

    var body: some View {
        Button { openCleaner(tile) } label: {
            Text("Clean")
                .font(.notch(size: 10, weight: .semibold))
                .padding(.horizontal, 8)
                .frame(height: 18)
                .background(Capsule().fill(Theme.selectedFill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .help("Open the Cleaner")
    }
}

/// The Home tile: what the last scan found (spec TT-7).
struct CleanerTileContent: View {
    let service: CleanerService

    var body: some View {
        TileValueView(
            title: "Cleaner",
            value: service.hasScanned ? CleanerService.format(service.cleanable) : "Scan",
            detail: service.hasScanned ? "to clean" : "Free up space"
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) { CleanButton(tile: .cleaner) }
    }
}
