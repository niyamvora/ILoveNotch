// SPDX-License-Identifier: MIT
import AppKit

/// The menu bar fallback: always reachable, even when the notch is hidden or misbehaving. The menu
/// is rebuilt each time it opens, so it shows the running version and the updater's state.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let updater: Updater
    private let openSettings: () -> Void

    init(updater: Updater, openSettings: @escaping () -> Void) {
        self.updater = updater
        self.openSettings = openSettings
        super.init()
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "OpenNotch")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let version = NSMenuItem(title: "OpenNotch \(Updater.version)", action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(version)
        for item in updateItems() { menu.addItem(item) }
        menu.addItem(.separator())
        menu.addItem(menuItem("Settings…", #selector(showSettings), key: ","))
        menu.addItem(menuItem("Sponsor OpenNotch…", #selector(sponsor)))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit OpenNotch", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func updateItems() -> [NSMenuItem] {
        #if APP_STORE
            return []  // the App Store updates this edition
        #else
            guard updater.sourceDirectory != nil else {
                return [menuItem("Check for Updates…", #selector(checkForUpdates))]
            }
            switch updater.state {
            case .idle:
                return [menuItem("Update OpenNotch", #selector(update))]
            case .updating:
                let item = NSMenuItem(title: "Updating OpenNotch…", action: nil, keyEquivalent: "")
                item.isEnabled = false
                return [item]
            case .failed:
                return [
                    menuItem("Update Failed: Show Log", #selector(showLog)),
                    menuItem("Try Updating Again", #selector(update)),
                ]
            }
        #endif
    }

    private func menuItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func showSettings() { openSettings() }
    @objc private func sponsor() { NSWorkspace.shared.open(Links.sponsor) }
    @objc private func update() { updater.updateFromSource() }
    @objc private func showLog() { updater.showLog() }
    @objc private func checkForUpdates() { updater.checkForUpdates() }
}

enum Links {
    static let repository = URL(string: "https://github.com/niyamvora/OpenNotch")!
    static let releases = URL(string: "https://github.com/niyamvora/OpenNotch/releases")!
    static let sponsor = URL(string: "https://github.com/sponsors/niyamvora")!
    static let privacy = URL(string: "https://github.com/niyamvora/OpenNotch/blob/main/PRIVACY.md")!
    /// Rendered on GitHub; the direct download also carries a copy in its Resources.
    static let acknowledgements = URL(
        string: "https://github.com/niyamvora/OpenNotch/blob/main/THIRD_PARTY_NOTICES.md")!
}
