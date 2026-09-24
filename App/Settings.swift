// SPDX-License-Identifier: MIT
import AppKit
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
    private let previewAnimation: () -> Void
    private let featureSettings: (FeatureID) -> AnyView?
    private var window: NSWindow?

    /// `featureSettings` supplies each feature's own settings, shown under its toggle.
    init(
        preferences: NotchPreferences, updater: Updater, previewAnimation: @escaping () -> Void,
        featureSettings: @escaping (FeatureID) -> AnyView?
    ) {
        self.preferences = preferences
        self.updater = updater
        self.previewAnimation = previewAnimation
        self.featureSettings = featureSettings
    }

    func show() {
        if window == nil {
            let root = SettingsView(
                preferences: preferences, updater: updater, previewAnimation: previewAnimation,
                featureSettings: featureSettings)
            let window = NSWindow(contentViewController: NSHostingController(rootView: root))
            window.title = "OpenNotch Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let preferences: NotchPreferences
    let updater: Updater
    let previewAnimation: () -> Void
    let featureSettings: (FeatureID) -> AnyView?

    var body: some View {
        TabView {
            GeneralSettings(preferences: preferences, previewAnimation: previewAnimation)
                .tabItem { Label("General", systemImage: "gearshape") }
            FeatureSettings(preferences: preferences, featureSettings: featureSettings)
                .tabItem { Label("Features", systemImage: "square.grid.2x2") }
            AboutSettings(updater: updater)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        // One size for every tab. A grouped Form has almost no height of its own, so a window sized
        // from the tab it opens on came up collapsed with General blank until you switched tabs.
        .frame(width: 460, height: 480)
        .padding()
    }
}

private struct GeneralSettings: View {
    @Bindable var preferences: NotchPreferences
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
            Text("Otherwise OpenNotch uses the built-in display's notch, or the main display.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            Text("Use − and + beside the pin to make the open notch smaller or larger.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Reset to Defaults", role: .destructive) { preferences.reset() }
        }
        .formStyle(.grouped)
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
            Image(systemName: "rectangle.topthird.inset.filled").font(.system(size: 40))
            Text("OpenNotch").font(.title2.bold())
            Text("Version \(Updater.version)").foregroundStyle(.secondary)
            #if !APP_STORE  // the App Store updates its edition
                if updater.sourceDirectory != nil {
                    Button(
                        updater.state == .updating ? "Updating…" : "Update OpenNotch", action: updater.updateFromSource
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
                Link("Sponsor OpenNotch", destination: Links.sponsor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
