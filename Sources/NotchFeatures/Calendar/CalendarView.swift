// SPDX-License-Identifier: MIT
import SwiftUI

/// The calendar tab: today's agenda, with past events dimmed and a Join button on events with a
/// video call that hasn't ended, the tasks due today beneath it, and a field that adds an event
/// from a line like "Lunch with Sam tomorrow 1pm".
struct CalendarView: View {
    let calendar: CalendarFeature
    @State private var draft = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if calendar.access != .granted {
            EventAccessView(
                access: calendar.access, symbol: "calendar", what: "calendars", settingsPane: "Privacy_Calendars",
                request: calendar.requestAccess)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button(action: calendar.openCalendarApp) {
                        Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    }
                    .buttonStyle(.plain)
                    .help("Open Calendar")
                    Spacer(minLength: 0)
                    if let notice = calendar.notice {
                        Text(notice).lineLimit(1).transition(.opacity)
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: calendar.notice)
                if calendar.events.isEmpty, calendar.dueTasks.isEmpty {
                    FeatureUnavailableView(symbol: "calendar", title: "Nothing today", message: "Enjoy the free time.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(calendar.events) { event in row(event) }
                            if !calendar.dueTasks.isEmpty {
                                Text("Tasks")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(.top, calendar.events.isEmpty ? 0 : 6)
                                    .accessibilityAddTraits(.isHeader)
                                ForEach(calendar.dueTasks) { task in taskRow(task) }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .fadingEdges()
                }
                TextField("New event: try \u{201C}Lunch tomorrow 1pm for 1h\u{201D}", text: $draft)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                    .onSubmit {
                        // Text without a time stays in the field so it can be finished.
                        if calendar.addEvent(draft) { draft = "" }
                    }
            }
        }
    }

    private func row(_ event: DayEvent) -> some View {
        let past = !event.isAllDay && event.end < .now
        let joinable = event.meeting != nil && !past && !event.isDeclined
        return HStack(spacing: 8) {
            Capsule()
                .fill(event.color?.color ?? .white)
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.callout.weight(.medium)).lineLimit(1)
                Group {
                    if event.isAllDay {
                        Text("All day")
                    } else {
                        Text(event.start, format: .dateTime.hour().minute()) + Text(" – ")
                            + Text(event.end, format: .dateTime.hour().minute())
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            if joinable, let meeting = event.meeting {
                joinButton(event, meeting: meeting)
            }
        }
        .opacity(past ? 0.45 : 1)
        .contentShape(Rectangle())
        .contextMenu {
            if let meeting = event.meeting {
                Button("Join \(meeting.service)") { calendar.join(event) }.disabled(!joinable)
                Button("Copy Link") { calendar.copyLink(event) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if joinable { Button("Join") { calendar.join(event) } }
        }
    }

    /// Stands out while the meeting's countdown is on.
    private func joinButton(_ event: DayEvent, meeting: MeetingLink) -> some View {
        let soon = calendar.countingDown?.id == event.id
        return Button {
            calendar.join(event)
        } label: {
            Label("Join", systemImage: "video.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(soon ? Color.green.opacity(0.85) : .white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Join on \(meeting.service). Right-click to copy the link.")
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                    calendar.complete(task)
                }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(task.color?.color ?? .white)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(task.title)")
            Text(task.title).font(.callout).lineLimit(1)
            Spacer(minLength: 0)
            if let due = task.due {
                Text(DueLabel.text(for: due, hasTime: task.hasTime))
                    .font(.caption)
                    .foregroundStyle(task.isOverdue() ? Color.red : .white.opacity(0.55))
            }
        }
        .transition(.opacity)
    }
}
