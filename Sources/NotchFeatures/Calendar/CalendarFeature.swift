// SPDX-License-Identifier: MIT
import AppKit
import EventKit
import NotchCore
import Observation
import SwiftUI

/// One event on today's agenda, copied out of EventKit so it can cross threads.
public struct DayEvent: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var color: RGB?

    init(_ event: EKEvent) {
        // Recurring events share an identifier, so the start date keeps occurrences apart.
        id = "\(event.calendarItemIdentifier)@\(event.startDate.timeIntervalSince1970)"
        title = event.title ?? "Untitled"
        start = event.startDate
        end = event.endDate
        isAllDay = event.isAllDay
        color = RGB(event.calendar?.cgColor)
    }

    init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false, color: RGB? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.color = color
    }

    /// All-day events first, then by start time.
    static func agendaOrder(_ lhs: DayEvent, _ rhs: DayEvent) -> Bool {
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
        return (lhs.start, lhs.title) < (rhs.start, rhs.title)
    }
}

/// Today's events from the user's calendars. It asks for access only when the user taps the
/// button, and reads (one bounded day-long query) only while the tab is on screen, refreshing on
/// EventKit's change notification rather than polling.
@MainActor
@Observable
public final class CalendarFeature: NotchFeature {
    public let id = FeatureID.calendar
    public var phase: FeaturePhase = .stopped {
        didSet {
            guard phase != oldValue else { return }
            phase == .foreground ? activate() : deactivate()
        }
    }
    public private(set) var access = EventAccess(.event)
    public private(set) var events: [DayEvent] = []
    /// Per-feature setting: include all-day events.
    public var showsAllDay: Bool {
        didSet {
            defaults.set(showsAllDay, forKey: Self.allDayKey)
            reload()
        }
    }

    private static let allDayKey = "calendar.showsAllDay"
    @ObservationIgnored private let eventStore: EventStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var changes: NSObjectProtocol?

    public init(eventStore: EventStore, defaults: UserDefaults = .standard) {
        self.eventStore = eventStore
        self.defaults = defaults
        showsAllDay = defaults.object(forKey: Self.allDayKey) as? Bool ?? true
    }

    public var view: some View { CalendarView(calendar: self) }

    /// Whether the feature is listening for calendar changes.
    var isObserving: Bool { changes != nil }

    public func requestAccess() {
        eventStore.store.requestFullAccessToEvents { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.access = EventAccess(.event)
                if self.phase == .foreground { self.activate() }
            }
        }
    }

    public func openCalendarApp() {
        let workspace = NSWorkspace.shared
        guard let app = workspace.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        workspace.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
    }

    private func activate() {
        access = EventAccess(.event)  // it may have changed in System Settings
        guard access == .granted else { return }
        if changes == nil {
            changes = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged, object: eventStore.store, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reload() }
            }
        }
        reload()
    }

    private func deactivate() {
        if let changes { NotificationCenter.default.removeObserver(changes) }
        changes = nil
        events = []
    }

    private func reload() {
        guard access == .granted, phase == .foreground else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let store = eventStore.store
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .map(DayEvent.init)
            .filter { showsAllDay || !$0.isAllDay }
            .sorted(by: DayEvent.agendaOrder)
    }
}
