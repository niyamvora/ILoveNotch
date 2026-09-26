// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

/// The notes tab: a searchable list of notes beside an editor. Hovering a note lights it up and shows
/// its pin and delete buttons; the selection slides between notes. The editor can show the note
/// formatted, with checkboxes to tick and send to Tasks. Clicking into a field gives the notch
/// keyboard focus; Escape or clicking elsewhere hands it back.
struct NotesView: View {
    @Bindable var notes: NotesFeature
    @Namespace private var selectionSpace
    @FocusState private var editorFocused: Bool
    @State private var showsPalette = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if notes.notes.isEmpty {
            FeatureUnavailableView(
                symbol: "note.text",
                title: "No notes yet",
                message: notes.usesCustomFolder
                    ? "Jot something down. Notes are saved as Markdown in \(notes.directory.lastPathComponent)."
                    : "Jot something down. Notes stay on this Mac as plain text.",
                action: (label: "New Note", perform: { notes.add() }))
        } else {
            HStack(spacing: 10) {
                list.frame(width: 136)
                editor
            }
            .onAppear(perform: takeFocusIfWanted)
            .onChange(of: notes.wantsEditorFocus) { _, _ in takeFocusIfWanted() }
        }
    }

    /// Puts the cursor in the editor after the quick note shortcut, once the editor is on screen.
    private func takeFocusIfWanted() {
        guard notes.wantsEditorFocus else { return }
        Task { @MainActor in
            editorFocused = true
            notes.editorTookFocus()
        }
    }

    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.82) }

    // MARK: List

    private var list: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                HStack(spacing: 3) {
                    Image(systemName: "magnifyingglass").font(.system(size: 9, weight: .semibold)).opacity(0.5)
                    TextField("Search", text: $notes.search).textFieldStyle(.plain)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                Menu {
                    Picker("Sort By", selection: $notes.sort) {
                        ForEach(NoteSort.allCases) { sort in Text(sort.name).tag(sort) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Sort notes")
                Button {
                    withAnimation(spring) { _ = notes.add() }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.plain)
                .help("New note")
                .accessibilityLabel("New Note")
            }
            .font(.caption)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(notes.visibleNotes) { note in
                        NoteRow(
                            notes: notes, note: note, isSelected: notes.selection == note.id,
                            selectionSpace: selectionSpace,
                            select: { withAnimation(spring) { notes.selection = note.id } })
                    }
                    if notes.visibleNotes.isEmpty {
                        Text("No matches").font(.caption).foregroundStyle(.white.opacity(0.5)).padding(6)
                    }
                }
                .padding(.vertical, 6)
            }
            .fadingEdges()
        }
    }

    // MARK: Editor

    @ViewBuilder private var editor: some View {
        if let note = notes.selected {
            VStack(alignment: .leading, spacing: 4) {
                toolbar(note)
                Group {
                    if notes.showsFormatted {
                        NoteFormattedView(
                            note: note, toggle: { notes.toggleTask(note.id, line: $0) },
                            send: { _ = notes.sendToTasks(note.id, line: $0) }
                        )
                        .onTapGesture(count: 2) { withAnimation(spring) { notes.showsFormatted = false } }
                    } else {
                        TextEditor(text: Binding(get: { note.text }, set: { notes.update(note.id, text: $0) }))
                            .font(.callout)
                            .scrollContentBackground(.hidden)
                            .focused($editorFocused)
                            .accessibilityLabel("Note text")
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(tint(note.color), in: RoundedRectangle(cornerRadius: 8))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: note.color)
                footer(note)
            }
        }
    }

    private func tint(_ color: NoteColor?) -> Color {
        guard let color else { return .white.opacity(0.06) }
        return color.swatch.opacity(0.18)
    }

    private func toolbar(_ note: Note) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(spring) { showsPalette.toggle() }
            } label: {
                Circle()
                    .fill(note.color?.swatch ?? .white.opacity(0.35))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            }
            .help("Color")
            .accessibilityLabel("Color")
            if showsPalette {
                ColorPalette(selected: note.color) { color in
                    notes.setColor(note.id, color)
                    withAnimation(spring) { showsPalette = false }
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            } else {
                ToolbarButton(
                    symbol: note.isPinned ? "pin.fill" : "pin", help: note.isPinned ? "Unpin" : "Pin to top",
                    isOn: note.isPinned
                ) { withAnimation(spring) { notes.togglePin(note.id) } }
                ToolbarButton(
                    symbol: notes.showsFormatted ? "pencil" : "text.badge.checkmark",
                    help: notes.showsFormatted ? "Edit text" : "Show formatted", isOn: notes.showsFormatted
                ) { withAnimation(spring) { notes.showsFormatted.toggle() } }
                if note.hasOpenChecklist {
                    ToolbarButton(symbol: "checklist", help: "Send unticked items to Tasks", isOn: false) {
                        _ = notes.sendToTasks(note.id)
                    }
                    .transition(.opacity)
                }
                Spacer(minLength: 0)
                ShareLink(item: note.text, subject: Text(note.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Share to Notes, Mail, Messages, and more")
                .accessibilityLabel("Share")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.75))
        .frame(height: 16)
    }

    private func footer(_ note: Note) -> some View {
        HStack(spacing: 6) {
            Text(note.wordCount == 1 ? "1 word" : "\(note.wordCount) words")
            Spacer(minLength: 0)
            if let notice = notes.notice {
                Text(notice).foregroundStyle(.white.opacity(0.85)).transition(.opacity)
            } else {
                Text("Edited \(note.modified, format: .relative(presentation: .named))")
            }
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.45))
        .lineLimit(1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: notes.notice)
    }
}

extension NoteColor {
    var swatch: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        }
    }
}

/// One note in the list. The selection highlight slides between rows; hovering shows a lighter
/// highlight, a preview tooltip, and pin and delete buttons.
private struct NoteRow: View {
    let notes: NotesFeature
    let note: Note
    let isSelected: Bool
    let selectionSpace: Namespace.ID
    let select: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            if let color = note.color {
                Circle().fill(color.swatch).frame(width: 6, height: 6)
            }
            Text(note.title)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 0)
            if hovering {
                HStack(spacing: 5) {
                    Button {
                        notes.togglePin(note.id)
                    } label: {
                        Image(systemName: note.isPinned ? "pin.slash" : "pin")
                    }
                    .accessibilityLabel(note.isPinned ? "Unpin" : "Pin")
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { notes.delete(note.id) }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Move to Trash")
                }
                .buttonStyle(.plain)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else if note.isPinned {
                Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.14))
                    .matchedGeometryEffect(id: "selection", in: selectionSpace)
            } else if hovering {
                RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.07))
            }
        }
        .scaleEffect(hovering && !isSelected && !reduceMotion ? 1.02 : 1, anchor: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .onHover { inside in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { hovering = inside }
        }
        .help(tooltip)
        .onDrag {
            notes.fileURL(for: note.id).flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
        }
        .contextMenu {
            Button(note.isPinned ? "Unpin" : "Pin to Top") { notes.togglePin(note.id) }
            Picker("Color", selection: Binding(get: { note.color }, set: { notes.setColor(note.id, $0) })) {
                Text("None").tag(NoteColor?.none)
                ForEach(NoteColor.allCases) { color in Text(color.name).tag(NoteColor?.some(color)) }
            }
            .pickerStyle(.menu)
            if note.hasOpenChecklist {
                Button("Send Unticked Items to Tasks") { _ = notes.sendToTasks(note.id) }
            }
            Button("Show in Finder") {
                if let url = notes.fileURL(for: note.id) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            Divider()
            Button("Move to Trash", role: .destructive) { notes.delete(note.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction(named: note.isPinned ? "Unpin" : "Pin") { notes.togglePin(note.id) }
        .accessibilityAction(named: "Move to Trash") { notes.delete(note.id) }
    }

    private var tooltip: String {
        let edited = "Edited " + note.modified.formatted(date: .abbreviated, time: .shortened)
        return note.preview.isEmpty ? "\(note.title)\n\(edited)" : "\(note.title)\n\(note.preview)\n\(edited)"
    }
}

/// A small icon button in the editor's toolbar that brightens on hover.
private struct ToolbarButton: View {
    let symbol: String
    let help: String
    let isOn: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .opacity(hovering || isOn ? 1 : 0.7)
                .scaleEffect(hovering ? 1.12 : 1)
                .contentShape(Rectangle())
        }
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovering)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// The colour choices, as swatches that grow under the pointer.
private struct ColorPalette: View {
    let selected: NoteColor?
    let choose: (NoteColor?) -> Void

    var body: some View {
        HStack(spacing: 5) {
            Swatch(color: nil, isSelected: selected == nil) { choose(nil) }
            ForEach(NoteColor.allCases) { color in
                Swatch(color: color, isSelected: selected == color) { choose(color) }
            }
        }
    }

    private struct Swatch: View {
        let color: NoteColor?
        let isSelected: Bool
        let action: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: action) {
                Circle()
                    .fill(color?.swatch ?? .clear)
                    .overlay(
                        Circle().strokeBorder(.white.opacity(isSelected ? 0.9 : 0.3), lineWidth: isSelected ? 2 : 1)
                    )
                    .overlay {
                        if color == nil { Image(systemName: "slash.circle").font(.system(size: 8)).opacity(0.6) }
                    }
                    .frame(width: 11, height: 11)
                    .scaleEffect(hovering ? 1.3 : 1)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hovering)
            .help(color?.name ?? "No Color")
            .accessibilityLabel(color?.name ?? "No Color")
        }
    }
}
