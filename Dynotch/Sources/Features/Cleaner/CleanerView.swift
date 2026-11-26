import SwiftUI

/// The Cleaner module: leftovers of removed apps, caches, and removing an app with its files
/// (spec TT-1…TT-6).
struct CleanerView: View {
    @Bindable var service: CleanerService
    let isActive: Bool

    @State private var confirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Group {
                if service.isScanning && !service.hasScanned {
                    scanning
                } else {
                    switch service.tab {
                    case .leftovers: CleanerLeftoversList(service: service)
                    case .caches: CleanerCachesList(service: service)
                    case .apps: CleanerAppsList(service: service)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: isActive, initial: true) { _, active in
            if active { service.scanIfNeeded(); service.refreshSpace() }
        }
        .onChange(of: service.tab) { confirming = false }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Cleaner")
                .font(.notch(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            if service.totalSpace > 0 {
                Text("\(CleanerService.format(service.freeSpace)) free of \(CleanerService.format(service.totalSpace))")
                    .font(.notch(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.level(0.5))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            CapsulePicker(items: CleanerService.Tab.allCases, selection: $service.tab, title: \.title)
            if service.isScanning {
                ProgressView().controlSize(.mini).frame(width: 40)
            } else {
                Button("Scan") { service.scan() }
                    .buttonStyle(.notch)
                    .font(.notch(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.level(0.75))
                    .frame(width: 40)
            }
        }
    }

    private var scanning: some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Scanning…").font(.notch(size: 12)).foregroundStyle(Color.white.level(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var footer: some View {
        let pending = service.pending
        let size = pending.reduce(Int64(0)) { $0 + $1.size }
        HStack(spacing: 8) {
            if confirming {
                Text("Move \(pending.count) \(pending.count == 1 ? "item" : "items") (\(CleanerService.format(size))) to the Trash?")
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button("Cancel") { confirming = false }
                    .buttonStyle(.notch)
                    .font(.notch(size: 11))
                    .foregroundStyle(Color.white.level(0.7))
                pill("Move to Trash", color: Theme.red) {
                    confirming = false
                    service.trashPending()
                }
            } else {
                status
                Spacer(minLength: 4)
                if !pending.isEmpty {
                    Text("\(pending.count) selected · \(CleanerService.format(size))")
                        .font(.notch(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.level(0.6))
                    pill(service.tab == .apps ? "Uninstall" : "Clean", color: Theme.blue) { confirming = true }
                        .disabled(service.tab == .apps && service.app.map(service.isRunning) == true)
                }
            }
        }
        .frame(height: 24)
    }

    @ViewBuilder private var status: some View {
        if let freed = service.freed {
            Label {
                Text("Freed \(CleanerService.format(freed))"
                     + (service.failed > 0 ? " · \(service.failed) could not be moved" : ""))
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            }
            .font(.notch(size: 11, weight: .medium))
            .foregroundStyle(Color.white.level(0.75))
            .lineLimit(1)
        }
    }

    private func pill(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.notch)
            .font(.notch(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(Capsule().fill(color))
    }
}

/// The cleaner beside the notch and in the preview (spec TT-7).
enum CleanerWing {
    @MainActor static func right(_ service: CleanerService) -> String {
        if service.isScanning { return "Scanning…" }
        guard service.hasScanned else { return "Click to scan" }
        return "\(CleanerService.format(service.cleanable)) to clean"
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
    }
}
