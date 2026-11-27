import AppKit
import Observation

/// Icons of networks whose app is not installed (e.g. Instagram), fetched once from the network's
/// own website and kept in Application Support (spec BP-3c). No logos live in the repository.
@MainActor
@Observable
final class NetworkIcons {
    static let shared = NetworkIcons()

    private(set) var icons: [String: NSImage] = [:]
    @ObservationIgnored private var asked: Set<String> = []
    private let folder: URL

    /// Word in the network's name → its website.
    nonisolated static let sites: [(word: String, host: String)] = [
        ("instagram", "www.instagram.com"), ("linkedin", "www.linkedin.com"), ("twitter", "x.com"),
        ("telegram", "telegram.org"), ("signal", "signal.org"), ("slack", "slack.com"), ("whatsapp", "www.whatsapp.com")
    ]

    init(folder: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.folder = folder ?? support.appendingPathComponent("Wingmate/NetworkIcons")
    }

    nonisolated static func host(for network: String?) -> String? {
        let lowered = (network ?? "").lowercased()
        return sites.first { lowered.contains($0.word) }?.host
    }

    /// The icon if known; otherwise it is fetched in the background and published when it comes.
    func icon(for network: String?) -> NSImage? {
        guard let host = Self.host(for: network) else { return nil }
        if let icon = icons[host] { return icon }
        let file = folder.appendingPathComponent(host + ".png")
        if let stored = NSImage(contentsOf: file) {
            icons[host] = stored
            return stored
        }
        guard asked.insert(host).inserted else { return nil }
        Task { [weak self] in
            guard let data = await Self.download(host), let image = NSImage(data: data), let self else { return }
            try? FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            self.icons[host] = image
        }
        return nil
    }

    /// The apple-touch-icon if the site has one, else its favicon; only real images count.
    nonisolated private static func download(_ host: String) async -> Data? {
        for path in ["apple-touch-icon.png", "favicon.ico"] {
            guard let url = URL(string: "https://\(host)/\(path)") else { continue }
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  (response.mimeType ?? "").hasPrefix("image/"), NSImage(data: data) != nil
            else { continue }
            return data
        }
        return nil
    }
}
