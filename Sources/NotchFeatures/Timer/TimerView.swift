// SPDX-License-Identifier: MIT
import SwiftUI

/// The timer tab: countdown presets or a running countdown, and a stopwatch with laps.
struct TimerView: View {
    let timer: TimerFeature

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                modeButton("Timer", .countdown)
                modeButton("Stopwatch", .stopwatch)
            }
            switch timer.mode {
            case .countdown: countdown
            case .stopwatch: stopwatch
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func modeButton(_ title: String, _ mode: TimerFeature.Mode) -> some View {
        Button(title) { timer.mode = mode }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(timer.mode == mode ? .white.opacity(0.16) : .clear, in: Capsule())
            .accessibilityAddTraits(timer.mode == mode ? .isSelected : [])
    }

    @ViewBuilder private var countdown: some View {
        if let countdown = timer.countdown {
            // Redraws once a second, and only while running on screen.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = countdown.remaining(at: context.date)
                VStack(spacing: 8) {
                    RollingTime(left, countsDown: true)
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .opacity(countdown.isRunning ? 1 : 0.5)
                    ProgressView(value: countdown.total - left, total: countdown.total)
                        .tint(.white)
                        .frame(maxWidth: 260)
                    HStack(spacing: 18) {
                        control(countdown.isRunning ? "Pause" : "Resume") {
                            countdown.isRunning ? timer.pause() : timer.resume()
                        }
                        control("+1 min", timer.addMinute)
                        control("Cancel", timer.cancel)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Timer, \(formatTime(left)) left")
            }
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(TimerFeature.presets, id: \.self) { seconds in
                    Button {
                        timer.start(seconds)
                    } label: {
                        Text(seconds < 3600 ? "\(Int(seconds / 60)) min" : "1 hr")
                            .font(.callout.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start a \(formatTime(seconds)) timer")
                }
            }
            .padding(.top, 4)
        }
    }

    private var stopwatch: some View {
        let watch = timer.stopwatch
        // Tenths of a second need ten redraws a second, only while running on screen.
        return TimelineView(.periodic(from: .now, by: watch.isRunning ? 0.1 : 3600)) { context in
            VStack(spacing: 8) {
                RollingTime(watch.elapsed(at: context.date), tenths: true)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                HStack(spacing: 18) {
                    control(watch.isRunning ? "Pause" : "Start") { timer.toggleStopwatch() }
                    if watch.isRunning {
                        control("Lap") { timer.lap() }
                    } else {
                        control("Reset", timer.resetStopwatch).disabled(watch.elapsed(at: context.date) == 0)
                    }
                }
                ForEach(Array(watch.laps.enumerated().suffix(3).reversed()), id: \.offset) { index, total in
                    let previous = index > 0 ? watch.laps[index - 1] : 0
                    HStack {
                        Text("Lap \(index + 1)")
                        Spacer()
                        Text(formatTime(total - previous, tenths: true)).monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: 220)
                }
            }
        }
    }

    private func control(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.white.opacity(0.14), in: Capsule())
    }
}
