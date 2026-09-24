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
    @State private var resizeOrigin: CGSize?
    @Namespace private var selection

    var body: some View {
        let presentation = engine.state.presentation
        let size = metrics.size(for: presentation, expanded: preferences.expandedSize)
        let outline = shape(for: presentation)
        ZStack(alignment: .top) {
            outline.fill(.black)
            if let tab = presentation.openTab {
                expanded(tab: tab, pinned: presentation.isPinned)
                    .transition(.opacity)
            } else if case .transient(let activity) = presentation {
                live(activity)
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
        .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.8), value: dropTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("OpenNotch")
        .accessibilityAction(named: presentation.openTab == nil ? "Open" : "Close") {
            engine.send(presentation.openTab == nil ? .clicked : .dismiss)
        }
        .padding(.top, metrics.topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func shape(for presentation: NotchPresentationState) -> NotchShape {
        let open = presentation.openTab != nil
        guard metrics.notch != nil else {
            return NotchShape(topRadius: 0, bottomRadius: open ? 24 : Self.pillRadius, flushTop: false)
        }
        switch presentation {
        case .expanded, .pinned, .focused:
            return NotchShape(topRadius: Self.expandedTopRadius, bottomRadius: Self.expandedBottomRadius)
        case .hoverArmed, .transient: return NotchShape(topRadius: 6, bottomRadius: 13)
        default: return NotchShape(topRadius: 6, bottomRadius: 10)
        }
    }

    private static let pillRadius: CGFloat = 100  // clamped to a capsule

    /// Opening and closing in the user's chosen style. Hover only nudges and live activities keep
    /// their own spring; Reduce Motion swaps everything for a short ease.
    private func motion(for presentation: NotchPresentationState) -> Animation? {
        if reduceMotion { return .easeInOut(duration: 0.12) }
        let style = preferences.animationStyle
        switch presentation {
        case .hoverArmed: return style == .instant ? nil : .easeOut(duration: 0.12)
        case .transient: return style == .instant ? nil : .spring(response: 0.3, dampingFraction: 0.85)
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
            HStack(spacing: 4) {
                tabBar(selected: tab)
                Spacer(minLength: 0)
                resizeControl
                iconButton(pinned ? "pin.fill" : "pin", label: pinned ? "Unpin" : "Pin") {
                    engine.send(.togglePin)
                }
                iconButton("gearshape", label: "Settings") { content.openSettings() }
            }
            content.tab(tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .id(tab)
                .transition(tabTransition)
                .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74), value: tab)
        }
        .padding(contentPadding)
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

    private func tabBar(selected: FeatureID) -> some View {
        let tabs = engine.state.tabs
        return HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    // Content slides the same way the selection travels.
                    slideForward = (tabs.firstIndex(of: tab) ?? 0) >= (tabs.firstIndex(of: selected) ?? 0)
                    engine.send(.selectTab(tab))
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 26)
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

    /// Drag to resize the open notch; it grows from its top center, so the width follows the drag at
    /// twice the speed. Click to step through small, medium, and large. The notch won't collapse
    /// mid-drag: the engine's pointer check sees the held mouse button.
    private var resizeControl: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 26, height: 26)
            .contentShape(Rectangle())
            .foregroundStyle(.white.opacity(resizeOrigin == nil ? 0.75 : 1))
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { drag in
                        let origin = resizeOrigin ?? preferences.expandedSize
                        resizeOrigin = origin
                        preferences.resizeExpanded(
                            to: CGSize(
                                width: origin.width + drag.translation.width * 2,
                                height: origin.height + drag.translation.height))
                    }
                    .onEnded { _ in resizeOrigin = nil }
            )
            .onTapGesture {
                withAnimation(motion(for: engine.state.presentation)) { preferences.cycleExpandedSize() }
            }
            .help("Drag to resize. Click to switch between small, medium, and large.")
            .accessibilityLabel("Resize")
            .accessibilityAction(named: "Next size") { preferences.cycleExpandedSize() }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.75))
        .help(label)
        .accessibilityLabel(label)
    }

    /// A live activity sits on either side of the physical notch.
    private func live(_ activity: Activity) -> some View {
        HStack(spacing: 0) {
            Image(systemName: activity.symbol)
                .font(.system(size: 13, weight: .semibold))
            Spacer(minLength: metrics.compactSize.width)
            Text(activity.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: metrics.compactSize.height)
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}
