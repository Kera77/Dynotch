import Foundation

/// One line on the What's new card: an icon, a title and one sentence (spec WN-1).
struct WhatsNewItem: Sendable, Hashable {
    let symbol: String
    let title: String
    let text: String
}

struct WhatsNewRelease: Sendable, Hashable {
    let version: String
    let items: [WhatsNewItem]
}

/// What each version brought, newest first (spec WN-4). Every user-visible feature or change
/// gets a short line here in the same change; the CHANGELOG is the long version.
enum WhatsNew {
    static let releases: [WhatsNewRelease] = [
        WhatsNewRelease(version: "1.1.0", items: [
            WhatsNewItem(symbol: "sparkles.rectangle.stack", title: "What's new",
                         text: "After an update, this card shows what arrived since the version you had."),
            WhatsNewItem(symbol: "arrow.up.and.down.and.arrow.left.and.right", title: "A tour that fits",
                         text: "The tour is as big as it needs to be, its buttons stay on screen, and you can drag it anywhere."),
            WhatsNewItem(symbol: "xmark.circle", title: "End tour",
                         text: "Settings › General › End tour stops the tour and the first-use tips in the modules."),
            WhatsNewItem(symbol: "square.grid.2x2", title: "Modules explained",
                         text: "The tour's Choose your modules step tells in a few sentences what each module does.")
        ]),
        WhatsNewRelease(version: "1.0.0", items: [
            WhatsNewItem(symbol: "airplane", title: "Hello, Wingmate",
                         text: "Dynotch is now called Wingmate; your settings and permissions stay."),
            WhatsNewItem(symbol: "graduationcap", title: "A guided tour",
                         text: "A short tour at first launch, with first-use tips in each module; replay it in Settings › General.")
        ])
    ]

    /// The releases after `last` up to `current`, newest first (spec WN-1…WN-3).
    static func due(last: String?, current: String, tourDone: Bool) -> [WhatsNewRelease] {
        // A first install gets the tour instead (spec WN-2).
        guard tourDone else { return [] }
        // Updated from 1.0, before this was kept: only the current version (spec WN-3).
        guard let last else { return releases.filter { $0.version == current } }
        return releases.filter {
            UpdateLogic.isNewer($0.version, than: last) && !UpdateLogic.isNewer($0.version, than: current)
        }
    }
}

/// The last version whose What's new was seen, in UserDefaults (spec WN-3).
struct WhatsNewProgress {
    static let lastVersionKey = "whatsNew.lastVersion"

    let defaults: UserDefaults

    var lastVersion: String? { defaults.string(forKey: Self.lastVersionKey) }

    func markSeen(_ version: String) {
        defaults.set(version, forKey: Self.lastVersionKey)
    }
}
