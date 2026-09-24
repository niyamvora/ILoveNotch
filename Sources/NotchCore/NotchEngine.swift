// SPDX-License-Identifier: MIT
import Observation

/// Runs the notch on the main actor: feeds events through the reducer, runs its deadline effects
/// on cancellable one-shot timers (never a polling loop), and moves feature modules through their
/// lifecycle whenever the presentation changes.
@MainActor
@Observable
public final class NotchEngine {
    public private(set) var state = NotchState()

    /// Called after every presentation change, for example to resize the panel.
    @ObservationIgnored
    public var onPresentationChange: ((_ old: NotchPresentationState, _ new: NotchPresentationState) -> Void)?

    @ObservationIgnored private let features: [any NotchFeature]
    @ObservationIgnored private var timers: [Deadline: Task<Void, Never>] = [:]

    public init(features: [any NotchFeature] = []) {
        self.features = features
    }

    public func send(_ event: NotchEvent) {
        let signpostID = Log.signposter.makeSignpostID()
        let interval = Log.signposter.beginInterval(
            "event", id: signpostID, "\(String(describing: event), privacy: .public)")
        defer { Log.signposter.endInterval("event", interval) }

        // A deadline event consumes its timer, whether the timer fired or a test injected it.
        if case .deadline(let deadline) = event { timers.removeValue(forKey: deadline)?.cancel() }

        let old = state
        var new = old
        let effects = new.handle(event)
        if new != old { state = new }
        if new.presentation != old.presentation {
            Log.state.debug(
                "\(String(describing: event), privacy: .public): \(String(describing: old.presentation), privacy: .public) → \(String(describing: new.presentation), privacy: .public)"
            )
            updateFeatures(for: new.presentation)
            onPresentationChange?(old.presentation, new.presentation)
        }
        for effect in effects { run(effect) }
    }

    /// Deadlines with a live timer.
    var pendingDeadlines: Set<Deadline> { Set(timers.keys) }

    private func updateFeatures(for presentation: NotchPresentationState) {
        for feature in features {
            let phase = presentation.phase(for: feature.id)
            guard feature.phase != phase else { continue }
            Log.features.debug(
                "\(feature.id.rawValue, privacy: .public): \(String(describing: feature.phase), privacy: .public) → \(String(describing: phase), privacy: .public)"
            )
            let signpostID = Log.signposter.makeSignpostID()
            Log.signposter.withIntervalSignpost(
                "feature phase", id: signpostID, "\(feature.id.rawValue, privacy: .public)"
            ) {
                feature.phase = phase
            }
        }
    }

    private func run(_ effect: NotchEffect) {
        switch effect {
        case .schedule(let deadline, let delay):
            timers[deadline]?.cancel()
            timers[deadline] = Task { [weak self] in
                // Tolerance lets macOS coalesce this wakeup with other timers (Apple's energy guidance).
                try? await Task.sleep(for: delay, tolerance: delay / 10)
                guard !Task.isCancelled else { return }
                self?.send(.deadline(deadline))
            }
        case .cancel(let deadline):
            timers.removeValue(forKey: deadline)?.cancel()
        }
    }
}
