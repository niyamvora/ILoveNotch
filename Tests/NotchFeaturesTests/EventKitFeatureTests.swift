// SPDX-License-Identifier: MIT
import Foundation
import NotchCore
import Testing

@testable import NotchFeatures

@MainActor
struct EventKitFeatureTests {
    private let defaults = UserDefaults(suiteName: "EventKitTests.\(UUID().uuidString)")!
    private let noon = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func theAgendaListsAllDayEventsFirstThenByTime() {
        let events = [
            DayEvent(id: "c", title: "Lunch", start: noon, end: noon + 3600),
            DayEvent(id: "a", title: "Holiday", start: noon - 43_200, end: noon + 43_200, isAllDay: true),
            DayEvent(id: "b", title: "Standup", start: noon - 7200, end: noon - 6300),
        ]
        #expect(events.sorted(by: DayEvent.agendaOrder).map(\.title) == ["Holiday", "Standup", "Lunch"])
    }

    @Test func tasksAreSoonestDueFirstAndUndatedLast() {
        let tasks = [
            TaskItem(id: "1", title: "someday"),
            TaskItem(id: "2", title: "tomorrow", due: noon + 86_400),
            TaskItem(id: "3", title: "overdue", due: noon - 86_400),
            TaskItem(id: "4", title: "Also someday"),
        ]
        #expect(tasks.sorted(by: TaskItem.order).map(\.title) == ["overdue", "tomorrow", "Also someday", "someday"])
    }

    @Test func completedTasksAreNewestFirst() {
        let done = [
            TaskItem(id: "1", title: "last week", completed: noon - 604_800),
            TaskItem(id: "2", title: "just now", completed: noon),
            TaskItem(id: "3", title: "yesterday", completed: noon - 86_400),
        ]
        let titles = done.sorted(by: TaskItem.recentlyCompletedFirst).map(\.title)
        #expect(titles == ["just now", "yesterday", "last week"])
    }

    @Test func theCompletedSectionRemembersWhetherItIsOpen() {
        let store = EventStore()
        TasksFeature(eventStore: store, defaults: defaults).showsCompleted = true
        #expect(TasksFeature(eventStore: store, defaults: defaults).showsCompleted)
    }

    @Test func withoutAccessNothingIsReadOrWatched() {
        // Test runners never grant EventKit access, so this is the not-yet-allowed path.
        let store = EventStore()
        let calendar = CalendarFeature(eventStore: store, defaults: defaults)
        let tasks = TasksFeature(eventStore: store, defaults: defaults)
        for feature in [calendar, tasks] as [any NotchFeature] {
            feature.phase = .foreground
        }
        #expect(calendar.access != .granted && calendar.events.isEmpty && !calendar.isObserving)
        #expect(tasks.access != .granted && tasks.tasks.isEmpty && !tasks.isObserving)
    }

    @Test func settingsPersist() {
        let store = EventStore()
        CalendarFeature(eventStore: store, defaults: defaults).showsAllDay = false
        TasksFeature(eventStore: store, defaults: defaults).listID = "work"
        #expect(!CalendarFeature(eventStore: store, defaults: defaults).showsAllDay)
        #expect(TasksFeature(eventStore: store, defaults: defaults).listID == "work")
    }
}
