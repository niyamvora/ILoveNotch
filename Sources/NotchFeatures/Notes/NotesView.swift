// SPDX-License-Identifier: MIT
import SwiftUI

/// The notes tab: a list of notes beside an editor. Clicking into the editor gives the notch
/// keyboard focus; Escape or clicking elsewhere hands it back.
struct NotesView: View {
    let notes: NotesFeature

    var body: some View {
        if notes.notes.isEmpty {
            FeatureUnavailableView(
                symbol: "note.text",
                title: "No notes yet",
                message: "Jot something down. Notes stay on this Mac as plain text.",
                action: (label: "New Note", perform: { notes.add() }))
        } else {
            HStack(spacing: 10) {
                list.frame(width: 128)
                editor
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                notes.add()
            } label: {
                Label("New Note", systemImage: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .padding(.bottom, 2)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(notes.notes) { note in
                        Button {
                            notes.selection = note.id
                        } label: {
                            Text(note.title)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    notes.selection == note.id ? .white.opacity(0.14) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(notes.selection == note.id ? .isSelected : [])
                        .contextMenu {
                            Button("Delete Note", role: .destructive) { notes.delete(note.id) }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .fadingEdges()
        }
    }

    @ViewBuilder private var editor: some View {
        if let note = notes.selected {
            TextEditor(text: Binding(get: { note.text }, set: { notes.update(note.id, text: $0) }))
                .font(.callout)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Note text")
        }
    }
}
