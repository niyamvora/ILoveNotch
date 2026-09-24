// SPDX-License-Identifier: MIT
import AppKit
import NotchCore
import SwiftUI
import Testing

@testable import NotchSurface

/// Renders the notch offscreen in every state. Always checks that each state draws; with
/// SNAPSHOT_DIR set, also writes PNGs there for eyeballing:
///
///     SNAPSHOT_DIR=/tmp/notch swift test --filter Snapshot
private let notched = NotchMetrics(
    screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
    left: CGRect(x: 0, y: 950, width: 662, height: 32), right: CGRect(x: 850, y: 950, width: 662, height: 32))
private let notchless = NotchMetrics(
    screen: CGRect(x: 0, y: 0, width: 2560, height: 1440), safeAreaTop: 0, left: nil, right: nil)
private let song = Activity(feature: .media, symbol: "music.note", title: "Midnight City", duration: .seconds(3))
private let volume = Activity(
    feature: nil, symbol: "speaker.wave.2.fill", title: "56%", level: 0.56, duration: .seconds(1))

private let snapshotCases: [(name: String, metrics: NotchMetrics, events: [NotchEvent])] = [
    ("compact", notched, [.show]),
    ("hover", notched, [.show, .pointerEntered]),
    ("activity", notched, [.show, .activity(song)]),
    ("volume", notched, [.show, .activity(volume)]),
    ("expanded-media", notched, [.show, .clicked]),
    ("pinned-notes", notched, [.show, .selectTab(.notes), .togglePin]),
    ("pill-compact", notchless, [.show]),
    ("pill-expanded", notchless, [.show, .selectTab(.shelf)]),
]

@MainActor
struct NotchSnapshotTests {
    @Test(arguments: snapshotCases.indices)
    func everyStateRenders(index: Int) throws {
        let (name, metrics, events) = snapshotCases[index]
        try draw(name, metrics: metrics, events: events, preferences: Self.preferences())
    }

    /// The densest layout: every tab and the settings button in the header, and the size and pin
    /// capsule in the corner, at the smallest open size.
    @Test func everyTabFitsTheSmallestSize() throws {
        let preferences = Self.preferences()
        preferences.resizeExpanded(to: NotchPreferences.minimumExpandedSize)
        try draw("expanded-smallest", metrics: notched, events: [.show, .clicked], preferences: preferences)
    }

    private static func preferences() -> NotchPreferences {
        NotchPreferences(defaults: UserDefaults(suiteName: "Snapshots.\(UUID().uuidString)")!)
    }

    private func draw(_ name: String, metrics: NotchMetrics, events: [NotchEvent], preferences: NotchPreferences)
        throws
    {
        let engine = NotchEngine()
        events.forEach(engine.send)
        let content = NotchContent(
            tab: { feature in
                AnyView(Text("\(feature.title) content").frame(maxWidth: .infinity, maxHeight: .infinity))
            },
            dropFiles: { _ in false },
            openSettings: {})
        let panel = metrics.panelFrame.size
        let view = NotchView(engine: engine, metrics: metrics, preferences: preferences, content: content)
            .frame(width: panel.width, height: panel.height)
            .background(Color(white: 0.82))  // stands in for the desktop behind the transparent panel
        let image = try #require(Self.render(view, size: panel, name: name))
        #expect(image.pixelsWide > 0 && image.pixelsHigh > 0)
    }

    /// Draws the view through the same AppKit hosting path the app uses (ImageRenderer can't draw
    /// AppKit-backed pieces such as the drop target and paints yellow placeholders over them). With
    /// SNAPSHOT_DIR set, also writes `<name>.png` there.
    static func render(_ view: some View, size: CGSize, name: String) -> NSBitmapImageRep? {
        let host = NotchHostingView(rootView: view)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let png = bitmap.representation(using: .png, properties: [:])
            try? png?.write(to: URL(filePath: directory).appending(path: "\(name).png"))
        }
        return bitmap
    }
}
