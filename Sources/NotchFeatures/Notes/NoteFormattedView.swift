// SPDX-License-Identifier: MIT
import SwiftUI

/// A note drawn as formatted Markdown: headings, lists, quotes, rules, and inline styles and links.
/// Checkboxes tick in place, and hovering an unticked one offers to send it to Tasks.
struct NoteFormattedView: View {
    let note: Note
    /// Ticks or unticks the checkbox on a line.
    let toggle: (Int) -> Void
    /// Sends the checklist item on a line to Tasks.
    let send: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(NoteLine.parse(note.text)) { line in
                    view(for: line)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
        .textSelection(.enabled)
        .accessibilityLabel("Formatted note")
    }

    @ViewBuilder private func view(for line: NoteLine) -> some View {
        switch line.kind {
        case .heading(let level, let text):
            Self.inline(text)
                .font(Self.headingFont(level))
                .padding(.top, 2)
                .accessibilityAddTraits(.isHeader)
        case .task(let done, let text):
            ChecklistLine(
                text: text, done: done, toggle: { toggle(line.id) }, send: { send(line.id) })
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\u{2022}").foregroundStyle(.white.opacity(0.6))
                Self.inline(text)
            }
        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).").monospacedDigit().foregroundStyle(.white.opacity(0.6))
                Self.inline(text)
            }
        case .quote(let text):
            HStack(spacing: 6) {
                Capsule().fill(.white.opacity(0.35)).frame(width: 2)
                Self.inline(text).italic().foregroundStyle(.white.opacity(0.75))
            }
            .fixedSize(horizontal: false, vertical: true)
        case .rule:
            Divider().overlay(.white.opacity(0.25)).padding(.vertical, 3)
        case .text(let text):
            Self.inline(text)
        case .blank:
            Color.clear.frame(height: 4)
        }
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .headline
        case 2: .subheadline.weight(.bold)
        default: .callout.weight(.semibold)
        }
    }

    /// Inline Markdown (bold, italics, code, links), or the plain text if it doesn't parse.
    static func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let attributed = try? AttributedString(markdown: text, options: options) else {
            return Text(verbatim: text)
        }
        return Text(attributed)
    }
}

/// A checklist item: a checkbox that ticks it, and, on hover, a button that sends it to Tasks.
private struct ChecklistLine: View {
    let text: String
    let done: Bool
    let toggle: () -> Void
    let send: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) { toggle() }
            } label: {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .foregroundStyle(done ? Color.green : .white.opacity(0.7))
                    .symbolEffect(.bounce, value: done)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Untick \(text)" : "Tick \(text)")
            NoteFormattedView.inline(text)
                .strikethrough(done)
                .opacity(done ? 0.5 : 1)
            Spacer(minLength: 0)
            if hovering, !done {
                Button(action: send) {
                    Label("To Tasks", systemImage: "arrow.up.forward.square")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.75))
                .help("Add this item to Tasks")
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { hovering = inside }
        }
        .accessibilityAction(named: "Send to Tasks", send)
    }
}
