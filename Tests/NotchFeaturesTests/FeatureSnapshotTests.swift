// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI
import Testing

@testable import NotchFeatures

/// Renders each feature tab with sample data inside a notch-sized black panel. Always checks that
/// it draws; with SNAPSHOT_DIR set, also writes PNGs there for eyeballing.
@MainActor
struct FeatureSnapshotTests {
    /// The content area of an expanded notch.
    private let size = CGSize(width: 428, height: 200)

    @Test func mediaWithATrack() throws {
        let media = MediaFeature(bundle: Bundle(for: SnapshotMarker.self))
        media.receive(
            NowPlaying(
                title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming", isPlaying: true,
                duration: 243, elapsed: 61, timestamp: Date(), artwork: Self.sampleArtwork()))
        #expect(media.artwork != nil, "artwork is decoded into a thumbnail")
        try render(media.view, name: "media-playing")
    }

    @Test func mediaWithNothingPlaying() throws {
        try render(MediaFeature(bundle: Bundle(for: SnapshotMarker.self)).view, name: "media-idle")
    }

    @Test func shelfWithFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "ShelfSnapshot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = try ["Invoice.pdf", "Screenshot.png", "Notes.txt", "Archive.zip"].map { name in
            let url = folder.appending(path: name)
            try Data(name.utf8).write(to: url)
            return url
        }
        let shelf = ShelfFeature(storeURL: folder.appending(path: "shelf.json"))
        shelf.add(files)
        try FileManager.default.removeItem(at: files[3])
        shelf.phase = .foreground  // Archive.zip now shows as missing
        try render(shelf.view, name: "shelf")
    }

    /// The tab as the notch shows it: white on black, dark mode, in the content area.
    private func inNotch(_ view: some View) -> some View {
        view
            .frame(width: size.width, height: size.height)
            .padding(16)
            .background(.black)
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
    }

    @Test func timerPresetsAndARunningCountdown() throws {
        let timer = TimerFeature()
        try render(timer.view, name: "timer-presets")
        timer.start(25 * 60)
        try render(timer.view, name: "timer-running")
        timer.mode = .stopwatch
        timer.toggleStopwatch(now: Date(timeIntervalSinceNow: -83.4))
        timer.lap(now: Date(timeIntervalSinceNow: -41))
        try render(timer.view, name: "stopwatch")
    }

    @Test func notesWithAFewNotes() throws {
        let notes = NotesFeature(directory: FileManager.default.temporaryDirectory.appending(path: "N-\(UUID())"))
        notes.phase = .foreground
        try render(notes.view, name: "notes-empty")
        for text in ["Groceries\n- oat milk\n- coffee", "Ideas for the notch", "Meeting notes\nShip Phase 4"] {
            notes.update(notes.add(), text: text)
        }
        try render(notes.view, name: "notes")
    }

    @Test func tasksWithACompletedSection() throws {
        let tasks = TasksFeature(eventStore: EventStore(), defaults: UserDefaults(suiteName: "T-\(UUID())")!)
        let now = Date.now
        tasks.show(
            tasks: [
                TaskItem(id: "1", title: "Send the invoice", due: now - 3600),
                TaskItem(id: "2", title: "Book flights", due: now + 86_400),
                TaskItem(id: "3", title: "Water the plants"),
            ],
            completed: [
                TaskItem(id: "4", title: "Ship Phase 4", completed: now - 600),
                TaskItem(id: "5", title: "Renew passport", completed: now - 90_000),
            ])
        tasks.showsCompleted = true
        try render(tasks.view, name: "tasks")
        tasks.show(
            tasks: [TaskItem(id: "6", title: "Stand-up", due: now, hasTime: true, priority: .high)], completed: [],
            alerting: TaskItem(id: "6", title: "Stand-up", due: now, hasTime: true))
        try render(tasks.view, name: "tasks-alert")
    }

    @Test func eventKitTabsBeforeAccess() throws {
        let store = EventStore()
        try render(CalendarFeature(eventStore: store).view, name: "calendar-no-access")
        try render(TasksFeature(eventStore: store).view, name: "tasks-no-access")
        try render(ShortcutsFeature().view, name: "shortcuts-loading")
    }

    private func render(_ view: some View, name: String) throws {
        let host = NSHostingView(rootView: inNotch(view))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: size.width + 32, height: size.height + 32),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        #expect(bitmap.pixelsWide > 0)
        if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try bitmap.representation(using: .png, properties: [:])?.write(
                to: URL(filePath: directory).appending(path: "\(name).png"))
        }
    }

    /// A made-up album cover: a diagonal gradient, PNG-encoded like real artwork data.
    private static func sampleArtwork() -> Data? {
        let image = NSImage(size: CGSize(width: 600, height: 600), flipped: false) { rect in
            NSGradient(colors: [.systemPurple, .systemOrange])?.draw(in: rect, angle: 45)
            return true
        }
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

private final class SnapshotMarker {}
