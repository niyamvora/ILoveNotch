// SPDX-License-Identifier: MIT
import AppKit

/// The menu bar fallback: always reachable, even when the notch is hidden or misbehaving.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let openSettings: () -> Void

    init(openSettings: @escaping () -> Void) {
        self.openSettings = openSettings
        super.init()
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "OpenNotch")
        let menu = NSMenu()
        menu.addItem(menuItem("Settings…", #selector(showSettings), key: ","))
        menu.addItem(menuItem("Sponsor OpenNotch…", #selector(sponsor)))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit OpenNotch", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func menuItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func showSettings() { openSettings() }
    @objc private func sponsor() { NSWorkspace.shared.open(Links.sponsor) }
}

enum Links {
    static let repository = URL(string: "https://github.com/niyamvora/OpenNotch")!
    static let sponsor = URL(string: "https://github.com/sponsors/niyamvora")!
    static let privacy = URL(string: "https://github.com/niyamvora/OpenNotch/blob/main/PRIVACY.md")!
}
