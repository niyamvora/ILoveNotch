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

    /// The open notch's size, set with its resize control. Always within the minimum and maximum.
    public private(set) var expandedSize: CGSize {
        didSet { defaults.set([expandedSize.width, expandedSize.height], forKey: Key.expandedSize) }
    }

    public nonisolated static let defaultExpandedSize = CGSize(width: 460, height: 290)
    public nonisolated static let minimumExpandedSize = CGSize(width: 400, height: 230)
    public nonisolated static let maximumExpandedSize = CGSize(width: 720, height: 480)
    /// Small, medium, and large: what clicking the resize control steps through.
    public nonisolated static let expandedSizePresets = [
        CGSize(width: 420, height: 250), defaultExpandedSize, CGSize(width: 560, height: 360),
    ]

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Key.disabledFeatures) ?? []
        disabledFeatures = Set(stored.compactMap(FeatureID.init(rawValue:)))
        showOnAllDisplays = defaults.bool(forKey: Key.showOnAllDisplays)
        if let size = defaults.array(forKey: Key.expandedSize) as? [Double], size.count == 2 {
            expandedSize = Self.clamped(CGSize(width: size[0], height: size[1]))
        } else {
            expandedSize = Self.defaultExpandedSize
        }
    }

    /// Resizes the open notch, keeping it within the minimum and maximum.
    public func resizeExpanded(to size: CGSize) {
        expandedSize = Self.clamped(size)
    }

    /// Steps to the next preset size up, wrapping around to the smallest.
    public func cycleExpandedSize() {
        let presets = Self.expandedSizePresets
        expandedSize = presets.first { $0.width > expandedSize.width + 1 } ?? presets[0]
    }

    nonisolated static func clamped(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width, minimumExpandedSize.width), maximumExpandedSize.width),
            height: min(max(size.height, minimumExpandedSize.height), maximumExpandedSize.height))
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
        expandedSize = Self.defaultExpandedSize
    }

    private enum Key {
        static let disabledFeatures = "disabledFeatures"
        static let showOnAllDisplays = "showOnAllDisplays"
        static let expandedSize = "expandedSize"
    }
}

/// Calls `apply` now, then again after every change to an observable property it read.
@MainActor
public func observeContinuously(_ apply: @escaping @MainActor () -> Void) {
    withObservationTracking(apply) {
        Task { @MainActor in observeContinuously(apply) }
    }
}
