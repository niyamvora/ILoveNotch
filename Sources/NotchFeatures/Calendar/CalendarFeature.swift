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

/// Today's events from the user's calendars, with the tasks due today beneath them and a field to
/// add an event. It asks for access only when the user taps the button, and reads (one bounded
/// day-long query, plus one for due reminders when Reminders access is already allowed) only while
/// the tab is on screen, refreshing on EventKit's change notification rather than polling.
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
    /// Open reminders due today or overdue, when Reminders access is allowed.
    public private(set) var dueTasks: [TaskItem] = []
    /// A short confirmation or problem after adding an event. Clears itself.
    public private(set) var notice: String?
    /// Per-feature setting: include all-day events.
    public var showsAllDay: Bool {
        didSet {
            defaults.set(showsAllDay, forKey: Self.allDayKey)
            reload()
        }
    }
    /// Per-feature setting: list the tasks due today under the events.
    public var showsTasks: Bool {
        didSet {
            defaults.set(showsTasks, forKey: Self.showsTasksKey)
            reload()
        }
    }

    // ponytail: overdue reminders can pile up, so the agenda shows a bounded number.
    static let dueTaskLimit = 20
    private static let allDayKey = "calendar.showsAllDay"
    private static let showsTasksKey = "calendar.showsTasks"
    @ObservationIgnored private let eventStore: EventStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var changes: NSObjectProtocol?
    @ObservationIgnored private var clearNotice: Task<Void, Never>?

    public init(eventStore: EventStore, defaults: UserDefaults = .standard) {
        self.eventStore = eventStore
        self.defaults = defaults
        showsAllDay = defaults.object(forKey: Self.allDayKey) as? Bool ?? true
        showsTasks = defaults.object(forKey: Self.showsTasksKey) as? Bool ?? true
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

    /// Re-reads access, which may have changed in System Settings.
    public func refreshAccess() { access = EventAccess(.event) }

    /// Adds an event typed as "Lunch with Sam tomorrow 1pm for 90 min" to the default calendar.
    /// Returns whether it was added; text without a date or time is left for the user to finish.
    @discardableResult
    public func addEvent(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, access == .granted else { return false }
        guard let draft = EventDraft.parse(text) else {
            show(notice: "Add when it happens, like \u{201C}tomorrow 1pm\u{201D}")
            return false
        }
        let store = eventStore.store
        guard let calendar = store.defaultCalendarForNewEvents else {
            show(notice: "No calendar to add the event to")
            return false
        }
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.calendar = calendar
        event.isAllDay = draft.isAllDay
        event.startDate = draft.start
        event.endDate = draft.start.addingTimeInterval(draft.duration)
        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            Log.features.error("Couldn't add an event: \(error.localizedDescription, privacy: .public)")
            show(notice: "Couldn't add the event")
            return false
        }
        let when = DueLabel.text(for: draft.start, hasTime: !draft.isAllDay)
        show(notice: "Added \u{201C}\(draft.title)\u{201D}, \(when)")
        reload()
        return true
    }

    /// Ticks off a task listed under today's events.
    public func complete(_ task: TaskItem) {
        let store = eventStore.store
        guard let reminder = store.calendarItem(withIdentifier: task.id) as? EKReminder else { return }
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
            dueTasks.removeAll { $0.id == task.id }
        } catch {
            Log.features.error("Couldn't complete a reminder: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Shows the given agenda as if access were granted. For tests and snapshots only.
    func show(events: [DayEvent], dueTasks: [TaskItem]) {
        access = .granted
        self.events = events
        self.dueTasks = dueTasks
    }

    private func show(notice text: String) {
        notice = text
        clearNotice?.cancel()
        clearNotice = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            self?.notice = nil
        }
    }

    public func openCalendarApp() {
        let workspace = NSWorkspace.shared
        guard let app = workspace.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        workspace.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
    }

    private func activate() {
        refreshAccess()
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
        dueTasks = []
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
        // Tasks come along only when Reminders access was already given in the Tasks tab.
        guard showsTasks, EventAccess(.reminder) == .granted else {
            dueTasks = []
            return
        }
        let due = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
        store.fetchReminders(matching: due) { [weak self] reminders in
            let items = (reminders ?? []).map(TaskItem.init).sorted(by: TaskItem.order)
            let bounded = Array(items.prefix(Self.dueTaskLimit))
            Task { @MainActor in
                guard let self, self.phase == .foreground else { return }
                self.dueTasks = bounded
            }
        }
    }
}
