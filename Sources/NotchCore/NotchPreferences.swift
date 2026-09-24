// SPDX-License-Identifier: MIT
import Foundation
import Observation

/// User preferences, persisted in UserDefaults. The settings UI binds to these directly.
@MainActor
@Observable
public final class NotchPreferences {
    /// Features the user turned off. Stored this way round so features added in later versions
    /// start out enabled.
    public private(set) var disabledFeatures: Set<FeatureID> {
        didSet { defaults.set(disabledFeatures.map(\.rawValue).sorted(), forKey: Key.disabledFeatures) }
    }

    /// Show a notch on every display, not just the built-in (or main) one.
    public var showOnAllDisplays: Bool {
        didSet { defaults.set(showOnAllDisplays, forKey: Key.showOnAllDisplays) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Key.disabledFeatures) ?? []
        disabledFeatures = Set(stored.compactMap(FeatureID.init(rawValue:)))
        showOnAllDisplays = defaults.bool(forKey: Key.showOnAllDisplays)
    }

    /// Enabled features in tab order.
    public var tabs: [FeatureID] { FeatureID.allCases.filter { !disabledFeatures.contains($0) } }

    public func isEnabled(_ feature: FeatureID) -> Bool { !disabledFeatures.contains(feature) }

    public func setEnabled(_ feature: FeatureID, _ enabled: Bool) {
        if enabled { disabledFeatures.remove(feature) } else { disabledFeatures.insert(feature) }
    }

    /// Restores every preference to its default.
    public func reset() {
        disabledFeatures = []
        showOnAllDisplays = false
    }

    private enum Key {
        static let disabledFeatures = "disabledFeatures"
        static let showOnAllDisplays = "showOnAllDisplays"
    }
}

/// Calls `apply` now, then again after every change to an observable property it read.
@MainActor
public func observeContinuously(_ apply: @escaping @MainActor () -> Void) {
    withObservationTracking(apply) {
        Task { @MainActor in observeContinuously(apply) }
    }
}
