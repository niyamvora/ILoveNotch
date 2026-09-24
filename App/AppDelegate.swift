// SPDX-License-Identifier: MIT
import AppKit
import NotchCore
import NotchFeatures
import NotchSurface
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = NotchPreferences()
    private let media = MediaFeature()
    private let shelf = ShelfFeature()
    private let notes = NotesFeature()
    private let timer = TimerFeature()
    private lazy var features = FeatureHost([media, shelf, notes, timer])
    private var coordinator: PanelCoordinator?
    private var statusItem: StatusItemController?
    private lazy var settings = SettingsWindowController(preferences: preferences)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let content = NotchContent(
            tab: { [media, shelf, notes, timer] feature in
                switch feature {
                case .media: AnyView(media.view)
                case .shelf: AnyView(shelf.view)
                case .notes: AnyView(notes.view)
                case .timer: AnyView(timer.view)
                default: AnyView(ComingSoonView(feature: feature))
                }
            },
            dropFiles: { [preferences, shelf] urls in preferences.isEnabled(.shelf) && shelf.add(urls) },
            openSettings: { [weak self] in self?.settings.show() })
        let coordinator = PanelCoordinator(preferences: preferences, content: content)
        coordinator.onPresentationsChange = { [weak self] presentations in
            guard let self else { return }
            features.update(presentations: presentations, enabled: Set(preferences.tabs))
        }
        media.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        shelf.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        timer.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        coordinator.start()
        self.coordinator = coordinator
        statusItem = StatusItemController { [weak self] in self?.settings.show() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stops every feature, including the media helper process.
        features.update(presentations: [], enabled: [])
    }
}
