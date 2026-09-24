// SPDX-License-Identifier: MIT
import AppKit
import ImageIO
import NotchCore
import Observation
import SwiftUI

/// Playback commands mediaremote-adapter's `send` understands.
public enum MediaCommand: Int, Sendable {
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

/// Now playing and playback controls for whatever app the system considers the player.
///
/// The system's now-playing data lives behind MediaRemote, which macOS 15.4+ only serves to Apple
/// processes. mediaremote-adapter (BSD-3-Clause) bridges that from `/usr/bin/perl` in a child
/// process, so the private framework never loads into OpenNotch and a breakage can't take the
/// app down. If the helper dies, Music and Spotify's public notifications take over, display only.
@MainActor
@Observable
public final class MediaFeature: NotchFeature {
    public enum Source: Equatable, Sendable {
        /// Any app, with controls.
        case adapter
        /// Music and Spotify only, no controls.
        case fallback
    }

    public let id = FeatureID.media
    public var phase: FeaturePhase = .stopped {
        didSet { phase == .stopped ? stop() : start() }
    }
    public private(set) var nowPlaying: NowPlaying?
    public private(set) var artwork: NSImage?
    public private(set) var source: Source
    /// Per-feature setting: raise a live activity when the track changes.
    public var announcesTracks: Bool {
        didSet { defaults.set(announcesTracks, forKey: Self.announceKey) }
    }
    /// Raised when the track changes while the notch shows something else.
    @ObservationIgnored public var onActivity: ((Activity) -> Void)?

    private static let announceKey = "media.announcesTracks"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let adapter: MediaAdapter?
    @ObservationIgnored private var stream: Process?
    @ObservationIgnored private var startedAt = Date.distantPast
    @ObservationIgnored private var notificationTokens: [NSObjectProtocol] = []
    // ponytail: artwork is downsampled to thumbnails and at most 16 recent tracks are kept.
    @ObservationIgnored private let artworkCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 16
        return cache
    }()

    public init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        adapter = MediaAdapter.bundled(in: bundle)
        source = adapter == nil ? .fallback : .adapter
        announcesTracks = defaults.object(forKey: Self.announceKey) as? Bool ?? true
    }

    public var view: some View { MediaView(media: self) }

    public func send(_ command: MediaCommand) {
        guard source == .adapter, let adapter else { return }
        // `send` waits up to 2 s for the player, so it runs off the main thread; the stream reports
        // the outcome.
        Task { _ = await Subprocess.run(MediaAdapter.perl, adapter.arguments(["send", "\(command.rawValue)"])) }
    }

    /// Brings the playing app forward.
    public func openPlayer() {
        guard let bundleID = nowPlaying?.appBundleID,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Sources

    private func start() {
        guard stream == nil, notificationTokens.isEmpty else { return }
        startedAt = Date()
        if source == .adapter, let adapter, startStream(adapter) { return }
        source = .fallback
        startNotifications()
    }

    private func stop() {
        let stream = stream
        self.stream = nil  // marks the exit as expected
        stream?.terminate()
        notificationTokens.forEach(DistributedNotificationCenter.default().removeObserver)
        notificationTokens = []
        receive(nil)
    }

    private func startStream(_ adapter: MediaAdapter) -> Bool {
        let process = adapter.process(["stream", "--micros"])
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] ended in
            let status = ended.terminationStatus
            Task { @MainActor in self?.streamEnded(ended, status: status) }
        }
        do {
            try process.run()
        } catch {
            Log.features.error("Media helper didn't start: \(error.localizedDescription, privacy: .public)")
            return false
        }
        stream = process
        let lines = output.fileHandleForReading.bytes.lines
        Task.detached { [weak self] in
            var parser = MediaStreamParser()
            do {
                for try await line in lines {
                    let now = parser.consume(line)
                    await self?.receive(now)
                }
            } catch {
                // The pipe closes when the helper exits; streamEnded handles that.
            }
        }
        Log.features.info("Media helper streaming")
        return true
    }

    private func streamEnded(_ process: Process, status: Int32) {
        guard process === stream else { return }  // stopped on purpose
        stream = nil
        // Upstream advises against restarting a helper that exited on its own: fall back instead.
        Log.features.error("Media helper exited with status \(status, privacy: .public); using the fallback")
        source = .fallback
        startNotifications()
    }

    private func startNotifications() {
        let center = DistributedNotificationCenter.default()
        notificationTokens = PlayerNotification.names.map { name in
            center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] note in
                let update = PlayerNotification(note.userInfo ?? [:], name: name)
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.receive(update.merge(into: self.nowPlaying))
                }
            }
        }
    }

    // MARK: Updates

    func receive(_ now: NowPlaying?) {
        guard now != nowPlaying else { return }
        let previous = nowPlaying
        nowPlaying = now
        if now?.artwork != previous?.artwork || now?.isDifferentTrack(from: previous) == true {
            artwork = now.flatMap(thumbnail(for:))
        }
        let settled = Date().timeIntervalSince(startedAt) > 1.5  // the first payloads are the current state
        if announcesTracks, Self.shouldAnnounce(now, after: previous, settled: settled, phase: phase), let now {
            onActivity?(Activity(feature: .media, symbol: "music.note", title: now.title, duration: .seconds(3)))
        }
    }

    /// A new track is worth a live activity, unless it's just the state at startup or Media is on screen.
    static func shouldAnnounce(_ now: NowPlaying?, after previous: NowPlaying?, settled: Bool, phase: FeaturePhase)
        -> Bool
    {
        guard let now, settled, phase == .background else { return false }
        return now.isDifferentTrack(from: previous)
    }

    private func thumbnail(for now: NowPlaying) -> NSImage? {
        guard let data = now.artwork else { return nil }
        let key = "\(now.title)|\(now.artist ?? "")|\(now.album ?? "")|\(data.count)" as NSString
        if let cached = artworkCache.object(forKey: key) { return cached }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 256,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        let thumbnail = NSImage(cgImage: image, size: .zero)
        artworkCache.setObject(thumbnail, forKey: key)
        return thumbnail
    }
}

/// The bundled mediaremote-adapter: its perl script and framework, run by the system perl.
struct MediaAdapter: Sendable {
    static let perl = "/usr/bin/perl"
    let script: URL
    let framework: URL

    static func bundled(in bundle: Bundle) -> MediaAdapter? {
        guard let script = bundle.url(forResource: "mediaremote-adapter", withExtension: "pl"),
            let framework = bundle.privateFrameworksURL?.appending(path: "MediaRemoteAdapter.framework"),
            FileManager.default.fileExists(atPath: framework.path),
            FileManager.default.isExecutableFile(atPath: perl)
        else { return nil }
        return MediaAdapter(script: script, framework: framework)
    }

    /// perl's arguments for one adapter command.
    func arguments(_ command: [String]) -> [String] { [script.path, framework.path] + command }

    func process(_ command: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(filePath: Self.perl)
        process.arguments = arguments(command)
        return process
    }
}
