// SPDX-License-Identifier: MIT
import AppKit
import Carbon.HIToolbox
import NotchCore
import NotchFeatures
import ServiceManagement
import SwiftUI

/// Accessory apps have no app menu, so Settings opens from the menu bar item or the notch's gear
/// button, and activates the app while it's up.
@MainActor
final class SettingsWindowController {
    private let preferences: NotchPreferences
    private let updater: Updater
    private let notchKey: HotKey
    private let clipboardKey: HotKey
    private let previewAnimation: () -> Void
    private let featureSettings: (FeatureID) -> AnyView?
    private let usageSettings: AnyView?
    private let selection = SettingsSelection()
    private var window: NSWindow?

    /// `featureSettings` supplies each feature's own settings, shown under its toggle; `usageSettings`,
    /// when this edition has AI Usage, gets a tab of its own.
    init(
        preferences: NotchPreferences, updater: Updater, notchKey: HotKey, clipboardKey: HotKey,
        previewAnimation: @escaping () -> Void, featureSettings: @escaping (FeatureID) -> AnyView?,
        usageSettings: AnyView?
    ) {
        self.preferences = preferences
        self.updater = updater
        self.notchKey = notchKey
        self.clipboardKey = clipboardKey
        self.previewAnimation = previewAnimation
        self.featureSettings = featureSettings
        self.usageSettings = usageSettings
    }

    /// Shows Settings, on `tab` when one is given.
    func show(_ tab: SettingsSelection.Tab? = nil) {
        if let tab { selection.tab = tab }
        if window == nil {
            let root = SettingsView(
                preferences: preferences, updater: updater, notchKey: notchKey, clipboardKey: clipboardKey,
                previewAnimation: previewAnimation, featureSettings: featureSettings, usageSettings: usageSettings,
                selection: selection)
            let window = NSWindow(contentViewController: NSHostingController(rootView: root))
            window.title = "ILoveNotch Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Which Settings tab is showing, so the notch can open a given one.
@MainActor
@Observable
final class SettingsSelection {
    enum Tab: Hashable { case general, features, usage, about }
    var tab = Tab.general
}

struct SettingsView: View {
    let preferences: NotchPreferences
    let updater: Updater
    let notchKey: HotKey
    let clipboardKey: HotKey
    let previewAnimation: () -> Void
    let featureSettings: (FeatureID) -> AnyView?
    let usageSettings: AnyView?
    @Bindable var selection: SettingsSelection

    var body: some View {
        TabView(selection: $selection.tab) {
            GeneralSettings(
                preferences: preferences, notchKey: notchKey, clipboardKey: clipboardKey,
                previewAnimation: previewAnimation
            )
            .tabItem { Label("General", systemImage: "gearshape") }
            .tag(SettingsSelection.Tab.general)
            FeatureSettings(preferences: preferences, featureSettings: featureSettings)
                .tabItem { Label("Features", systemImage: "square.grid.2x2") }
                .tag(SettingsSelection.Tab.features)
            if let usageSettings {
                usageSettings
                    .tabItem { Label(FeatureID.usage.title, systemImage: FeatureID.usage.symbol) }
                    .tag(SettingsSelection.Tab.usage)
            }
            AboutSettings(updater: updater)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsSelection.Tab.about)
        }
        // One size for every tab. A grouped Form has almost no height of its own, so a window sized
        // from the tab it opens on came up collapsed with General blank until you switched tabs.
        .frame(width: 460, height: 480)
        .padding()
    }
}

private struct GeneralSettings: View {
    @Bindable var preferences: NotchPreferences
    let notchKey: HotKey
    let clipboardKey: HotKey
    let previewAnimation: () -> Void
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            // A closure, not a method reference: converting the method to Binding's isolated
            // setter type crashes the Swift 6.3 compiler in IRGen.
            Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) }))
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
            Toggle("Show on all displays", isOn: $preferences.showOnAllDisplays)
            Text("Otherwise ILoveNotch uses the built-in display's notch, or the main display.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledContent("Open the notch") {
                ShortcutRecorder(shortcut: $preferences.notchShortcut, hotKey: notchKey)
            }
            shortcutNote(
                notchKey, preferences.notchShortcut,
                "From any app, on the display under the pointer. Press it again or Escape to close.")
            if preferences.isEnabled(.clipboard) {
                LabeledContent("Search the clipboard") {
                    ShortcutRecorder(shortcut: $preferences.clipboardShortcut, hotKey: clipboardKey)
                }
                shortcutNote(
                    clipboardKey, preferences.clipboardShortcut,
                    "Opens the Clipboard tab ready to type; Return copies the first match.")
            }
            Picker("Open and close animation", selection: $preferences.animationStyle) {
                ForEach(NotchAnimationStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            HStack {
                Text(preferences.animationStyle.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Preview", action: previewAnimation)
            }
            LabeledContent("Open notch size") {
                HStack {
                    Text("\(Int(preferences.expandedSize.width)) × \(Int(preferences.expandedSize.height))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button("Reset") { preferences.resizeExpanded(to: NotchPreferences.defaultExpandedSize) }
                        .disabled(preferences.expandedSize == NotchPreferences.defaultExpandedSize)
                }
            }
            Text("Drag the open notch's bottom-right corner to make it smaller or larger.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Reset to Defaults", role: .destructive) { preferences.reset() }
        }
        .formStyle(.grouped)
    }

    /// What a shortcut does, or that another app already has it.
    private func shortcutNote(_ hotKey: HotKey, _ shortcut: KeyShortcut?, _ explanation: String) -> some View {
        Group {
            if hotKey.isAvailable {
                Text(explanation).foregroundStyle(.secondary)
            } else {
                Text("Another app already uses \(shortcut?.display ?? "it"). Record another.").foregroundStyle(.red)
            }
        }
        .font(.caption)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// Click, then press the new shortcut; Escape cancels and Delete clears it. The shortcut stops
/// working while recording, so pressing the current one records it rather than opening the notch.
private struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut?
    let hotKey: HotKey
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(monitor != nil ? "Press the shortcut…" : shortcut?.display ?? "Record Shortcut") {
                monitor == nil ? record() : stop()
            }
            .help(monitor != nil ? "Escape cancels, Delete clears" : "Click, then press a new shortcut")
            if shortcut != nil, monitor == nil {
                Button("Clear") { shortcut = nil }
            }
        }
        .onDisappear(perform: stop)
    }

    private func record() {
        hotKey.isPaused = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                let plain = event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift])
                switch Int(event.keyCode) {
                case kVK_Escape where plain:
                    stop()
                case kVK_Delete where plain, kVK_ForwardDelete where plain:
                    shortcut = nil
                    stop()
                default:
                    guard let recorded = KeyShortcut(event: event) else {
                        NSSound.beep()  // needs Command, Option, or Control
                        return
                    }
                    shortcut = recorded
                    stop()
                }
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        hotKey.isPaused = false
    }
}

/// One section per feature: whether it shows in the notch, then its own settings while it does.
private struct FeatureSettings: View {
    let preferences: NotchPreferences
    let featureSettings: (FeatureID) -> AnyView?

    var body: some View {
        Form {
            ForEach(preferences.available, id: \.self) { feature in
                Section {
                    Toggle(
                        isOn: Binding(
                            get: { preferences.isEnabled(feature) },
                            set: { preferences.setEnabled(feature, $0) })
                    ) {
                        Label(feature.title, systemImage: feature.symbol).font(.headline)
                    }
                    if preferences.isEnabled(feature), let settings = featureSettings(feature) {
                        settings
                    }
                }
            }
            SystemSettings(preferences: preferences)
        }
        .formStyle(.grouped)
    }
}

/// Live activities that belong to no tab: volume, battery, and accessories.
private struct SystemSettings: View {
    @Bindable var preferences: NotchPreferences
    @State private var trusted = VolumeKeyTap.isTrusted

    var body: some View {
        Section {
            Toggle("Show volume changes", isOn: $preferences.showsVolume)
            #if !APP_STORE  // the App Sandbox allows neither the volume-key tap nor the accessory monitor
                // A closure, not a method reference: see GeneralSettings.
                let replaces = Binding(
                    get: { preferences.replacesVolumeDisplay }, set: { setReplacesVolumeDisplay($0) })
                Toggle(isOn: replaces) {
                    Text("Replace the macOS volume display")
                    Text("Catches the volume keys so the change shows in the notch. Needs Accessibility access.")
                }
                .disabled(!preferences.showsVolume)
                if preferences.replacesVolumeDisplay, !trusted {
                    LabeledContent("Accessibility") {
                        Button("Open Accessibility Settings") {
                            NSWorkspace.shared.open(.privacySettings("Privacy_Accessibility"))
                        }
                    }
                }
            #endif
            Toggle("Show charging and battery", isOn: $preferences.showsBattery)
            #if !APP_STORE
                Toggle(isOn: $preferences.showsAccessoryBattery) {
                    Text("Show a Bluetooth accessory's battery when it connects")
                    Text("Experimental: Apple keyboards, mice, and trackpads.")
                }
            #endif
        } header: {
            Label("System", systemImage: "gearshape.2").font(.headline)
        }
        .onAppear { trusted = VolumeKeyTap.isTrusted }
    }

    private func setReplacesVolumeDisplay(_ replaces: Bool) {
        preferences.replacesVolumeDisplay = replaces
        trusted = VolumeKeyTap.isTrusted
        if replaces, !trusted { VolumeKeyTap.requestTrust() }
    }
}

private struct AboutSettings: View {
    let updater: Updater

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            Text("ILoveNotch").font(.title2.bold())
            Text("Version \(Updater.version)").foregroundStyle(.secondary)
            #if !APP_STORE  // the App Store updates its edition
                if updater.sourceDirectory != nil {
                    Button(
                        updater.state == .updating ? "Updating…" : "Update ILoveNotch", action: updater.updateFromSource
                    )
                    .disabled(updater.state == .updating)
                    if updater.state == .failed {
                        Button("The update failed. Show Log", action: updater.showLog).buttonStyle(.link)
                    }
                    Text("Rebuilds from this Mac's checkout and relaunches.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Check for Updates…", action: updater.checkForUpdates)
                }
            #endif
            Text("Free and open source under the MIT License. Local-first: no accounts, no telemetry.")
                .font(.callout)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("GitHub", destination: Links.repository)
                Link("Privacy", destination: Links.privacy)
                Link("Acknowledgements", destination: Links.acknowledgements)
                Link("Sponsor ILoveNotch", destination: Links.sponsor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
