// SPDX-License-Identifier: MIT
import Charts
import NotchCore
import NotchFeatures
import SwiftUI

/// The Usage tab: a tile per provider with its headline limit as a ring, a provider's full detail,
/// or, before any provider is on, the tools signed in on this Mac to choose from. With one provider
/// on, its detail is the whole tab.
struct UsageView: View {
    let usage: UsageFeature

    @State private var selected: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let providers = usage.enabledProviders
        let only = providers.count == 1 ? providers.first : nil
        // Relative times ("Resets in 2h 13m") move on once a minute, only while the tab is on screen.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Group {
                if providers.isEmpty {
                    UsageOnboarding(usage: usage)
                } else if let provider = only ?? providers.first(where: { $0.id == selected }) {
                    let back: (() -> Void)? = only == nil ? { selected = nil } : nil
                    ProviderDetail(usage: usage, provider: provider, now: context.date, back: back)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    dashboard(now: context.date)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: selected)
        }
    }

    private func dashboard(now: Date) -> some View {
        VStack(spacing: 8) {
            UsageHeader(usage: usage, now: now)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 8)], spacing: 8) {
                    ForEach(usage.enabledProviders) { provider in
                        Button {
                            selected = provider.id
                        } label: {
                            ProviderTile(
                                provider: provider, snapshot: usage.snapshots[provider.id],
                                error: usage.errors[provider.id], refreshing: usage.refreshing.contains(provider.id),
                                now: now)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .fadingEdges(length: 8)
        }
    }
}

/// Today's spend across providers, when they report it, the last update, and refresh.
private struct UsageHeader: View {
    let usage: UsageFeature
    let now: Date

    var body: some View {
        let snapshots = usage.enabledProviders.compactMap { usage.snapshots[$0.id] }
        let today = snapshots.compactMap { $0.dollars(for: "Today") }
        HStack(spacing: 8) {
            if !today.isEmpty {
                HStack(spacing: 4) {
                    Text("Today").foregroundStyle(.white.opacity(0.5))
                    Text(MetricFormatter.number(today.reduce(0, +), kind: .dollars, style: .row))
                        .fontWeight(.semibold)
                        .contentTransition(.numericText())
                }
                .font(.system(size: 11))
            }
            Spacer(minLength: 0)
            if let latest = snapshots.map(\.refreshedAt).max() {
                Text(Self.updated(latest, now: now))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }
            RefreshButton(spinning: !usage.refreshing.isEmpty) { Task { await usage.refreshAll(force: true) } }
        }
    }

    static func updated(_ date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        guard seconds >= 60, let ago = Formatters.compactDuration(seconds) else { return "Updated just now" }
        return "Updated \(ago) ago"
    }
}

/// One provider at a glance: its headline limit as a ring, up to three limits as bars, and when the
/// headline resets.
private struct ProviderTile: View {
    /// ponytail: fixed so the tiles in a row line up. Fonts are fixed-size, so the header, three bars
    /// and the footer always fit; showing a fourth bar needs a taller tile.
    static let height: CGFloat = 128

    let provider: UsageProvider
    let snapshot: ProviderSnapshot?
    let error: String?
    let refreshing: Bool
    let now: Date

    var body: some View {
        let style = ProviderStyle.of(provider.id)
        let meters = snapshot?.meters ?? []
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                ProviderLogo(providerID: provider.id, name: provider.name, size: 13)
                    .foregroundStyle(style.end)
                Text(provider.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if let plan = snapshot?.plan, !plan.isEmpty { PlanPill(plan: plan, style: style) }
                Spacer(minLength: 0)
                status
            }
            if let headline = meters.first {
                HStack(spacing: 10) {
                    UsageRing(meter: headline, style: style, size: 56)
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(meters.prefix(3)) { meter in miniMeter(meter, style: style) }
                    }
                }
                Spacer(minLength: 0)
                footer(headline)
            } else {
                placeholder(style: style)
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .frame(height: Self.height, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.start.opacity(0.16), .white.opacity(0.04)], startPoint: .topLeading,
                        endPoint: .bottomTrailing))
        }
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.08)) }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows every limit")
    }

    @ViewBuilder private var status: some View {
        if refreshing {
            ProgressView().controlSize(.mini)
        } else if error != nil {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: 0xF59E_0B))
                .help(error ?? "")
        }
    }

    /// When the headline limit resets, and whether it will last until then, on one line.
    private func footer(_ headline: Meter) -> some View {
        let left = headline.resetsAt.flatMap { Formatters.compactDuration($0.timeIntervalSince(now)) }
        return HStack(spacing: 6) {
            if let left {
                HStack(spacing: 3) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(left).monospacedDigit()
                }
                .help("Resets in \(left)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Resets in \(left)")
            }
            Spacer(minLength: 0)
            PaceBadge(meter: headline, now: now)
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.55))
        .lineLimit(1)
    }

    private func miniMeter(_ meter: Meter, style: ProviderStyle) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(meter.label).foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 4)
                Text(meter.headline).monospacedDigit()
            }
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            MeterBar(meter: meter, style: style, height: 4)
        }
    }

    /// No limits to show: still loading, a failure, or a provider that only reports spend.
    @ViewBuilder private func placeholder(style: ProviderStyle) -> some View {
        if let spend = snapshot?.dollars(for: "Today") ?? snapshot?.dollars(for: "Last 30 Days") {
            Text(MetricFormatter.number(spend, kind: .dollars, style: .row))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(style.end)
        } else {
            Text(error ?? (refreshing || snapshot == nil ? "Checking…" : "No limits to show"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
        }
    }
}

/// Everything a provider reports: each limit with its reset and pace, spend, and the daily trend.
/// `back` returns to the tiles; there's none when this is the only provider.
private struct ProviderDetail: View {
    let usage: UsageFeature
    let provider: UsageProvider
    let now: Date
    let back: (() -> Void)?

    var body: some View {
        let style = ProviderStyle.of(provider.id)
        let snapshot = usage.snapshots[provider.id]
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                if let back {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
                ProviderLogo(providerID: provider.id, name: provider.name, size: 15).foregroundStyle(style.end)
                Text(provider.name).font(.system(size: 13, weight: .semibold))
                if let plan = snapshot?.plan, !plan.isEmpty { PlanPill(plan: plan, style: style) }
                Spacer(minLength: 0)
                ForEach(provider.links, id: \.url) { link in
                    if let url = URL(string: link.url) {
                        Link(link.label, destination: url)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                RefreshButton(spinning: usage.refreshing.contains(provider.id)) {
                    Task { await usage.refresh(provider.id, force: true) }
                }
            }
            if let error = usage.errors[provider.id] { banner(error) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(snapshot?.meters ?? []) { meter in MeterRow(meter: meter, style: style, now: now) }
                    if let snapshot {
                        SpendRow(snapshot: snapshot, style: style)
                        if let trend = snapshot.trend, trend.count > 1 { TrendChart(points: trend, style: style) }
                        notes(snapshot)
                    }
                }
                .padding(.vertical, 4)
            }
            .fadingEdges(length: 8)
        }
    }

    private func banner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 10))
            .foregroundStyle(Color(hex: 0xFDE6_8A))
            .lineLimit(2)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xF59E_0B).opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Badges and notes the provider adds, like an organization's status or a sign-in hint.
    @ViewBuilder private func notes(_ snapshot: ProviderSnapshot) -> some View {
        if let warning = snapshot.warning {
            Text(warning).font(.system(size: 10)).foregroundStyle(Color(hex: 0xFDE6_8A))
        }
        ForEach(Array(snapshot.lines.enumerated()), id: \.offset) { _, line in
            switch line {
            case .badge(let label, let text, _, _) where !line.isError:
                HStack {
                    Text(label).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text(text).fontWeight(.medium)
                }
                .font(.system(size: 11))
            case .text(let label, let value, _, _):
                HStack {
                    Text(label).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text(value)
                }
                .font(.system(size: 11))
            case .values(let label, let values, _, _, _, _) where !SpendRow.periods.contains(label):
                HStack {
                    Text(label).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text(values.map { MetricFormatter.string(for: $0, style: .row) }.joined(separator: " · "))
                        .monospacedDigit()
                }
                .font(.system(size: 11))
            default:
                EmptyView()
            }
        }
    }
}

/// A limit in full: label and amount, its bar, when it resets, and whether it will last.
private struct MeterRow: View {
    let meter: Meter
    let style: ProviderStyle
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meter.label).font(.system(size: 11, weight: .medium))
                Spacer()
                Text(meter.detail)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            MeterBar(meter: meter, style: style, height: 6)
            HStack {
                if let reset = meter.resetLabel(now: now) { Text(reset) }
                Spacer()
                PaceBadge(meter: meter, now: now)
            }
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.5))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Today, yesterday, and the last 30 days of spend, as chips.
private struct SpendRow: View {
    static let periods = ["Today", "Yesterday", "Last 30 Days"]

    let snapshot: ProviderSnapshot
    let style: ProviderStyle

    var body: some View {
        let chips = Self.periods.compactMap { period in snapshot.values(for: period).map { (period, $0) } }
        if !chips.isEmpty {
            HStack(spacing: 6) {
                ForEach(chips, id: \.0) { period, values in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(period).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                        Text(values.first.map { MetricFormatter.string(for: $0, style: .row) } ?? "–")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        if values.count > 1 {
                            Text(MetricFormatter.string(for: values[1], style: .row))
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(style.start.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            .fixedSize(horizontal: false, vertical: true)  // every chip as tall as the tallest
        }
    }
}

/// The daily trend as rounded bars in the provider's colors.
private struct TrendChart: View {
    let points: [MetricChartPoint]
    let style: ProviderStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Daily usage").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                Spacer()
                if let peak = points.max(by: { $0.value < $1.value }) {
                    Text("Peak \(peak.readout)").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                }
            }
            let bars = LinearGradient(colors: [style.end, style.start], startPoint: .top, endPoint: .bottom)
            // A bar's ratio width needs a category axis: numeric x gives the bars no width.
            Chart(Array(points.enumerated()), id: \.offset) { index, point in
                BarMark(x: .value("Day", String(index)), y: .value("Usage", point.value), width: .ratio(0.7))
                    .foregroundStyle(bars)
                    .cornerRadius(2)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 54)
            HStack {
                Text(points.first?.label ?? "")
                Spacer()
                Text(points.last?.label ?? "")
            }
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.4))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily usage chart")
    }
}

/// Before any provider is on: the tools signed in on this Mac, one tap to turn each on.
private struct UsageOnboarding: View {
    let usage: UsageFeature

    var body: some View {
        let found = usage.providers.filter { usage.detected.contains($0.id) }
        let accents = ["claude", "copilot", "cursor"].map { ProviderStyle.of($0).start }
        VStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: accents, startPoint: .leading, endPoint: .trailing))
                .accessibilityHidden(true)
            VStack(spacing: 3) {
                Text("Your AI plans at a glance").font(.headline)
                Text(
                    "Turn on the tools you use. Each reads only its own sign-in on this Mac and sends it only to "
                        + "its own service."
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            }
            if !usage.hasDetected {
                ProgressView().controlSize(.small)
            } else if found.isEmpty {
                Text("No signed-in AI tools found. Settings › Features › AI Usage lists every provider.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 6)], spacing: 6) {
                    ForEach(found) { provider in chip(provider) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { if !usage.hasDetected { await usage.detect() } }
    }

    private func chip(_ provider: UsageProvider) -> some View {
        let style = ProviderStyle.of(provider.id)
        return Button {
            usage.setEnabled(provider.id, true)
        } label: {
            HStack(spacing: 6) {
                ProviderLogo(providerID: provider.id, name: provider.name, size: 13).foregroundStyle(style.end)
                Text(provider.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill").foregroundStyle(style.end)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(style.start.opacity(0.18), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Turn on \(provider.name)")
    }
}

extension ProviderSnapshot {
    /// A spend row's values, like Today's dollars and tokens.
    func values(for label: String) -> [MetricValue]? {
        for line in lines {
            if case .values(label, let values, _, _, _, _) = line, !values.isEmpty { return values }
        }
        return nil
    }

    func dollars(for label: String) -> Double? {
        values(for: label)?.first { $0.kind == .dollars }?.number
    }

    /// The daily usage trend, when the provider keeps local history.
    var trend: [MetricChartPoint]? {
        for line in lines {
            if case .chart(_, let points, _) = line { return points }
        }
        return nil
    }
}
