// SPDX-License-Identifier: MIT
import SwiftUI

/// The tasks tab: open reminders, soonest first, a collapsible section of recently completed ones,
/// and a field to add a task. Typing in the field gives the notch keyboard focus.
struct TasksView: View {
    let tasks: TasksFeature
    @State private var draft = ""
    /// Tasks just ticked: they show a checkmark for a beat before moving to Completed.
    @State private var ticking: Set<TaskItem.ID> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if tasks.access != .granted {
            EventAccessView(
                access: tasks.access, symbol: "checklist", what: "reminders", settingsPane: "Privacy_Reminders",
                request: tasks.requestAccess)
        } else {
            VStack(spacing: 6) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if tasks.tasks.isEmpty {
                            Label("All done", systemImage: "checkmark.circle")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.vertical, 6)
                        }
                        ForEach(tasks.tasks) { task in row(task) }
                        if !tasks.completed.isEmpty { completedSection }
                    }
                    .padding(.vertical, 6)
                }
                .fadingEdges()
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
        let ticked = ticking.contains(task.id)
        return HStack(spacing: 8) {
            Button {
                tick(task)
            } label: {
                Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(task.color?.color ?? .white)
                    .symbolEffect(.bounce, value: ticked)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(task.title)")
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title).font(.callout).lineLimit(1).opacity(ticked ? 0.5 : 1)
                if let due = task.due {
                    Text(due, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(due < .now ? Color.red : .white.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .move(edge: .bottom))))
    }

    private var completedSection: some View {
        Group {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                    tasks.showsCompleted.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(tasks.showsCompleted ? 90 : 0))
                    Text("Completed")
                    Text("\(tasks.completed.count)").foregroundStyle(.white.opacity(0.45))
                    Spacer(minLength: 0)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 10)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Completed, \(tasks.completed.count) tasks")
            .accessibilityValue(tasks.showsCompleted ? "Expanded" : "Collapsed")
            if tasks.showsCompleted {
                ForEach(tasks.completed) { task in completedRow(task) }
            }
        }
    }

    private func completedRow(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) { tasks.reopen(task) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle((task.color?.color ?? .white).opacity(0.6))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reopen \(task.title)")
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title).font(.callout).strikethrough().lineLimit(1)
                if let done = task.completed, done != .distantPast {
                    Text(done, format: .relative(presentation: .named)).font(.caption)
                }
            }
            .foregroundStyle(.white.opacity(0.45))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// Shows the checkmark for a beat, then moves the task to Completed.
    private func tick(_ task: TaskItem) {
        ticking.insert(task.id)
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 350))
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                tasks.complete(task)
            }
            ticking.remove(task.id)
        }
    }
}
