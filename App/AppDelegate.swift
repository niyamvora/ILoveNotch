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
    private let mirror = MirrorFeature()
    private lazy var features = FeatureHost([media, shelf, calendar, tasks, notes, shortcuts, timer, mirror])
    // System live activities, which belong to no tab.
    private let volume = VolumeMonitor()
    private let battery = BatteryMonitor()
    private let accessories = AccessoryMonitor()
    private let volumeKeys = VolumeKeyTap()

    override init() {
        let eventStore = EventStore()  // shared, and only created when Calendar or Tasks first needs it
        calendar = CalendarFeature(eventStore: eventStore)
        tasks = TasksFeature(eventStore: eventStore)
        super.init()
    }
    private var coordinator: PanelCoordinator?
    private var statusItem: StatusItemController?
    private let updater = Updater()
    private lazy var settings = SettingsWindowController(
        preferences: preferences,
        updater: updater,
        previewAnimation: { [weak self] in self?.coordinator?.previewAnimation() },
        featureSettings: { [media, shelf, calendar, tasks, shortcuts] feature in
            switch feature {
            case .media: AnyView(media.settingsView)
            case .shelf: AnyView(shelf.settingsView)
            case .calendar: AnyView(calendar.settingsView)
            case .tasks: AnyView(tasks.settingsView)
            case .shortcuts: AnyView(shortcuts.settingsView)
            case .notes, .timer, .mirror: nil
            }
        })

    func applicationDidFinishLaunching(_ notification: Notification) {
        let content = NotchContent(
            tab: { [media, shelf, calendar, tasks, notes, shortcuts, timer, mirror] feature in
                switch feature {
                case .media: AnyView(media.view)
                case .shelf: AnyView(shelf.view)
                case .calendar: AnyView(calendar.view)
                case .tasks: AnyView(tasks.view)
                case .notes: AnyView(notes.view)
                case .shortcuts: AnyView(shortcuts.view)
                case .timer: AnyView(timer.view)
                case .mirror: AnyView(mirror.view)
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
        volume.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        battery.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        accessories.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        volumeKeys.onKey = { [volume] key, fine in
            switch key {
            case .up: volume.step(up: true, fine: fine)
            case .down: volume.step(up: false, fine: fine)
            case .mute: volume.toggleMute()
            }
        }
        coordinator.start()
        self.coordinator = coordinator
        observeContinuously { [weak self] in self?.updateSystemActivities() }
        // Accessibility access arrives while running; this is posted when it changes.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))  // trust updates just after the notification
                self?.updateSystemActivities()
            }
        }
        statusItem = StatusItemController(updater: updater) { [weak self] in self?.settings.show() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stops every feature, including the media helper process and the camera.
        features.update(presentations: [], enabled: [])
        volume.stop()
        battery.stop()
        accessories.stop()
        volumeKeys.stop()
    }

    /// Runs each system activity's listener only while Settings has it on. Replacing the volume
    /// display needs the volume activity and Accessibility access; without access the keys keep
    /// working as usual until access is granted.
    private func updateSystemActivities() {
        preferences.showsVolume ? volume.start() : volume.stop()
        preferences.showsBattery ? battery.start() : battery.stop()
        preferences.showsAccessoryBattery ? accessories.start() : accessories.stop()
        if preferences.showsVolume, preferences.replacesVolumeDisplay {
            volumeKeys.start()
        } else {
            volumeKeys.stop()
        }
    }
}
