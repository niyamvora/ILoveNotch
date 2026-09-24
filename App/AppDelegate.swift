// SPDX-License-Identifier: MIT
import AppKit
import NotchSurface

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prefer a screen that actually has a notch; fall back to the main screen (pill mode).
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        guard let screen else { return }
        let controller = NotchController(screen: screen)
        controller.show()
        self.controller = controller
    }
}
