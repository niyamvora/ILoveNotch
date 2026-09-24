// SPDX-License-Identifier: MIT
import EventKit
import NotchCore
import Observation
import SwiftUI

/// One open reminder, copied out of EventKit so it can cross threads.
public struct TaskItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var due: Date?
    public var color: RGB?

    init(_ reminder: EKReminder) {
        id = reminder.calendarItemIdentifier
        title = reminder.title ?? "Untitled"
        due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        color = RGB(reminder.calendar?.cgColor)
    }

    init(id: String, title: String, due: Date? = nil) {
        self.id = id
        self.title = title
        self.due = due
    }

    /// Soonest due first, undated last, then by title.
    static func order(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        switch (lhs.due, rhs.due) {
        case (let left?, let right?) where left != right: left < right
        case (.some, nil): true
        case (nil, .some): false
        default: lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}

/// A Reminders list the user can pick in settings.
public struct ReminderList: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
}

/// Open reminders from Apple Reminders, so tasks sync to the iPhone over iCloud with no server.
/// Access is asked for only on tap; reads happen only while the tab is on screen and refresh on
/// EventKit's change notification.
@MainActor
@Observable
public final class TasksFeature: NotchFeature {
    public let id = FeatureID.tasks
    public var phase: FeaturePhase = .stopped {
        didSet {
            guard phase != oldValue else { return }
            phase == .foreground ? activate() : deactivate()
        }
    }
    public private(set) var access = EventAccess(.reminder)
    public private(set) var tasks: [TaskItem] = []
    public private(set) var lists: [ReminderList] = []
    /// Per-feature setting: the list to show and add to. Nil shows every list and adds to the default.
    public var listID: String? {
        didSet {
            defaults.set(listID, forKey: Self.listKey)
            reload()
        }
    }

    private static let listKey = "tasks.listID"
    @ObservationIgnored private let eventStore: EventStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var changes: NSObjectProtocol?

    public init(eventStore: EventStore, defaults: UserDefaults = .standard) {
        self.eventStore = eventStore
        self.defaults = defaults
        listID = defaults.string(forKey: Self.listKey)
    }

    public var view: some View { TasksView(tasks: self) }

    /// Whether the feature is listening for reminder changes.
    var isObserving: Bool { changes != nil }

    public func requestAccess() {
        eventStore.store.requestFullAccessToReminders { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.access = EventAccess(.reminder)
                if self.phase == .foreground { self.activate() }
            }
        }
    }

    public func complete(_ task: TaskItem) {
        let store = eventStore.store
        guard let reminder = store.calendarItem(withIdentifier: task.id) as? EKReminder else { return }
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
            tasks.removeAll { $0.id == task.id }
        } catch {
            Log.features.error("Couldn't complete a reminder: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func add(_ title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let store = eventStore.store
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = listID.flatMap(store.calendar(withIdentifier:)) ?? store.defaultCalendarForNewReminders()
        do {
            try store.save(reminder, commit: true)
        } catch {
            Log.features.error("Couldn't add a reminder: \(error.localizedDescription, privacy: .public)")
        }
        reload()
    }

    /// Re-reads access, which may have changed in System Settings.
    public func refreshAccess() { access = EventAccess(.reminder) }

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
        tasks = []
    }

    /// Loads the Reminders lists, for the settings picker as well as the tab.
    public func loadLists() {
        guard EventAccess(.reminder) == .granted else { return }
        lists = eventStore.store.calendars(for: .reminder)
            .map { ReminderList(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func reload() {
        guard access == .granted, phase == .foreground else { return }
        let store = eventStore.store
        loadLists()
        let chosen = listID.flatMap(store.calendar(withIdentifier:)).map { [$0] }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: chosen)
        store.fetchReminders(matching: predicate) { [weak self] reminders in
            let items = (reminders ?? []).map(TaskItem.init).sorted(by: TaskItem.order)
            Task { @MainActor in
                // Results that land after the tab went away are dropped, not kept in memory.
                guard let self, self.phase == .foreground else { return }
                self.tasks = items
            }
        }
    }
}
