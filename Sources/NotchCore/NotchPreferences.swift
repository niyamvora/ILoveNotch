// SPDX-License-Identifier: MIT
// CGSize through Foundation alone makes Swift 6.3 serialize the size constants below with Double
// fields, and Release builds of NotchSurface then crash the optimizer.
import CoreGraphics
import Foundation
import Observation

/// How the notch opens and closes. Hover feedback and live activities keep their own subtle
/// motion, and Reduce Motion overrides every style.
public enum NotchAnimationStyle: String, CaseIterable, Identifiable, Sendable {
    case spring, jelly, pop, smooth, snappy, instant

    public var id: Self { self }

    public var title: String {
        switch self {
        case .spring: "Spring"
        case .jelly: "Jelly"
        case .pop: "Pop"
        case .smooth: "Smooth"
        case .snappy: "Snappy"
        case .instant: "Instant"
        }
    }

    public var summary: String {
        switch self {
        case .spring: "A balanced spring with a hint of bounce."
        case .jelly: "Squashes wide, stretches down, and wobbles into place."
        case .pop: "Springs up from slightly smaller with a quick bounce."
        case .smooth: "Eases in and out, no bounce."
        case .snappy: "Quick and crisp."
        case .instant: "No animation."
        }
    }
}

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

    /// How the notch opens and closes.
    public var animationStyle: NotchAnimationStyle {
        didSet { defaults.set(animationStyle.rawValue, forKey: Key.animationStyle) }
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
        animationStyle = defaults.string(forKey: Key.animationStyle).flatMap(NotchAnimationStyle.init) ?? .spring
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
        animationStyle = .spring
        expandedSize = Self.defaultExpandedSize
    }

    private enum Key {
        static let disabledFeatures = "disabledFeatures"
        static let showOnAllDisplays = "showOnAllDisplays"
        static let animationStyle = "animationStyle"
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
