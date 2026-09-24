// SPDX-License-Identifier: MIT
import Foundation
import NotchCore
import Observation
import SwiftUI

/// One note: a plain-text (Markdown-friendly) file named by its id.
public struct Note: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var modified: Date

    /// The first non-empty line, or "New Note".
    public var title: String {
        let line = text.split(whereSeparator: \.isNewline).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return line ?? "New Note"
    }
}

/// Quick notes kept on this Mac as Markdown files in Application Support, one per note. They load
/// when the tab comes on screen, save half a second after typing stops, are written out whenever the
/// tab goes away, and leave memory when the feature stops. Empty notes are never saved.
@MainActor
@Observable
public final class NotesFeature: NotchFeature {
    public let id = FeatureID.notes
    public var phase: FeaturePhase = .stopped {
        didSet {
            guard phase != oldValue else { return }
            if phase == .foreground {
                load()
            } else {
                flush()
            }
            if phase == .stopped { notes = [] }
        }
    }
    public private(set) var notes: [Note] = []
    public var selection: Note.ID?

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private var unsaved: Set<Note.ID> = []
    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    public init(directory: URL = AppSupport.file("Notes")) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public var view: some View { NotesView(notes: self) }

    public var selected: Note? { notes.first { $0.id == selection } }

    @discardableResult
    public func add() -> Note.ID {
        let note = Note(id: UUID(), text: "", modified: .now)
        notes.insert(note, at: 0)
        selection = note.id
        return note.id
    }

    public func update(_ id: Note.ID, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].text != text else { return }
        notes[index].text = text
        notes[index].modified = .now
        unsaved.insert(id)
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            self?.flush()
        }
    }

    public func delete(_ id: Note.ID) {
        notes.removeAll { $0.id == id }
        unsaved.remove(id)
        try? FileManager.default.removeItem(at: file(for: id))
        if selection == id { selection = notes.first?.id }
    }

    func load() {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let listing = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)
        let stored = (listing ?? []).filter { $0.pathExtension == "md" }.compactMap { url -> Note? in
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                let text = try? String(contentsOf: url, encoding: .utf8)
            else { return nil }
            let modified = try? url.resourceValues(forKeys: Set(keys)).contentModificationDate
            return Note(id: id, text: text, modified: modified ?? .distantPast)
        }
        // Edits not yet on disk win over what's stored.
        let pending = notes.filter { unsaved.contains($0.id) }
        notes = (pending + stored.filter { note in !pending.contains { $0.id == note.id } })
            .sorted { $0.modified > $1.modified }
        if selected == nil { selection = notes.first?.id }
    }

    /// Writes every unsaved note now; a note emptied out is deleted rather than kept blank.
    func flush() {
        pendingSave?.cancel()
        for id in unsaved {
            guard let note = notes.first(where: { $0.id == id }) else { continue }
            do {
                if note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try? FileManager.default.removeItem(at: file(for: id))
                } else {
                    try note.text.write(to: file(for: id), atomically: true, encoding: .utf8)
                }
            } catch {
                Log.features.error("Couldn't save a note: \(error.localizedDescription, privacy: .public)")
            }
        }
        unsaved = []
    }

    private func file(for id: Note.ID) -> URL { directory.appending(path: "\(id.uuidString).md") }
}
