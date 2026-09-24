// SPDX-License-Identifier: MIT
import AppKit
import NotchCore
import Observation
import SwiftUI

/// A countdown: running until `endsAt`, or paused with `remaining` left.
public struct Countdown: Equatable, Sendable {
    public var total: TimeInterval
    /// Set while running.
    public var endsAt: Date?
    /// Time left when paused.
    public var remaining: TimeInterval

    public var isRunning: Bool { endsAt != nil }

    public func remaining(at date: Date) -> TimeInterval {
        endsAt.map { max(0, $0.timeIntervalSince(date)) } ?? remaining
    }
}

/// A stopwatch: the time banked so far plus the current run, if any.
public struct Stopwatch: Equatable, Sendable {
    public private(set) var banked: TimeInterval = 0
    public private(set) var startedAt: Date?
    /// Total elapsed time at each lap, oldest first.
    public private(set) var laps: [TimeInterval] = []

    public init() {}

    public var isRunning: Bool { startedAt != nil }

    public func elapsed(at date: Date) -> TimeInterval {
        banked + (startedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    public mutating func start(at date: Date) {
        if startedAt == nil { startedAt = date }
    }

    public mutating func pause(at date: Date) {
        banked = elapsed(at: date)
        startedAt = nil
    }

    public mutating func lap(at date: Date) { laps.append(elapsed(at: date)) }

    public mutating func reset() { self = Stopwatch() }
}

/// A countdown timer and a stopwatch. Neither needs work to start or stop: a countdown is one
/// wall-clock deadline (never a per-second tick) and the stopwatch is arithmetic, so both keep
/// going across sleep and while the tab is hidden, and the display only ticks while it's on screen.
@MainActor
@Observable
public final class TimerFeature: NotchFeature {
    public enum Mode: Sendable { case countdown, stopwatch }

    public let id = FeatureID.timer
    public var phase: FeaturePhase = .stopped
    public var mode = Mode.countdown
    public private(set) var countdown: Countdown?
    public private(set) var stopwatch = Stopwatch()
    /// Raised when a countdown finishes.
    @ObservationIgnored public var onActivity: ((Activity) -> Void)?
    @ObservationIgnored private var alarm: Task<Void, Never>?

    public static let presets: [TimeInterval] = [60, 180, 300, 600, 900, 1500, 2700, 3600]

    public init() {}

    public var view: some View { TimerView(timer: self) }

    // MARK: Countdown

    public func start(_ seconds: TimeInterval, now: Date = .now) {
        countdown = Countdown(total: seconds, endsAt: now.addingTimeInterval(seconds), remaining: seconds)
        scheduleAlarm()
    }

    public func pause(now: Date = .now) {
        guard var countdown, countdown.isRunning else { return }
        countdown.remaining = countdown.remaining(at: now)
        countdown.endsAt = nil
        self.countdown = countdown
        alarm?.cancel()
    }

    public func resume(now: Date = .now) {
        guard var countdown, !countdown.isRunning else { return }
        countdown.endsAt = now.addingTimeInterval(countdown.remaining)
        self.countdown = countdown
        scheduleAlarm()
    }

    public func addMinute() {
        guard var countdown else { return }
        countdown.total += 60
        countdown.remaining += 60
        countdown.endsAt = countdown.endsAt?.addingTimeInterval(60)
        self.countdown = countdown
        scheduleAlarm()
    }

    public func cancel() {
        alarm?.cancel()
        countdown = nil
    }

    /// Whether a countdown is waiting to ring.
    var alarmPending: Bool { alarm.map { !$0.isCancelled } ?? false }

    private func scheduleAlarm() {
        alarm?.cancel()
        guard let end = countdown?.endsAt else { return }
        let delay = max(0, end.timeIntervalSinceNow)
        alarm = Task { [weak self] in
            // The continuous clock keeps counting through sleep, so a countdown that ends while the
            // Mac sleeps rings on wake instead of drifting.
            do { try await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(250)) } catch { return }
            self?.ring()
        }
    }

    func ring() {
        alarm = nil
        countdown = nil
        NSSound(named: "Glass")?.play()
        onActivity?(Activity(feature: .timer, symbol: "timer", title: "Timer done", duration: .seconds(4)))
    }

    // MARK: Stopwatch

    public func toggleStopwatch(now: Date = .now) {
        if stopwatch.isRunning { stopwatch.pause(at: now) } else { stopwatch.start(at: now) }
    }

    public func lap(now: Date = .now) { stopwatch.lap(at: now) }

    public func resetStopwatch() { stopwatch.reset() }
}

/// "1:05" or "1:02:03"; with `tenths`, "1:05.3". Countdowns round whole seconds up, so 0:00 means
/// done; counters round down, so elapsed plus remaining always adds up.
func formatTime(_ seconds: TimeInterval, tenths: Bool = false, roundingUp: Bool = true) -> String {
    let total = max(0, seconds)
    let whole = Int(tenths ? total : total.rounded(roundingUp ? .up : .down))
    let (hours, minutes, secs) = (whole / 3600, whole / 60 % 60, whole % 60)
    var text = String(format: "%d:%02d", minutes, secs)
    if hours > 0 { text = String(format: "%d:%02d:%02d", hours, minutes, secs) }
    if tenths { text += String(format: ".%d", Int((total * 10).rounded(.down)) % 10) }
    return text
}
