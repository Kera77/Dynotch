import Foundation

// MARK: - Teams in a background tab (spec MT-13)

extension TeamsService {
    /// Teams not readable: a Teams tab behind another one in the default browser says why.
    func findBackgroundTab() async {
        let tab = await TeamsTabs.read()?.first { !$0.isActive }
        guard isEnabled, snapshot == nil else { return }
        backgroundTab = tab
        setState(tab == nil ? .notFound : .backgroundTab)
    }

    /// Settings' button: the tab moves to a window of its own, where Teams can be read.
    func moveToOwnWindow() {
        guard let tab = backgroundTab else { return }
        Task {
            let moved = await TeamsTabs.moveToOwnWindow(tab)
            TeamsLog.write(moved ? "moved to its own window" : "move failed")
            backgroundTab = nil
            try? await Task.sleep(for: .seconds(3))
            refresh()
        }
    }
}
