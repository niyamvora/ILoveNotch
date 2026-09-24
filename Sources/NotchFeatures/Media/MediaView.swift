// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

/// The media tab: artwork and track details over a soft glow of the cover, a wavy seek bar you can
/// drag, animated controls, and a waveform along the bottom, all tinted from the artwork. The
/// animated parts run at most 30 fps, and only while music plays and the tab is on screen.
struct MediaView: View {
    let media: MediaFeature

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    /// Where the seek bar is being dragged to, 0...1.
    @State private var scrub: Double?
    @State private var backTaps = 0
    @State private var forwardTaps = 0

    private var tint: Color { media.accent?.color ?? .white }

    var body: some View {
        if let now = media.nowPlaying {
            player(now)
        } else {
            idle
        }
    }

    private func player(_ now: NowPlaying) -> some View {
        let animating = now.isPlaying && !reduceMotion
        return VStack(spacing: 8) {
            HStack(spacing: 14) {
                artwork
                details(now)
            }
            // One timeline drives the wave, the waveform, and the times, and stops when paused.
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !animating)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                VStack(spacing: 8) {
                    seekBar(now, at: context.date, phase: time * 2.4)
                    controls(playing: now.isPlaying)
                    Spacer(minLength: 0)
                    Waveform(level: animating ? 1 : 0, time: time, tint: tint)
                        .frame(height: 18)
                        .fadingEdges(.horizontal, length: 28)
                        .animation(.easeInOut(duration: 0.5), value: animating)
                        .accessibilityHidden(true)
                }
            }
            if media.source == .fallback {
                Text("Music and Spotify only; controls unavailable")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .background { glow }
    }

    // MARK: Parts

    private var artwork: some View {
        Button(action: media.openPlayer) {
            ZStack {
                if let image = media.artwork {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                } else {
                    LinearGradient(
                        colors: [tint.opacity(0.45), tint.opacity(0.12)], startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                    Image(systemName: "music.note").font(.system(size: 26)).opacity(0.7)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: tint.opacity(0.45), radius: 12, y: 4)
            .animation(.easeInOut(duration: 0.16), value: media.artwork)
        }
        .buttonStyle(PressableButtonStyle())
        .help("Open the player")
        .accessibilityLabel("Open the player")
    }

    private func details(_ now: NowPlaying) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(now.title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .id(now.title)
                .transition(.push(from: .bottom))
            if let subtitle = now.artist ?? now.album {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .id(subtitle)
                    .transition(.push(from: .bottom))
            }
            sourceApp(now)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82), value: now.title)
    }

    @ViewBuilder private func sourceApp(_ now: NowPlaying) -> some View {
        if let id = now.appBundleID, let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            HStack(spacing: 4) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .frame(width: 13, height: 13)
                Text(FileManager.default.displayName(atPath: app.path))
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.45))
            .padding(.top, 2)
        }
    }

    private func seekBar(_ now: NowPlaying, at date: Date, phase: Double) -> some View {
        let duration = now.duration ?? 0
        let position = scrub.map { $0 * duration } ?? now.position(at: date) ?? 0
        let canSeek = media.source == .adapter && duration > 0
        return HStack(spacing: 8) {
            RollingTime(position)
                .frame(minWidth: 34, alignment: .trailing)
            GeometryReader { proxy in
                WavySeekBar(
                    progress: duration > 0 ? position / duration : 0,
                    amplitude: now.isPlaying && !reduceMotion && scrub == nil ? 1 : 0,
                    phase: phase, tint: tint
                )
                .animation(.easeInOut(duration: 0.45), value: now.isPlaying)
                .animation(.easeInOut(duration: 0.2), value: scrub == nil)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in scrub = min(max(drag.location.x / proxy.size.width, 0), 1) }
                        .onEnded { _ in
                            if let scrub { media.seek(to: scrub * duration) }
                            scrub = nil
                        },
                    isEnabled: canSeek)
            }
            .frame(height: 18)
            HStack(spacing: 0) {
                Text("-")
                RollingTime(duration - position, countsDown: true)
            }
            .frame(minWidth: 38, alignment: .leading)
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.55))
        .opacity(duration > 0 ? 1 : 0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(formatTime(position, roundingUp: false)) of \(formatTime(duration, roundingUp: false))")
    }

    private func controls(playing: Bool) -> some View {
        HStack(spacing: 30) {
            Button {
                backTaps += 1
                media.send(.previousTrack)
            } label: {
                Image(systemName: "backward.fill").symbolEffect(.bounce.down, value: backTaps)
            }
            .accessibilityLabel("Previous track")
            Button {
                media.send(.togglePlayPause)
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(tint, in: Circle())
            }
            .accessibilityLabel(playing ? "Pause" : "Play")
            Button {
                forwardTaps += 1
                media.send(.nextTrack)
            } label: {
                Image(systemName: "forward.fill").symbolEffect(.bounce.down, value: forwardTaps)
            }
            .accessibilityLabel("Next track")
        }
        .font(.system(size: 17, weight: .semibold))
        .buttonStyle(PressableButtonStyle())
        .disabled(media.source == .fallback)
    }

    /// A soft, saturated blur of the cover behind the whole notch; the notch clips it to its outline.
    @ViewBuilder private var glow: some View {
        if let image = media.artwork, !reduceTransparency {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 50)
                .saturation(1.3)
                .opacity(0.35)
                .padding(-60)
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: media.artwork)
        }
    }

    private var idle: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: "music.note")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.08), in: Circle())
            Text("Nothing playing").font(.headline)
            Text(
                media.source == .adapter
                    ? "Play something in Music, Spotify, a browser, or any app that reports what it's playing."
                    : "This macOS version blocks full now-playing access. Music and Spotify still show up here."
            )
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)
            Spacer(minLength: 0)
            Waveform(level: 0, time: 0, tint: .white)
                .frame(height: 14)
                .fadingEdges(.horizontal, length: 40)
                .opacity(0.4)
                .accessibilityHidden(true)
        }
    }
}
