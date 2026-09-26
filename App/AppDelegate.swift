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
        // The App Sandbox can't read other tools' sign-ins or add hooks to their settings, so the App
        // Store edition has no AI Usage or Agents.
        private let preferences = NotchPreferences(unavailable: [.usage, .agents])
    #else
        private let preferences = NotchPreferences()
        private let usage = UsageFeature()
        private let agents = AgentsFeature()
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
    /// Opens and closes the notch from any app.
    private let notchKey = HotKey()
    /// Escape, only while a notch the shortcut opened is still open.
    private let escapeKey = HotKey()
    /// Starts a new note from any app, while Notes has it on.
    private let quickNoteKey = HotKey()

    override init() {
        let eventStore = EventStore()  // shared, and only created when Calendar or Tasks first needs it
        calendar = CalendarFeature(eventStore: eventStore)
        tasks = TasksFeature(eventStore: eventStore)
        super.init()
    }
    private var coordinator: PanelCoordinator?
    /// Show in Notch messages that arrived while launching, before there was a notch to show them.
    private var pendingMessages: [Activity] = []
    private var statusItem: StatusItemController?
    private let updater = Updater()
    private lazy var settings = SettingsWindowController(
        preferences: preferences,
        updater: updater,
        notchKey: notchKey,
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
            [media, shelf, calendar, tasks, notes, shortcuts, timer, mirror, usage, agents]
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
        case .agents:
            #if APP_STORE
                return AnyView(EmptyView())
            #else
                return AnyView(agents.view)
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
        case .notes: return AnyView(notes.settingsView)
        case .timer, .mirror: return nil
        case .usage:
            #if APP_STORE
                return nil
            #else
                // Its settings have their own tab.
                return AnyView(Button("Providers, API Keys, and Refresh…") { [unowned self] in settings.show(.usage) })
            #endif
        case .agents:
            #if APP_STORE
                return nil
            #else
                return AnyView(agents.settingsView)
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
            if !presentations.contains(where: { $0.openTab != nil }) { escapeKey.shortcut = nil }
        }
        notchKey.onPress = { [weak self, weak coordinator] in
            guard let self, coordinator?.toggleNotch() == true else { return }
            escapeKey.shortcut = .escape
        }
        escapeKey.onPress = { [weak coordinator] in coordinator?.dismissAll() }
        media.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        shelf.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        calendar.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        calendar.onOngoing = { [weak coordinator] in coordinator?.setOngoing($0, for: .calendar) }
        timer.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        timer.onOngoing = { [weak coordinator] in coordinator?.setOngoing($0, for: .timer) }
        shortcuts.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        tasks.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        notes.onSendToTasks = { [tasks] in tasks.add($0) }
        quickNoteKey.onPress = { [weak self] in self?.startQuickNote() }
        volume.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        battery.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        accessories.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
        #if !APP_STORE
            usage.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
            usage.openSettings = { [weak self] in self?.settings.show(.usage) }
            agents.onActivity = { [weak coordinator] in coordinator?.broadcast(.activity($0)) }
            agents.onOngoing = { [weak coordinator] in coordinator?.setOngoing($0, for: .agents) }
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
        pendingMessages.forEach(showInNotch)
        pendingMessages = []
        observeContinuously { [weak self] in self?.updateSystemActivities() }
        observeContinuously { [weak self] in
            guard let self else { return }
            notchKey.shortcut = preferences.notchShortcut
        }
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

    /// Show in Notch links from scripts and other apps: ilovenotch://show?title=….
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let message = ShowInNotch.activity(from: url) else {
                Log.features.info("Ignored a link: \(url.absoluteString, privacy: .private)")
                continue
            }
            showInNotch(message)
        }
    }

    /// Shows a message from outside ILoveNotch, from a link or the Shortcuts action, as a live
    /// activity.
    func showInNotch(_ message: Activity) {
        guard let coordinator else {
            pendingMessages.append(message)
            return
        }
        coordinator.broadcast(.activity(message))
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stops every feature, including the media helper process and the camera.
        features.update(presentations: [], enabled: [])
        timer.allowSleep()
        volume.stop()
        battery.stop()
        accessories.stop()
        volumeKeys.stop()
    }

    /// Opens the notch on Notes with a new note, ready to type. The tab gets a moment to come on
    /// screen and load before the note is added and the editor takes the keyboard.
    private func startQuickNote() {
        guard let coordinator, preferences.isEnabled(.notes) else { return }
        coordinator.open(.notes)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self else { return }
            notes.quickCapture()
            self.coordinator?.focusKeyboard()
        }
    }

    /// Runs each system activity's listener, and the quick note shortcut, only while Settings has it
    /// on. Replacing the volume display needs the volume activity and Accessibility access; without
    /// access the keys keep working as usual until access is granted.
    private func updateSystemActivities() {
        // Keep awake lives in the Timer tab: turning the tab off must not leave the Mac awake unseen.
        if !preferences.isEnabled(.timer) { timer.allowSleep() }
        preferences.showsVolume ? volume.start() : volume.stop()
        preferences.showsBattery ? battery.start() : battery.stop()
        preferences.showsAccessoryBattery ? accessories.start() : accessories.stop()
        if preferences.showsVolume, preferences.replacesVolumeDisplay {
            volumeKeys.start()
        } else {
            volumeKeys.stop()
        }
        quickNoteKey.shortcut = notes.quickNoteShortcut && preferences.isEnabled(.notes) ? .newNote : nil
    }
}
