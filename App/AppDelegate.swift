// SPDX-License-Identifier: MIT
import AppKit
import NotchCore
import NotchFeatures
import NotchSurface
import SwiftUI

#if !APP_STORE
    import NotchUsage
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    #if APP_STORE
        // The App Sandbox can't read other tools' sign-ins, so the App Store edition has no AI Usage.
        private let preferences = NotchPreferences(unavailable: [.usage])
    #else
        private let preferences = NotchPreferences()
        private let usage = UsageFeature()
    #endif
    private let media = MediaFeature()
    private let shelf = ShelfFeature()
    private let calendar: CalendarFeature
    private let tasks: TasksFeature
    private let notes = NotesFeature()
    private let shortcuts = ShortcutsFeature()
    private let timer = TimerFeature()
    private let mirror = MirrorFeature()
    private lazy var features = FeatureHost(featureList)
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
        featureSettings: { [unowned self] in self.settingsView(for: $0) },
        usageSettings: usageSettings)

    private var usageSettings: AnyView? {
        #if APP_STORE
            nil
        #else
            AnyView(usage.settingsView)
        #endif
    }

    private var featureList: [any NotchFeature] {
        #if APP_STORE
            [media, shelf, calendar, tasks, notes, shortcuts, timer, mirror]
        #else
            [media, shelf, calendar, tasks, notes, shortcuts, timer, mirror, usage]
        #endif
    }

    private func tabView(for feature: FeatureID) -> AnyView {
        switch feature {
        case .media: return AnyView(media.view)
        case .shelf: return AnyView(shelf.view)
        case .calendar: return AnyView(calendar.view)
        case .tasks: return AnyView(tasks.view)
        case .notes: return AnyView(notes.view)
        case .shortcuts: return AnyView(shortcuts.view)
        case .timer: return AnyView(timer.view)
        case .mirror: return AnyView(mirror.view)
        case .usage:
            #if APP_STORE
                return AnyView(EmptyView())
            #else
                return AnyView(usage.view)
            #endif
        }
    }

    private func settingsView(for feature: FeatureID) -> AnyView? {
        switch feature {
        case .media: return AnyView(media.settingsView)
        case .shelf: return AnyView(shelf.settingsView)
        case .calendar: return AnyView(calendar.settingsView)
        case .tasks: return AnyView(tasks.settingsView)
        case .shortcuts: return AnyView(shortcuts.settingsView)
        case .notes, .timer, .mirror: return nil
        case .usage:
            #if APP_STORE
                return nil
            #else
                // Its settings have their own tab.
                return AnyView(Button("Providers, API Keys, and Refresh…") { [unowned self] in settings.show(.usage) })
            #endif
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let content = NotchContent(
            tab: { [unowned self] in self.tabView(for: $0) },
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
        tasks.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        volume.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        battery.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        accessories.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        #if !APP_STORE
            usage.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
            usage.openSettings = { [weak self] in self?.settings.show(.usage) }
        #endif
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
