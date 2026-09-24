// SPDX-License-Identifier: MIT

/// A feature that can own the expanded notch.
public enum FeatureID: String, CaseIterable, Hashable, Sendable {
    case media, shelf, tasks, notes
}

/// A one-shot live activity shown on the compact notch, such as a track change or a file drop.
public struct Activity: Hashable, Sendable {
    public var feature: FeatureID
    public var duration: Duration

    public init(feature: FeatureID, duration: Duration) {
        self.feature = feature
        self.duration = duration
    }
}

/// Everything the notch can be doing. One value replaces the prototype's `isOpen` flag,
/// so contradictory combinations (pinned but closed, focused while hidden) can't exist.
public enum NotchPresentationState: Hashable, Sendable {
    /// Not attached to a display.
    case hidden
    /// Resting: a black lip around the physical notch.
    case compact
    /// The pointer is on the notch; it expands once `NotchTiming.hoverDwell` passes.
    case hoverArmed
    /// Open while in use; collapses `NotchTiming.collapseGrace` after the pointer leaves.
    case expanded(tab: FeatureID)
    /// Open until dismissed; ignores the pointer leaving and click-away.
    case pinned(tab: FeatureID)
    /// Taking text input. Stays open and remembers whether it was pinned.
    case focused(tab: FeatureID, pinned: Bool)
    /// Showing a live activity on the compact notch.
    case transient(Activity)
    /// Out of the way: full-screen app, sleep, or screen lock.
    case suspended

    /// The tab on screen when the notch is open.
    public var openTab: FeatureID? {
        switch self {
        case .expanded(let tab), .pinned(let tab), .focused(let tab, _): tab
        default: nil
        }
    }

    /// The one deadline this state may have pending.
    var deadline: Deadline? {
        switch self {
        case .hoverArmed: .hoverDwell
        case .expanded: .collapseGrace
        case .transient: .activityEnd
        default: nil
        }
    }
}

/// Inputs to the reducer. Pointer, keyboard, feature, and system callbacks all become one of these.
public enum NotchEvent: Hashable, Sendable {
    case show
    case hide
    case pointerEntered
    case pointerExited
    /// Primary click on the notch itself.
    case clicked
    /// Click anywhere outside the notch.
    case clickedOutside
    /// Escape or a close control.
    case dismiss
    case selectTab(FeatureID)
    case togglePin
    case beginTextInput
    case endTextInput
    case activity(Activity)
    case suspend
    case resume
    /// A deadline requested by an earlier `NotchEffect.schedule` fired.
    case deadline(Deadline)
}

/// Timers the reducer can ask for. Each belongs to exactly one presentation state.
public enum Deadline: Hashable, Sendable {
    case hoverDwell
    case collapseGrace
    case activityEnd
}

/// Work the reducer asks its runner to do. Scheduling a pending deadline replaces it.
public enum NotchEffect: Hashable, Sendable {
    case schedule(Deadline, after: Duration)
    case cancel(Deadline)
}

/// Pointer hysteresis timings.
public enum NotchTiming {
    // ponytail: hand-picked defaults; calibrate on hardware with the Phase 2 surface.
    /// How long the pointer rests on the notch before it expands.
    public static let hoverDwell: Duration = .milliseconds(100)
    /// How long the pointer may stray from the expanded notch before it collapses.
    public static let collapseGrace: Duration = .milliseconds(250)
}

/// The reducer's whole world: the presentation plus two facts it must carry across states.
public struct NotchState: Hashable, Sendable {
    public private(set) var presentation: NotchPresentationState = .hidden
    /// The tab to show the next time the notch expands.
    public private(set) var lastTab: FeatureID = .media
    /// Kept in every state so a late collapse deadline can't close a notch the pointer is on.
    public private(set) var pointerInside = false

    public init() {}

    /// Applies one event and returns the effects to run. Pure: no clocks, no I/O.
    public mutating func handle(_ event: NotchEvent) -> [NotchEffect] {
        switch event {
        case .pointerEntered: pointerInside = true
        case .pointerExited: pointerInside = false
        default: break
        }
        let before = presentation
        var effects = transition(on: event)
        // Leaving a state cancels the deadline it owned, so at most one deadline is ever pending.
        if let owned = before.deadline, owned != presentation.deadline, event != .deadline(owned) {
            effects.insert(.cancel(owned), at: 0)
        }
        return effects
    }

    /// Every (state, event) pair not listed here is deliberately a no-op, including late deadlines.
    private mutating func transition(on event: NotchEvent) -> [NotchEffect] {
        switch (presentation, event) {
        // Attaching, detaching, suspending, and resuming win over everything else.
        case (.hidden, .show):
            presentation = .compact
        case (.hidden, _):
            break
        case (_, .hide):
            presentation = .hidden
            pointerInside = false
        case (.suspended, .resume):
            presentation = .compact
        case (.suspended, _):
            break
        case (_, .suspend):
            presentation = .suspended
            pointerInside = false

        // Opening
        case (.compact, .pointerEntered):
            presentation = .hoverArmed
            return [.schedule(.hoverDwell, after: NotchTiming.hoverDwell)]
        case (.transient(let activity), .pointerEntered):
            // Hovering a live activity opens the feature that raised it.
            lastTab = activity.feature
            presentation = .hoverArmed
            return [.schedule(.hoverDwell, after: NotchTiming.hoverDwell)]
        case (.compact, .clicked), (.hoverArmed, .clicked), (.hoverArmed, .deadline(.hoverDwell)):
            open(lastTab)
        case (.transient(let activity), .clicked):
            open(activity.feature)
        case (.hoverArmed, .pointerExited), (.hoverArmed, .dismiss):
            presentation = .compact

        // Live activities show only while the notch is closed.
        case (.compact, .activity(let activity)), (.transient, .activity(let activity)):
            presentation = .transient(activity)
            return [.schedule(.activityEnd, after: activity.duration)]
        case (.transient, .deadline(.activityEnd)), (.transient, .dismiss):
            presentation = .compact

        // Expanded
        case (.expanded, .pointerEntered):
            return [.cancel(.collapseGrace)]
        case (.expanded, .pointerExited):
            return [.schedule(.collapseGrace, after: NotchTiming.collapseGrace)]
        case (.expanded, .deadline(.collapseGrace)) where !pointerInside:
            presentation = .compact
        case (.expanded, .clickedOutside), (.expanded, .dismiss):
            presentation = .compact
        case (.expanded(let tab), .togglePin):
            open(tab, pinned: true)
        case (.expanded(let tab), .beginTextInput):
            presentation = .focused(tab: tab, pinned: false)

        // Pinned
        case (.pinned(let tab), .togglePin):
            open(tab)
        case (.pinned(let tab), .beginTextInput):
            presentation = .focused(tab: tab, pinned: true)
        case (.pinned, .dismiss):
            presentation = .compact

        // Focused
        case (.focused(let tab, let pinned), .endTextInput):
            open(tab, pinned: pinned)
        case (.focused(let tab, let pinned), .togglePin):
            presentation = .focused(tab: tab, pinned: !pinned)
        case (.focused(let tab, true), .clickedOutside):
            open(tab, pinned: true)
        case (.focused, .clickedOutside), (.focused, .dismiss):
            presentation = .compact

        // Choosing a tab opens it; in a pinned or focused notch it keeps the pin and ends text input.
        case (.pinned, .selectTab(let tab)), (.focused(_, true), .selectTab(let tab)):
            open(tab, pinned: true)
        case (_, .selectTab(let tab)):
            open(tab)

        default:
            break
        }
        return []
    }

    private mutating func open(_ tab: FeatureID, pinned: Bool = false) {
        lastTab = tab
        presentation = pinned ? .pinned(tab: tab) : .expanded(tab: tab)
    }
}
