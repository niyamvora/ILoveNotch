// SPDX-License-Identifier: MIT
import SwiftUI

extension UsageFeature {
    /// Which providers to show, and whether to refresh in the background.
    public var settingsView: some View { UsageSettings(usage: self) }
}

private struct UsageSettings: View {
    @Bindable var usage: UsageFeature

    var body: some View {
        Group {
            ForEach(usage.providers) { provider in
                // A closure, not a method reference: see the app's GeneralSettings.
                Toggle(
                    isOn: Binding(get: { usage.isEnabled(provider.id) }, set: { usage.setEnabled(provider.id, $0) })
                ) {
                    HStack(spacing: 6) {
                        ProviderLogo(providerID: provider.id, name: provider.name, size: 14)
                        Text(provider.name)
                        if usage.detected.contains(provider.id) {
                            Text("Signed in on this Mac").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Picker("Refresh in the background", selection: $usage.backgroundRefresh) {
                ForEach(UsageFeature.BackgroundRefresh.allCases) { Text($0.title).tag($0) }
            }
            Text(
                "Each provider reads only the sign-in its own tool keeps on this Mac and sends it only to its "
                    + "own service. Spend estimates use public price lists from LiteLLM, models.dev, and "
                    + "OpenUsage. Usage code adapted from OpenUsage; provider logos from theSVG."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .task { await usage.detect() }
    }
}
