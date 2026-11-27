import SwiftUI

/// The disk at a glance under the Cleaner's header: apps, caches, leftovers, the rest and the
/// free space, with their sizes below (spec TT-18). Before a scan only used and free.
struct CleanerDiskBar: View {
    let service: CleanerService

    struct Part: Identifiable, Equatable {
        let title: String
        let size: Int64
        let color: Color

        var id: String { title }
    }

    /// The parts in order; their sizes add up to the disk's.
    /// What a scan found, by kind.
    struct Found: Equatable {
        let apps: Int64
        let caches: Int64
        let leftovers: Int64
    }

    /// - Parameter found: the scanned sizes; nil before a scan.
    static func parts(total: Int64, free: Int64, found: Found?) -> [Part] {
        let used = max(total - free, 0)
        guard let found else {
            return [Part(title: "Used", size: used, color: Color.white.level(0.45)), Part(title: "Free", size: free, color: .clear)]
        }
        let known = [Part(title: "Apps", size: found.apps, color: Theme.blue), Part(title: "Caches", size: found.caches, color: .orange),
                     Part(title: "Leftovers", size: found.leftovers, color: .purple)]
        let other = max(used - known.reduce(0) { $0 + $1.size }, 0)
        return known + [Part(title: "Other", size: other, color: Color.white.level(0.4)), Part(title: "Free", size: free, color: .clear)]
    }

    var body: some View {
        let result = service.result
        let parts = Self.parts(
            total: service.totalSpace, free: service.freeSpace,
            found: service.hasScanned ? Found(
                apps: result.apps.reduce(0) { $0 + $1.size }, caches: result.caches.reduce(0) { $0 + $1.size },
                leftovers: result.leftovers.reduce(0) { $0 + $1.size }
            ) : nil
        )
        if service.totalSpace > 0 {
            VStack(alignment: .leading, spacing: 5) {
                GeometryReader { proxy in
                    HStack(spacing: 1) {
                        ForEach(parts) { part in
                            Rectangle()
                                .fill(part.color)
                                .frame(width: max(proxy.size.width * CGFloat(part.size) / CGFloat(service.totalSpace), 0))
                        }
                    }
                }
                .frame(height: 8)
                .background(Capsule().fill(Theme.fill))
                .clipShape(Capsule())
                HStack(spacing: 12) {
                    ForEach(parts) { part in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(part.color == .clear ? Theme.fill : part.color)
                                .frame(width: 7, height: 7)
                            Text("\(part.title) \(CleanerService.format(part.size))")
                                .font(.notch(size: 12))
                                .monospacedDigit()
                                .foregroundStyle(Color.white.level(0.6))
                                .lineLimit(1)
                        }
                        .fixedSize()
                    }
                    Spacer(minLength: 0)
                    Text("of \(CleanerService.format(service.totalSpace))")
                        .font(.notch(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.level(0.45))
                        .lineLimit(1)
                }
            }
        }
    }
}
