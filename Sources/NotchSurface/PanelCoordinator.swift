// SPDX-License-Identifier: MIT
import AppKit
import NotchCore

/// Keeps one notch on the preferred display, or on every display, rebuilding them when displays
/// change, and relays sleep, display sleep, and screen lock to all of them.
@MainActor
public final class PanelCoordinator {
    /// Called whenever any notch's presentation, or the set of notches, changes.
    public var onPresentationsChange: (([NotchPresentationState]) -> Void)?

    private let preferences: NotchPreferences
    private let content: NotchContent
    private var controllers: [NotchController] = []
    private var suspensions: Set<SuspendReason> = []
    private var showingAllDisplays = false
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    public init(preferences: NotchPreferences, content: NotchContent) {
        self.preferences = preferences
        self.content = content
    }

    /// Every notch's current presentation.
    public var presentations: [NotchPresentationState] { controllers.map(\.engine.state.presentation) }

    public func start() {
        showingAllDisplays = preferences.showOnAllDisplays
        rebuild()
        watchSystem()
        observeContinuously { [weak self] in
            guard let self else { return }
            let tabs = preferences.tabs
            if preferences.showOnAllDisplays != showingAllDisplays {
                showingAllDisplays = preferences.showOnAllDisplays
                rebuild()
            }
            broadcast(.setTabs(tabs))
            onPresentationsChange?(presentations)
        }
    }

    /// Sends one event, such as a live activity, to every notch.
    public func broadcast(_ event: NotchEvent) {
        for controller in controllers { controller.engine.send(event) }
    }

    /// Opens `tab` on every notch, as if the user had chosen it.
    public func open(_ tab: FeatureID) {
        broadcast(.selectTab(tab))
    }

    /// Gives the keyboard to the first open notch, for typing started from a keyboard shortcut.
    public func focusKeyboard() {
        controllers.first { $0.engine.state.presentation.openTab != nil }?.focusKeyboard()
    }

    /// Opens every closed notch and closes it again, to preview the open and close animation. Only
    /// notches the preview opened are closed, and only if nothing (like a pin) changed them since.
    public func previewAnimation() {
        let engines = controllers.map(\.engine).filter { $0.state.presentation.openTab == nil }
        for engine in engines { engine.send(.clicked) }
        let opened = engines.map { ($0, $0.state.presentation) }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            for (engine, presentation) in opened where engine.state.presentation == presentation {
                engine.send(.dismiss)
            }
        }
    }

    private func rebuild() {
        for controller in controllers { controller.close() }
        let screens = showingAllDisplays ? NSScreen.screens : [NSScreen.preferredForNotch].compactMap { $0 }
        controllers = screens.map { screen in
            let controller = NotchController(screen: screen, content: content, preferences: preferences)
            controller.onPresentationChange = { [weak self] in
                guard let self else { return }
                onPresentationsChange?(presentations)
            }
            controller.engine.send(.setTabs(preferences.tabs))
            for reason in suspensions { controller.engine.send(.suspend(reason)) }
            controller.engine.send(.show)
            return controller
        }
        Log.surface.info("Showing \(self.controllers.count) notch(es)")
        onPresentationsChange?(presentations)
    }

    private func suspend(_ reason: SuspendReason, _ suspended: Bool) {
        if suspended { suspensions.insert(reason) } else { suspensions.remove(reason) }
        broadcast(suspended ? .suspend(reason) : .resume(reason))
    }

    private func watchSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let events: [(NotificationCenter, Notification.Name, @MainActor (PanelCoordinator) -> Void)] = [
            (.default, NSApplication.didChangeScreenParametersNotification, { $0.rebuild() }),
            (workspace, NSWorkspace.willSleepNotification, { $0.suspend(.systemSleep, true) }),
            (workspace, NSWorkspace.didWakeNotification, { $0.suspend(.systemSleep, false) }),
            (workspace, NSWorkspace.screensDidSleepNotification, { $0.suspend(.displaySleep, true) }),
            (workspace, NSWorkspace.screensDidWakeNotification, { $0.suspend(.displaySleep, false) }),
            (workspace, NSWorkspace.sessionDidResignActiveNotification, { $0.suspend(.screenLocked, true) }),
            (workspace, NSWorkspace.sessionDidBecomeActiveNotification, { $0.suspend(.screenLocked, false) }),
            (distributed, Notification.Name("com.apple.screenIsLocked"), { $0.suspend(.screenLocked, true) }),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), { $0.suspend(.screenLocked, false) }),
        ]
        for (center, name, handle) in events {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    handle(self)
                }
            }
            observers.append((center, token))
        }
    }
}

extension NSScreen {
    /// The built-in display with a notch, else the display with the menu bar.
    static var preferredForNotch: NSScreen? {
        screens.first { $0.safeAreaInsets.top > 0 } ?? screens.first
    }
}
