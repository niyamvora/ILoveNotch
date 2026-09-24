// SPDX-License-Identifier: MIT
import Observation

/// Runs one display's notch on the main actor: feeds events through the reducer and runs its
/// deadline effects on cancellable one-shot timers (never a polling loop).
@MainActor
@Observable
public final class NotchEngine {
    public private(set) var state = NotchState()

    /// Called after every presentation change, for example to update the panel and the features.
    @ObservationIgnored
    public var onPresentationChange: ((_ old: NotchPresentationState, _ new: NotchPresentationState) -> Void)?

    @ObservationIgnored private var timers: [Deadline: Task<Void, Never>] = [:]

    public init() {}

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
            onPresentationChange?(old.presentation, new.presentation)
        }
        for effect in effects { run(effect) }
    }

    /// Deadlines with a live timer.
    var pendingDeadlines: Set<Deadline> { Set(timers.keys) }

    private func run(_ effect: NotchEffect) {
        switch effect {
        case .schedule(let deadline, let delay):
            timers[deadline]?.cancel()
            // Sleep off the main actor so a cancelled timer never wakes the main thread; only a timer
            // that fires hops back. Tolerance lets macOS coalesce the wakeup (Apple's energy guidance).
            timers[deadline] = Task.detached { [weak self] in
                do { try await Task.sleep(for: delay, tolerance: delay / 10) } catch { return }
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self?.send(.deadline(deadline))
                }
            }
        case .cancel(let deadline):
            timers.removeValue(forKey: deadline)?.cancel()
        }
    }
}
