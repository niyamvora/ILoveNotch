// SPDX-License-Identifier: MIT
import SwiftUI

// Per-feature settings, shown under each feature's toggle in the Settings window.

extension MediaFeature {
    public var settingsView: some View {
        @Bindable var media = self
        return Toggle("Show track changes as a live activity", isOn: $media.announcesTracks)
    }
}

extension CalendarFeature {
    public var settingsView: some View {
        @Bindable var calendar = self
        return Group {
            AccessRow(access: calendar.access, pane: "Privacy_Calendars", request: calendar.requestAccess)
            Toggle("Show all-day events", isOn: $calendar.showsAllDay)
        }
        .onAppear(perform: calendar.refreshAccess)
    }
}

extension TasksFeature {
    public var settingsView: some View {
        @Bindable var tasks = self
        return Group {
            AccessRow(access: tasks.access, pane: "Privacy_Reminders", request: tasks.requestAccess)
            Picker("List", selection: $tasks.listID) {
                Text("All lists").tag(String?.none)
                ForEach(tasks.lists) { list in
                    Text(list.title).tag(String?.some(list.id))
                }
            }
            .help("New tasks go to this list, or to your default list when showing all lists.")
        }
        .onAppear {
            tasks.refreshAccess()
            tasks.loadLists()
        }
    }
}

/// EventKit access at a glance, with the next step when it isn't allowed.
private struct AccessRow: View {
    let access: EventAccess
    let pane: String
    let request: () -> Void

    var body: some View {
        LabeledContent("Access") {
            switch access {
            case .granted:
                Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .notDetermined:
                Button("Allow Access", action: request)
            case .denied:
                Button("Open Privacy Settings") { NSWorkspace.shared.open(.privacySettings(pane)) }
            }
        }
    }
}

extension ShortcutsFeature {
    public var settingsView: some View {
        ShortcutsSettings(shortcuts: self)
    }
}

extension ShelfFeature {
    public var settingsView: some View {
        LabeledContent(items.count == 1 ? "1 item on the shelf" : "\(items.count) items on the shelf") {
            Button("Clear Shelf", role: .destructive, action: removeAll).disabled(items.isEmpty)
        }
    }
}

private struct ShortcutsSettings: View {
    @Bindable var shortcuts: ShortcutsFeature

    var body: some View {
        Group {
            if shortcuts.shortcuts.isEmpty {
                Text("Shortcuts you make in the Shortcuts app appear here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shortcuts.shortcuts, id: \.self) { name in
                    Toggle(
                        name,
                        isOn: Binding(
                            get: { !shortcuts.hidden.contains(name) },
                            set: { shown in
                                if shown { shortcuts.hidden.remove(name) } else { shortcuts.hidden.insert(name) }
                            }))
                }
            }
        }
        .onAppear(perform: shortcuts.refresh)
    }
}
