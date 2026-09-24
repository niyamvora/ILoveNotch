// SPDX-License-Identifier: MIT
import SwiftUI

/// The media tab: artwork, title, artist, a live progress bar, and playback controls.
struct MediaView: View {
    let media: MediaFeature

    var body: some View {
        if let now = media.nowPlaying {
            HStack(spacing: 14) {
                Button(action: media.openPlayer) {
                    artwork
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Open the player")
                .accessibilityLabel("Open the player")

                VStack(alignment: .leading, spacing: 4) {
                    Text(now.title).font(.headline).lineLimit(1)
                    if let subtitle = now.artist ?? now.album {
                        Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    }
                    progress(now)
                    controls(playing: now.isPlaying)
                    if media.source == .fallback {
                        Text("Music and Spotify only; controls unavailable")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .animation(.easeInOut(duration: 0.16), value: media.artwork)
        } else {
            FeatureUnavailableView(
                symbol: "music.note",
                title: "Nothing playing",
                message: media.source == .adapter
                    ? "Play something in Music, Spotify, a browser, or any app that reports what it's playing."
                    : "This macOS version blocks full now-playing access. Music and Spotify still show up here.")
        }
    }

    @ViewBuilder private var artwork: some View {
        if let image = media.artwork {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                .transition(.opacity)
        } else {
            ZStack {
                Color.white.opacity(0.1)
                Image(systemName: "music.note").font(.system(size: 30)).opacity(0.5)
            }
        }
    }

    /// Ticks once a second, and only while this tab is on screen and the track is playing.
    @ViewBuilder private func progress(_ now: NowPlaying) -> some View {
        if let duration = now.duration, duration > 0 {
            let spokenPosition = formatTime(now.position(at: .now) ?? 0, roundingUp: false)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let position = now.position(at: context.date) ?? 0
                VStack(spacing: 2) {
                    ProgressView(value: position, total: duration)
                        .progressViewStyle(.linear)
                        .tint(.white)
                    HStack(spacing: 0) {
                        RollingTime(position)
                        Spacer()
                        Text("-")
                        RollingTime(duration - position, countsDown: true)
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(spokenPosition) of \(formatTime(duration, roundingUp: false))")
        }
    }

    private func controls(playing: Bool) -> some View {
        HStack(spacing: 22) {
            control("backward.fill", label: "Previous track") { media.send(.previousTrack) }
            control(playing ? "pause.fill" : "play.fill", label: playing ? "Pause" : "Play") {
                media.send(.togglePlayPause)
            }
            .font(.system(size: 20))
            control("forward.fill", label: "Next track") { media.send(.nextTrack) }
        }
        .font(.system(size: 15))
        .disabled(media.source == .fallback)
        .padding(.top, 2)
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 28, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
