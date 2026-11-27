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

    /// What a scan found, by kind.
    struct Found: Equatable {
        let apps: Int64
        let caches: Int64
        let leftovers: Int64
        var rest = DiskBreakdown()
    }

    /// The parts, largest first from the left (spec TT-23); their sizes add up to the disk's.
    /// - Parameter found: the scanned sizes; nil before a scan.
    static func parts(total: Int64, free: Int64, found: Found?) -> [Part] {
        let used = max(total - free, 0)
        guard let found else {
            return [Part(title: "Used", size: used, color: Color.white.level(0.45)), Part(title: "Free", size: free, color: .clear)]
                .sorted { $0.size > $1.size }
        }
        let measured = [
            Part(title: "Apps", size: found.apps, color: Theme.blue), Part(title: "App data", size: found.rest.appData, color: .teal),
            Part(title: "Caches", size: found.caches, color: .orange), Part(title: "Leftovers", size: found.leftovers, color: .purple),
            Part(title: "System", size: found.rest.system, color: Color.white.level(0.7)),
            Part(title: "Files", size: found.rest.files, color: .green)
        ]
        // Never more than the used space, whatever overlaps.
        var left = used
        var known: [Part] = []
        for part in measured {
            let size = min(part.size, left)
            left -= size
            known.append(Part(title: part.title, size: size, color: part.color))
        }
        let all = known + [Part(title: "Other", size: left, color: Color.white.level(0.35)), Part(title: "Free", size: free, color: .clear)]
        return all.filter { $0.size > 0 || $0.title == "Free" }.sorted { $0.size > $1.size }
    }

    /// What each part holds, on hover (spec TT-24).
    static func help(_ title: String) -> String {
        switch title {
        case "Apps": "Apps in the Applications folders"
        case "App data": "Apps' data in ~/Library: Application Support, Containers, Group Containers"
        case "Caches": "Caches and logs in ~/Library and developer caches"
        case "Leftovers": "Files of apps no longer on the Mac"
        case "System": "macOS itself, its updates and the swap file"
        case "Files": "Desktop, Documents, Downloads, Movies, Music and Pictures"
        case "Other": "Everything else: the rest of ~/Library, hidden folders, other users, snapshots"
        default: title
        }
    }

    var body: some View {
        let result = service.result
        let parts = Self.parts(
            total: service.totalSpace, free: service.freeSpace,
            found: service.hasScanned ? Found(
                apps: result.apps.reduce(0) { $0 + $1.size }, caches: result.caches.reduce(0) { $0 + $1.size },
                leftovers: result.leftovers.reduce(0) { $0 + $1.size }, rest: result.breakdown
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
                CleanerLegendFlow(spacing: 12, lineSpacing: 4) {
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
                        .help(Self.help(part.title))
                    }
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

/// The legend's chips in rows that wrap when the Cleaner is narrow (spec TT-24).
struct CleanerLegendFlow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = place(width: proposal.width ?? .infinity, subviews: subviews)
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: proposal.width ?? frames.map(\.maxX).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = place(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func place(width: CGFloat, subviews: Subviews) -> [CGRect] {
        var frames: [CGRect] = []
        var point = CGPoint.zero
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x > 0, point.x + size.width > width {
                point = CGPoint(x: 0, y: point.y + lineHeight + lineSpacing)
                lineHeight = 0
            }
            frames.append(CGRect(origin: point, size: size))
            point.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return frames
    }
}
