// SPDX-License-Identifier: MIT
import Foundation
import Testing

@testable import NotchFeatures

@MainActor
struct NotesFeatureTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "NotesTests-\(UUID().uuidString)")

    private func files() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
    }

    @Test func notesAreSavedAsFilesAndSurviveARelaunch() {
        let notes = NotesFeature(directory: folder)
        notes.phase = .foreground
        let id = notes.add()
        notes.update(id, text: "Groceries\n- milk")
        notes.phase = .background  // leaving the tab writes pending edits
        #expect(files() == ["\(id.uuidString).md"])

        let relaunched = NotesFeature(directory: folder)
        relaunched.phase = .foreground
        #expect(relaunched.notes.map(\.text) == ["Groceries\n- milk"])
        #expect(relaunched.selected?.title == "Groceries")
    }

    @Test func typingSavesAfterAShortPause() async throws {
        let notes = NotesFeature(directory: folder)
        notes.phase = .foreground
        notes.update(notes.add(), text: "draft")
        #expect(files().isEmpty, "not on every keystroke")
        #expect(await eventually { files().count == 1 })
    }

    @Test func emptyNotesAreNeverKept() {
        let notes = NotesFeature(directory: folder)
        notes.phase = .foreground
        let id = notes.add()
        notes.update(id, text: "temporary")
        notes.phase = .background
        notes.phase = .foreground
        notes.update(id, text: "   \n")
        notes.phase = .background
        #expect(files().isEmpty)
    }

    @Test func deletingANoteRemovesItsFileAndMovesTheSelection() {
        let notes = NotesFeature(directory: folder)
        notes.phase = .foreground
        let first = notes.add()
        notes.update(first, text: "one")
        let second = notes.add()
        notes.update(second, text: "two")
        notes.phase = .background
        notes.delete(second)
        #expect(files() == ["\(first.uuidString).md"])
        #expect(notes.selection == first)
    }

    @Test func stoppingWritesEverythingAndReleasesMemory() {
        let notes = NotesFeature(directory: folder)
        notes.phase = .foreground
        notes.update(notes.add(), text: "keep me")
        notes.phase = .stopped
        #expect(notes.notes.isEmpty)
        #expect(files().count == 1)
    }

    @Test func titlesComeFromTheFirstNonEmptyLine() {
        #expect(Note(id: UUID(), text: "\n  \n  Plan  \nmore", modified: .now).title == "Plan")
        #expect(Note(id: UUID(), text: "", modified: .now).title == "New Note")
    }
}
