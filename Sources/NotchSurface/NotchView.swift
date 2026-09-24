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

/// One display's notch. The panel around it never moves; this view animates one shape between
/// every presentation, so SwiftUI is the only animation owner.
struct NotchView: View {
    let engine: NotchEngine
    let metrics: NotchMetrics
    let content: NotchContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var dropTargeted = false
    @State private var justDropped = false
    @State private var slideForward = true
    @Namespace private var selection

    var body: some View {
        let presentation = engine.state.presentation
        let size = metrics.size(for: presentation)
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

    /// Expanding springs open (~320 ms); collapsing is faster with little bounce; hover only nudges.
    /// Reduce Motion swaps all of it for a short crossfade-speed ease.
    private func motion(for presentation: NotchPresentationState) -> Animation {
        if reduceMotion { return .easeInOut(duration: 0.12) }
        switch presentation {
        case .expanded, .pinned, .focused: return .spring(response: 0.32, dampingFraction: 0.78)
        case .hoverArmed: return .easeOut(duration: 0.12)
        case .transient: return .spring(response: 0.3, dampingFraction: 0.85)
        default: return .spring(response: 0.24, dampingFraction: 0.95)
        }
    }

    private func expanded(tab: FeatureID, pinned: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                tabBar(selected: tab)
                Spacer(minLength: 0)
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
