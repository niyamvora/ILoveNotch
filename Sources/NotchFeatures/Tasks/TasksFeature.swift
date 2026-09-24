// SPDX-License-Identifier: MIT
import EventKit
import NotchCore
import Observation
import SwiftUI

/// One reminder, copied out of EventKit so it can cross threads.
public struct TaskItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var due: Date?
    /// When it was completed; nil while it's open.
    public var completed: Date?
    public var color: RGB?

    init(_ reminder: EKReminder) {
        id = reminder.calendarItemIdentifier
        title = reminder.title ?? "Untitled"
        due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        completed = reminder.isCompleted ? reminder.completionDate ?? .distantPast : nil
        color = RGB(reminder.calendar?.cgColor)
    }

    init(id: String, title: String, due: Date? = nil, completed: Date? = nil) {
        self.id = id
        self.title = title
        self.due = due
        self.completed = completed
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

    /// Most recently completed first.
    static func recentlyCompletedFirst(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        (lhs.completed ?? .distantPast) > (rhs.completed ?? .distantPast)
    }
}

/// A Reminders list the user can pick in settings.
public struct ReminderList: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
}

/// Reminders from Apple Reminders, so tasks sync to the iPhone over iCloud with no server: the open
/// ones, plus a collapsible section of recently completed ones. Access is asked for only on tap;
/// reads happen only while the tab is on screen and refresh on EventKit's change notification.
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
    /// Completed in the last `completedWindow`, newest first, at most `completedLimit`.
    public private(set) var completed: [TaskItem] = []
    public private(set) var lists: [ReminderList] = []
    /// Per-feature setting: the list to show and add to. Nil shows every list and adds to the default.
    public var listID: String? {
        didSet {
            defaults.set(listID, forKey: Self.listKey)
            reload()
        }
    }
    /// Whether the completed section is expanded.
    public var showsCompleted: Bool {
        didSet { defaults.set(showsCompleted, forKey: Self.showsCompletedKey) }
    }

    // ponytail: completed tasks are bounded by age and count so years of history can't flood the notch.
    static let completedWindow = 30  // days
    static let completedLimit = 50
    private static let listKey = "tasks.listID"
    private static let showsCompletedKey = "tasks.showsCompleted"
    @ObservationIgnored private let eventStore: EventStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var changes: NSObjectProtocol?

    public init(eventStore: EventStore, defaults: UserDefaults = .standard) {
        self.eventStore = eventStore
        self.defaults = defaults
        listID = defaults.string(forKey: Self.listKey)
        showsCompleted = defaults.bool(forKey: Self.showsCompletedKey)
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

    /// Marks a task done; it moves to the completed section.
    public func complete(_ task: TaskItem) {
        guard save(task, completed: true) else { return }
        tasks.removeAll { $0.id == task.id }
        var done = task
        done.completed = .now
        completed.insert(done, at: 0)
    }

    /// Marks a completed task open again.
    public func reopen(_ task: TaskItem) {
        guard save(task, completed: false) else { return }
        completed.removeAll { $0.id == task.id }
        var open = task
        open.completed = nil
        tasks = (tasks + [open]).sorted(by: TaskItem.order)
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

    /// Loads the Reminders lists, for the settings picker as well as the tab.
    public func loadLists() {
        guard EventAccess(.reminder) == .granted else { return }
        lists = eventStore.store.calendars(for: .reminder)
            .map { ReminderList(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Shows the given tasks as if access were granted. For tests and snapshots only.
    func show(tasks: [TaskItem], completed: [TaskItem]) {
        access = .granted
        self.tasks = tasks
        self.completed = completed
    }

    private func save(_ task: TaskItem, completed: Bool) -> Bool {
        let store = eventStore.store
        guard let reminder = store.calendarItem(withIdentifier: task.id) as? EKReminder else { return false }
        reminder.isCompleted = completed
        do {
            try store.save(reminder, commit: true)
            return true
        } catch {
            Log.features.error("Couldn't update a reminder: \(error.localizedDescription, privacy: .public)")
            return false
        }
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
        tasks = []
        completed = []
    }

    private func reload() {
        guard access == .granted, phase == .foreground else { return }
        let store = eventStore.store
        loadLists()
        let chosen = listID.flatMap(store.calendar(withIdentifier:)).map { [$0] }
        let open = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: chosen)
        store.fetchReminders(matching: open) { [weak self] reminders in
            let items = (reminders ?? []).map(TaskItem.init).sorted(by: TaskItem.order)
            Task { @MainActor in
                // Results that land after the tab went away are dropped, not kept in memory.
                guard let self, self.phase == .foreground else { return }
                self.tasks = items
            }
        }
        let since = Calendar.current.date(byAdding: .day, value: -Self.completedWindow, to: .now)
        let done = store.predicateForCompletedReminders(
            withCompletionDateStarting: since, ending: nil, calendars: chosen)
        store.fetchReminders(matching: done) { [weak self] reminders in
            let items = (reminders ?? []).map(TaskItem.init).sorted(by: TaskItem.recentlyCompletedFirst)
            let recent = Array(items.prefix(Self.completedLimit))
            Task { @MainActor in
                guard let self, self.phase == .foreground else { return }
                self.completed = recent
            }
        }
    }
}
