// SPDX-License-Identifier: MIT
import NotchCore
import SwiftUI

/// Stand-in for features that haven't landed yet.
struct ComingSoonView: View {
    let feature: FeatureID

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: feature.symbol).font(.system(size: 26, weight: .semibold))
            Text(feature.title).font(.headline)
            Text("Coming soon").font(.caption).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
