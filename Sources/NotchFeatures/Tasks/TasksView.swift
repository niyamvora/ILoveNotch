// SPDX-License-Identifier: MIT
import SwiftUI

/// The tasks tab: open reminders, soonest first, and a field to add one. Typing in the field gives
/// the notch keyboard focus.
struct TasksView: View {
    let tasks: TasksFeature
    @State private var draft = ""

    var body: some View {
        if tasks.access != .granted {
            EventAccessView(
                access: tasks.access, symbol: "checklist", what: "reminders", settingsPane: "Privacy_Reminders",
                request: tasks.requestAccess)
        } else {
            VStack(spacing: 6) {
                if tasks.tasks.isEmpty {
                    FeatureUnavailableView(symbol: "checkmark.circle", title: "All done", message: "Add a task below.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(tasks.tasks) { task in row(task) }
                        }
                    }
                }
                TextField("New task", text: $draft)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                    .onSubmit {
                        tasks.add(draft)
                        draft = ""
                    }
            }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { tasks.complete(task) }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(task.color?.color ?? .white)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(task.title)")
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title).font(.callout).lineLimit(1)
                if let due = task.due {
                    Text(due, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(due < .now ? Color.red : .white.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }
}
