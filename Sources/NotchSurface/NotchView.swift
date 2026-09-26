// SPDX-License-Identifier: MIT
import NotchCore
import SwiftUI

/// What the app plugs into every notch: feature views and actions the surface doesn't know about.
@MainActor
public struct NotchContent {
    /// The expanded view for a feature tab.
    public var tab: (FeatureID) -> AnyView
    /// Files dropped on the notch; returns whether they were accepted.
    public var dropFiles: ([URL]) -> Bool
    public var openSettings: () -> Void

    public init(
        tab: @escaping (FeatureID) -> AnyView,
        dropFiles: @escaping ([URL]) -> Bool,
        openSettings: @escaping () -> Void
    ) {
        self.tab = tab
        self.dropFiles = dropFiles
        self.openSettings = openSettings
    }
}

/// Horizontal and vertical scale for the squash-and-stretch animation styles.
struct Squash {
    var x: CGFloat = 1
    var y: CGFloat = 1
}

/// One display's notch. The panel around it never moves; this view animates one shape between
/// every presentation, so SwiftUI is the only animation owner.
struct NotchView: View {
    let engine: NotchEngine
    let metrics: NotchMetrics
    let preferences: NotchPreferences
    let content: NotchContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var dropTargeted = false
    @State private var justDropped = false
    @State private var slideForward = true
    /// The open size when a resize drag began, while one is under way.
    @State private var resizeStart: CGSize?
    @Namespace private var selection

    var body: some View {
        let presentation = engine.state.presentation
        let resting = engine.state.restingActivity
        let size = metrics.size(for: engine.state, expanded: preferences.expandedSize)
        let outline = Self.shape(for: presentation, resting: resting != nil, on: metrics)
        ZStack(alignment: .top) {
            outline.fill(.black)
            if let tab = presentation.openTab {
                expanded(tab: tab, pinned: presentation.isPinned)
                    .transition(.opacity)
            } else if case .transient(let activity) = presentation {
                live(activity)
                    .transition(.opacity)
            } else if let resting {
                live(resting, ongoing: true)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(outline)  // content sliding between tabs never shows outside the notch
        .overlay {
            if contrast == .increased {
                outline.stroke(.white.opacity(0.45), lineWidth: 1)
            }
            if dropTargeted {
                outline.stroke(Color.accentColor, lineWidth: 2).shadow(color: .accentColor, radius: 6)
            }
        }
        .keyframeAnimator(initialValue: Squash(), trigger: presentation.openTab != nil) { notch, squash in
            notch.scaleEffect(x: squash.x, y: squash.y, anchor: .top)  // anchored to the screen edge
        } keyframes: { _ in
            squashKeyframes(opening: presentation.openTab != nil)
        }
        .environment(\.colorScheme, .dark)  // the notch is always black
        .contentShape(outline)
        .onHover { engine.send($0 ? .pointerEntered : .pointerExited) }
        .onTapGesture { engine.send(.clicked) }
        .dropDestination(for: URL.self) { urls, _ in
            justDropped = true
            engine.send(.dropped)
            return content.dropFiles(urls)
        } isTargeted: { targeted in
            if targeted {
                justDropped = false
                engine.send(.dragEntered)
            } else if !justDropped {
                engine.send(.dragExited)
            }
            dropTargeted = targeted
        }
        .animation(motion(for: presentation), value: presentation)
        .animation(activityMotion, value: resting)
        .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.8), value: dropTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ILoveNotch")
        .accessibilityAction(named: presentation.openTab == nil ? "Open" : "Close") {
            engine.send(presentation.openTab == nil ? .clicked : .dismiss)
        }
        .padding(.top, metrics.topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// `resting` is a resting notch showing an ongoing activity, which takes a live activity's shape.
    static func shape(for presentation: NotchPresentationState, resting: Bool = false, on metrics: NotchMetrics)
        -> NotchShape
    {
        let open = presentation.openTab != nil
        guard metrics.notch != nil else {
            return NotchShape(topRadius: 0, bottomRadius: open ? 24 : Self.pillRadius, flushTop: false)
        }
        switch presentation {
        case .expanded, .pinned, .focused:
            return NotchShape(topRadius: Self.expandedTopRadius, bottomRadius: Self.expandedBottomRadius)
        case .hoverArmed, .transient: return NotchShape(topRadius: NotchMetrics.flare, bottomRadius: 13)
        case .compact where resting: return NotchShape(topRadius: NotchMetrics.flare, bottomRadius: 13)
        // Closed: rounder than the housing's own corners, so the shape stays hidden behind it.
        default: return NotchShape(topRadius: NotchMetrics.flare, bottomRadius: 10)
        }
    }

    private static let pillRadius: CGFloat = 100  // clamped to a capsule

    /// Live activities, one-shot or ongoing, come and go on their own spring.
    private var activityMotion: Animation? {
        if reduceMotion { return .easeInOut(duration: 0.12) }
        return preferences.animationStyle == .instant ? nil : .spring(response: 0.3, dampingFraction: 0.85)
    }

    /// Opening and closing in the user's chosen style. Hover only nudges and live activities keep
    /// their own spring; Reduce Motion swaps everything for a short ease.
    private func motion(for presentation: NotchPresentationState) -> Animation? {
        if reduceMotion { return .easeInOut(duration: 0.12) }
        let style = preferences.animationStyle
        switch presentation {
        case .hoverArmed: return style == .instant ? nil : .easeOut(duration: 0.12)
        case .transient: return activityMotion
        default: break
        }
        let opening = presentation.openTab != nil
        switch style {
        case .spring:
            return opening
                ? .spring(response: 0.32, dampingFraction: 0.78) : .spring(response: 0.24, dampingFraction: 0.95)
        case .jelly:
            return opening
                ? .spring(response: 0.5, dampingFraction: 0.55) : .spring(response: 0.38, dampingFraction: 0.66)
        case .pop:
            return opening
                ? .spring(response: 0.3, dampingFraction: 0.6) : .spring(response: 0.22, dampingFraction: 0.82)
        case .smooth: return .easeInOut(duration: opening ? 0.34 : 0.26)
        case .snappy: return .snappy(duration: opening ? 0.2 : 0.15)
        case .instant: return nil
        }
    }

    /// Squash-and-stretch beats layered on the size change. Jelly squashes wide, stretches down, and
    /// wobbles into place; Pop springs up from slightly smaller. Other styles hold still.
    @KeyframesBuilder<Squash>
    private func squashKeyframes(opening: Bool) -> some Keyframes<Squash> {
        let style = reduceMotion ? NotchAnimationStyle.smooth : preferences.animationStyle
        let (x, y): ([CGFloat], [CGFloat]) =
            switch (style, opening) {
            case (.jelly, true): ([1, 1.06, 0.97, 1.01], [1, 0.9, 1.04, 0.99])
            case (.jelly, false): ([1, 1.04, 0.98, 1], [1, 0.94, 1.02, 1])
            case (.pop, true): ([0.92, 1.03, 0.995, 1], [0.92, 1.03, 0.995, 1])
            case (.pop, false): ([1, 0.96, 1.01, 1], [1, 0.96, 1.01, 1])
            default: ([1, 1, 1, 1], [1, 1, 1, 1])
            }
        KeyframeTrack(\.x) {
            MoveKeyframe(x[0])
            SpringKeyframe(x[1], duration: 0.12)
            SpringKeyframe(x[2], duration: 0.16)
            SpringKeyframe(x[3], duration: 0.14)
            SpringKeyframe(1, duration: 0.2)
        }
        KeyframeTrack(\.y) {
            MoveKeyframe(y[0])
            SpringKeyframe(y[1], duration: 0.12)
            SpringKeyframe(y[2], duration: 0.16)
            SpringKeyframe(y[3], duration: 0.14)
            SpringKeyframe(1, duration: 0.2)
        }
    }

    private func expanded(tab: FeatureID, pinned: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: Self.tabSpacing) {
                tabBar(selected: tab)
                Spacer(minLength: 0)
                headerButton(pinned ? "pin.fill" : "pin", label: pinned ? "Unpin" : "Pin", lit: pinned) {
                    engine.send(.togglePin)
                }
                headerButton("gearshape", label: "Settings") { content.openSettings() }
            }
            content.tab(tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // Overlay scroll bars would sit on top of charts and lists; faded edges show there's more.
                .scrollIndicators(.never)
                .id(tab)
                .transition(tabTransition)
                .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74), value: tab)
        }
        .padding(contentPadding)
        .overlay(alignment: .bottomTrailing) {
            // The grip's corner sits 10 pt in from the notch's visible corner along both edges, inside
            // its 24–26 pt rounding, in the margin beside and under the content.
            resizeGrip
                .padding(.trailing, contentPadding.trailing - 22 + 10)
                .padding(.bottom, 10)
        }
        .foregroundStyle(.white)
    }

    private static let expandedTopRadius: CGFloat = 10
    private static let expandedBottomRadius: CGFloat = 26

    /// Expanded content keeps 22 pt of black around it, measured from the visible edge: the sides of
    /// the notch outline sit inside its frame by the top radius, and the bottom corners are rounded.
    private var contentPadding: EdgeInsets {
        let side = (metrics.notch == nil ? 0 : Self.expandedTopRadius) + 22
        return EdgeInsets(top: (metrics.notch?.height ?? 0) + 10, leading: side, bottom: 22, trailing: side)
    }

    private static let tabSpacing: CGFloat = 2
    private static let headerButtonWidth: CGFloat = 26

    /// The widest tab that still fits every tab, the pin, and settings into the smallest open size,
    /// up to 32 pt. Tabs keep that width at every size, and each tab added makes them a little
    /// narrower instead of crowding the row.
    private var tabWidth: CGFloat {
        let room =
            NotchPreferences.minimumExpandedSize.width - contentPadding.leading - contentPadding.trailing
            - 2 * (Self.headerButtonWidth + Self.tabSpacing)
        let count = CGFloat(max(engine.state.tabs.count, 1))
        return min(32, ((room - Self.tabSpacing * (count - 1)) / count).rounded(.down))
    }

    private func tabBar(selected: FeatureID) -> some View {
        let tabs = engine.state.tabs
        let tabWidth = tabWidth
        return HStack(spacing: Self.tabSpacing) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    // Content slides the same way the selection travels.
                    slideForward = (tabs.firstIndex(of: tab) ?? 0) >= (tabs.firstIndex(of: selected) ?? 0)
                    engine.send(.selectTab(tab))
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: tabWidth, height: 26)
                        .scaleEffect(tab == selected ? 1.08 : 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .matchedGeometryEffect(id: tab, in: selection)  // a slot the capsule can move to
                .help(tab.title)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == selected ? .isSelected : [])
            }
        }
        .background {
            // One capsule travels between tabs: a bouncy spring carries it, and a quick
            // stretch-and-settle makes the move read as jelly instead of a jump.
            Capsule()
                .fill(.white.opacity(0.16))
                .matchedGeometryEffect(id: selected, in: selection, isSource: false)
                .keyframeAnimator(initialValue: CGSize(width: 1, height: 1), trigger: selected) { capsule, scale in
                    capsule.scaleEffect(scale)
                } keyframes: { _ in
                    let stretch: CGFloat = reduceMotion ? 1 : 1.3
                    KeyframeTrack(\.width) {
                        SpringKeyframe(stretch, duration: 0.12)
                        SpringKeyframe(reduceMotion ? 1 : 0.94, duration: 0.14)
                        SpringKeyframe(1, duration: 0.24)
                    }
                    KeyframeTrack(\.height) {
                        SpringKeyframe(2 - stretch, duration: 0.12)
                        SpringKeyframe(reduceMotion ? 1 : 1.05, duration: 0.14)
                        SpringKeyframe(1, duration: 0.24)
                    }
                }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.64), value: selected)
    }

    /// Content slides in from the side the selection moved toward, with a little scale and fade.
    private var tabTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let incoming: Edge = slideForward ? .trailing : .leading
        let outgoing: Edge = slideForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: incoming).combined(with: .opacity).combined(with: .scale(scale: 0.96)),
            removal: .move(edge: outgoing).combined(with: .opacity))
    }

    /// The size a corner drag asks for, in whole points: the notch grows to both sides of its center
    /// and down from the screen's edge, so the width moves twice as far as the pointer.
    static func resized(_ start: CGSize, by drag: CGSize) -> CGSize {
        CGSize(width: (start.width + 2 * drag.width).rounded(), height: (start.height + drag.height).rounded())
    }

    private func headerButton(_ symbol: String, label: String, lit: Bool = false, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: Self.headerButtonWidth, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(lit ? 1 : 0.75))
        .help(label)
        .accessibilityLabel(label)
    }

    /// Drag the corner to resize, anywhere between the smallest and largest size. The notch grows from
    /// its center, so width moves twice as far as the pointer and the corner stays under it. Holding the
    /// button keeps the notch open even past its edge. VoiceOver steps through sizes instead.
    private var resizeGrip: some View {
        ResizeGrip(active: resizeStart != nil)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .gesture(
                // Global: the grip moves with the corner, so a local translation would chase itself.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        let start = resizeStart ?? preferences.expandedSize
                        resizeStart = start
                        preferences.resizeExpanded(to: Self.resized(start, by: drag.translation))
                    }
                    .onEnded { _ in resizeStart = nil }
            )
            .resizeCursor()
            .help("Drag to resize")
            .accessibilityElement()
            .accessibilityLabel("Resize")
            .accessibilityValue("\(Int(preferences.expandedSize.width)) by \(Int(preferences.expandedSize.height))")
            .accessibilityAdjustableAction { direction in
                guard let next = preferences.expandedSizeStep(larger: direction == .increment) else { return }
                withAnimation(motion(for: engine.state.presentation)) { preferences.resizeExpanded(to: next) }
            }
    }

    /// A live activity: its symbol and title snug against either side of the physical notch, on wings
    /// just wide enough for the title, or, for a level like the volume or the battery's charge, one
    /// row as wide as the notch just below it. A countdown shows the time left in place of the
    /// title, which VoiceOver still reads.
    private func live(_ activity: Activity, ongoing: Bool = false) -> some View {
        Group {
            if let level = activity.level {
                levelRow(activity, level: level)
            } else {
                let wing = NotchMetrics.wing(for: activity, ongoing: ongoing)
                HStack(spacing: 0) {
                    Image(systemName: activity.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.trailing, NotchMetrics.wingInset)
                        .frame(width: wing, alignment: .trailing)
                    // Nothing under the camera housing, where it couldn't be seen.
                    Color.clear.frame(width: metrics.housing.width)
                    Group {
                        if let countdown = activity.countdown {
                            // ponytail: redraws once a second while a countdown shows; a per-minute
                            // timeline if a soak ever notices.
                            let now = Date.now
                            let left = Text(timerInterval: now...max(countdown, now), countsDown: true)
                            left.monospacedDigit().accessibilityLabel(activity.title).accessibilityValue(left)
                        } else {
                            Text(activity.title)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .padding(.leading, NotchMetrics.wingInset)
                    .padding(.trailing, NotchMetrics.wingOutset)
                    .frame(width: wing, alignment: .leading)
                }
                .frame(height: metrics.housing.height)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }

    /// Symbol, meter, and value side by side, under the camera housing (or inside the pill).
    private func levelRow(_ activity: Activity, level: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: activity.symbol)
                .font(.system(size: 12, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 20)
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(height: 5)
                .overlay(alignment: .leading) {
                    GeometryReader { track in
                        Capsule().fill(.white).frame(width: track.size.width * min(max(level, 0), 1))
                    }
                }
                .accessibilityHidden(true)
            // The value gets its room before the meter, which takes what's left: "Claude 85%", not "Claude 8…".
            Text(activity.title)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .frame(minWidth: 30, alignment: .trailing)
                .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .frame(height: metrics.notch == nil ? metrics.housing.height : NotchMetrics.meterDepth)
        .padding(.top, metrics.notch == nil ? 0 : metrics.housing.height)
    }
}

/// Three diagonal strokes that run from the right edge to the bottom edge, like a window's resize
/// corner. They brighten under the pointer and while dragging.
private struct ResizeGrip: View {
    let active: Bool
    @State private var hovering = false

    var body: some View {
        Canvas { context, size in
            var strokes = Path()
            for inset in [4.0, 8.0, 12.0] {
                strokes.move(to: CGPoint(x: size.width, y: size.height - inset))
                strokes.addLine(to: CGPoint(x: size.width - inset, y: size.height))
            }
            context.stroke(strokes, with: .color(.white), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .opacity(active ? 0.95 : hovering ? 0.75 : 0.5)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityHidden(true)
    }
}

extension View {
    /// The diagonal resize cursor, where macOS has one (15 and later).
    @ViewBuilder fileprivate func resizeCursor() -> some View {
        if #available(macOS 15, *) {
            pointerStyle(.frameResize(position: .bottomTrailing))
        } else {
            self
        }
    }
}
