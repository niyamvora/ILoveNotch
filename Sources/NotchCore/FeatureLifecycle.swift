// SPDX-License-Identifier: MIT

/// How much work a feature module may do right now.
public enum FeaturePhase: Hashable, Sendable {
    /// Released: no observers, no tasks, no caches.
    case stopped
    /// Enabled but off screen: only cheap, event-driven observers, such as listening for a
    /// track change so it can raise a live activity.
    case background
    /// On screen: full work, such as artwork, visualizers, or camera capture.
    case foreground
}

/// A notch feature module. `NotchEngine` sets `phase` whenever the presentation changes, and
/// only when the value actually changes; a module starts and stops its work in `didSet`.
@MainActor
public protocol NotchFeature: AnyObject {
    var id: FeatureID { get }
    var phase: FeaturePhase { get set }
}

extension NotchPresentationState {
    /// The feature on screen: the open tab, or the owner of the live activity.
    public var visibleFeature: FeatureID? {
        if case .transient(let activity) = self { return activity.feature }
        return openTab
    }

    /// Activation policy: the visible feature runs fully, the others keep only cheap observers,
    /// and nothing runs while the notch is hidden or suspended.
    public func phase(for feature: FeatureID) -> FeaturePhase {
        switch self {
        case .hidden, .suspended: .stopped
        default: visibleFeature == feature ? .foreground : .background
        }
    }
}
