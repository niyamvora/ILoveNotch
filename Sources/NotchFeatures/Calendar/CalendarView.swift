// SPDX-License-Identifier: MIT
import SwiftUI

/// The calendar tab: today's agenda, with past events dimmed.
struct CalendarView: View {
    let calendar: CalendarFeature

    var body: some View {
        if calendar.access != .granted {
            EventAccessView(
                access: calendar.access, symbol: "calendar", what: "calendars", settingsPane: "Privacy_Calendars",
                request: calendar.requestAccess)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: calendar.openCalendarApp) {
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Open Calendar")
                if calendar.events.isEmpty {
                    FeatureUnavailableView(symbol: "calendar", title: "Nothing today", message: "Enjoy the free time.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(calendar.events) { event in row(event) }
                        }
                    }
                }
            }
        }
    }

    private func row(_ event: DayEvent) -> some View {
        let past = !event.isAllDay && event.end < .now
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
        }
        .opacity(past ? 0.45 : 1)
        .accessibilityElement(children: .combine)
    }
}
