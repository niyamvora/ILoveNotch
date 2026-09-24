// SPDX-License-Identifier: MIT
import Foundation
import NotchCore
import Testing

@testable import NotchFeatures

struct MediaStreamParserTests {
    // Line shapes as mediaremote-adapter v0.7.7 prints them with `stream --micros`.
    private let empty = #"{"type":"data","diff":false,"payload":{}}"#
    private let song =
        #"{"type":"data","diff":false,"payload":{"title":"Song","artist":"Artist","album":"Album","playing":true,"playbackRate":1,"durationMicros":180000000,"elapsedTimeMicros":30000000,"timestampEpochMicros":1790000000000000,"bundleIdentifier":"com.apple.WebKit.GPU","parentApplicationBundleIdentifier":"com.apple.Safari","processIdentifier":42}}"#

    /// Feeds lines to a fresh parser and returns what's playing after the last one.
    private func play(_ lines: String...) -> NowPlaying? {
        var parser = MediaStreamParser()
        var now: NowPlaying?
        for line in lines { now = parser.consume(line) }
        return now
    }

    @Test func theFirstEmptyPayloadMeansNothingIsPlaying() {
        #expect(play(empty) == nil)
    }

    @Test func aFullPayloadBecomesTheTrackInSeconds() throws {
        let now = try #require(play(empty, song))
        #expect(now.title == "Song" && now.artist == "Artist" && now.album == "Album")
        #expect(now.isPlaying)
        #expect(now.duration == 180 && now.elapsed == 30)
        #expect(now.timestamp == Date(timeIntervalSince1970: 1_790_000_000))
        #expect(now.appBundleID == "com.apple.Safari", "browsers report their media helper; use the parent app")
    }

    @Test func diffsMergeAndNullRemovesAKey() throws {
        let paused = try #require(play(song, #"{"type":"data","diff":true,"payload":{"playing":false}}"#))
        #expect(!paused.isPlaying && paused.title == "Song")
        let noAlbum = try #require(play(song, #"{"type":"data","diff":true,"payload":{"album":null}}"#))
        #expect(noAlbum.album == nil && noAlbum.artist == "Artist")
    }

    @Test func aFullPayloadReplacesEverything() throws {
        let next = try #require(play(song, #"{"type":"data","diff":false,"payload":{"title":"Next","playing":true}}"#))
        #expect(next.title == "Next" && next.artist == nil)
        #expect(play(song, empty) == nil, "an empty full payload clears the track")
    }

    @Test func artworkIsDecodedFromBase64() throws {
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let line =
            #"{"type":"data","diff":false,"payload":{"title":"Art","playing":true,"artworkData":"\#(bytes.base64EncodedString())"}}"#
        #expect(try #require(play(line)).artwork == bytes)
    }

    @Test(arguments: ["", "not json", #"{"type":"error"}"#, #"{"type":"data","diff":true}"#])
    func linesItDoesntUnderstandChangeNothing(line: String) throws {
        #expect(try #require(play(song, line)).title == "Song")
    }
}

struct NowPlayingTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func positionAdvancesWhilePlaying() {
        let now = NowPlaying(title: "T", isPlaying: true, duration: 100, elapsed: 10, timestamp: start)
        #expect(now.position(at: start.addingTimeInterval(5)) == 15)
        #expect(now.position(at: start.addingTimeInterval(500)) == 100, "clamped to the duration")
    }

    @Test func positionHoldsWhilePausedAndFollowsTheRate() {
        let paused = NowPlaying(title: "T", isPlaying: false, duration: 100, elapsed: 10, timestamp: start)
        #expect(paused.position(at: start.addingTimeInterval(30)) == 10)
        let doubled = NowPlaying(title: "T", isPlaying: true, playbackRate: 2, elapsed: 10, timestamp: start)
        #expect(doubled.position(at: start.addingTimeInterval(5)) == 20)
    }
}

struct PlayerNotificationTests {
    @Test func musicReportsTheTrackInMilliseconds() throws {
        let info: [AnyHashable: Any] = [
            "Name": "Song", "Artist": "Artist", "Album": "Album", "Player State": "Playing", "Total Time": 200_000.0,
        ]
        let now = try #require(PlayerNotification(info, name: "com.apple.Music.playerInfo").merge(into: nil))
        #expect(now.title == "Song" && now.isPlaying && now.duration == 200)
        #expect(now.appBundleID == "com.apple.Music")
    }

    @Test func aBarePauseKeepsTheTrack() throws {
        let playing = NowPlaying(title: "Song", artist: "Artist", isPlaying: true, duration: 200)
        let paused = PlayerNotification(["Player State": "Paused"], name: "com.apple.Music.playerInfo")
        let now = try #require(paused.merge(into: playing))
        #expect(now.title == "Song" && now.artist == "Artist" && now.duration == 200 && !now.isPlaying)
    }

    @Test func stoppingClearsTheTrack() {
        let playing = NowPlaying(title: "Song", isPlaying: true)
        let stopped = PlayerNotification(["Player State": "Stopped"], name: "com.spotify.client.PlaybackStateChanged")
        #expect(stopped.merge(into: playing) == nil)
    }

    @Test func spotifyIsIdentified() throws {
        let info: [AnyHashable: Any] = ["Name": "Song", "Player State": "Playing", "Duration": 1000.0]
        let update = PlayerNotification(info, name: "com.spotify.client.PlaybackStateChanged")
        let now = try #require(update.merge(into: nil))
        #expect(now.appBundleID == "com.spotify.client" && now.duration == 1)
    }
}

@MainActor
struct MediaFeatureTests {
    private let song = NowPlaying(title: "Song", artist: "A", isPlaying: true)
    private let next = NowPlaying(title: "Next", artist: "A", isPlaying: true)

    @Test func onlySettledTrackChangesOffScreenAreAnnounced() {
        #expect(MediaFeature.shouldAnnounce(next, after: song, settled: true, phase: .background))
        #expect(!MediaFeature.shouldAnnounce(next, after: song, settled: false, phase: .background), "startup state")
        #expect(!MediaFeature.shouldAnnounce(next, after: song, settled: true, phase: .foreground), "already on screen")
        var paused = song
        paused.isPlaying = false
        #expect(!MediaFeature.shouldAnnounce(paused, after: song, settled: true, phase: .background), "same track")
        #expect(!MediaFeature.shouldAnnounce(nil, after: song, settled: true, phase: .background))
    }

    @Test func withoutTheBundledHelperMediaFallsBack() {
        // Test runners don't bundle mediaremote-adapter, so this exercises the fallback path.
        let media = MediaFeature(bundle: Bundle(for: BundleMarker.self))
        #expect(media.source == .fallback)
        media.phase = .background
        media.receive(song)
        #expect(media.nowPlaying == song)
        media.phase = .stopped
        #expect(media.nowPlaying == nil, "stopping releases the state")
    }
}

private final class BundleMarker {}
