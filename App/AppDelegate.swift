// SPDX-License-Identifier: MIT
import AppKit
import NotchCore
import NotchSurface
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = NotchPreferences()
    private let features = FeatureHost([])
    private var coordinator: PanelCoordinator?
    private var statusItem: StatusItemController?
    private lazy var settings = SettingsWindowController(preferences: preferences)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let content = NotchContent(
            tab: { AnyView(ComingSoonView(feature: $0)) },
            dropFiles: { _ in false },
            openSettings: { [weak self] in self?.settings.show() })
        let coordinator = PanelCoordinator(preferences: preferences, content: content)
        coordinator.onPresentationsChange = { [weak self] presentations in
            guard let self else { return }
            features.update(presentations: presentations, enabled: Set(preferences.tabs))
        }
        coordinator.start()
        self.coordinator = coordinator
        statusItem = StatusItemController { [weak self] in self?.settings.show() }
    }
}
