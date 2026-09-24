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
    private let calendar: CalendarFeature
    private let tasks: TasksFeature
    private let notes = NotesFeature()
    private let shortcuts = ShortcutsFeature()
    private let timer = TimerFeature()
    private lazy var features = FeatureHost([media, shelf, calendar, tasks, notes, shortcuts, timer])

    override init() {
        let eventStore = EventStore()  // shared, and only created when Calendar or Tasks first needs it
        calendar = CalendarFeature(eventStore: eventStore)
        tasks = TasksFeature(eventStore: eventStore)
        super.init()
    }
    private var coordinator: PanelCoordinator?
    private var statusItem: StatusItemController?
    private lazy var settings = SettingsWindowController(
        preferences: preferences,
        previewAnimation: { [weak self] in self?.coordinator?.previewAnimation() },
        featureSettings: { [media, shelf, calendar, tasks, shortcuts] feature in
            switch feature {
            case .media: AnyView(media.settingsView)
            case .shelf: AnyView(shelf.settingsView)
            case .calendar: AnyView(calendar.settingsView)
            case .tasks: AnyView(tasks.settingsView)
            case .shortcuts: AnyView(shortcuts.settingsView)
            case .notes, .timer: nil
            }
        })

    func applicationDidFinishLaunching(_ notification: Notification) {
        let content = NotchContent(
            tab: { [media, shelf, calendar, tasks, notes, shortcuts, timer] feature in
                switch feature {
                case .media: AnyView(media.view)
                case .shelf: AnyView(shelf.view)
                case .calendar: AnyView(calendar.view)
                case .tasks: AnyView(tasks.view)
                case .notes: AnyView(notes.view)
                case .shortcuts: AnyView(shortcuts.view)
                case .timer: AnyView(timer.view)
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
        shortcuts.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        coordinator.start()
        self.coordinator = coordinator
        statusItem = StatusItemController { [weak self] in self?.settings.show() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stops every feature, including the media helper process.
        features.update(presentations: [], enabled: [])
    }
}
