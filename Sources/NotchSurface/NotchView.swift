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
    @Namespace private var selection

    var body: some View {
        let presentation = engine.state.presentation
        let size = metrics.size(for: presentation)
        let outline = shape(for: presentation)
        ZStack(alignment: .top) {
            outline.fill(.black)
            if contrast == .increased {
                outline.stroke(.white.opacity(0.45), lineWidth: 1)
            }
            if dropTargeted {
                outline.stroke(Color.accentColor, lineWidth: 2).shadow(color: .accentColor, radius: 6)
            }
            if let tab = presentation.openTab {
                expanded(tab: tab, pinned: presentation.isPinned)
                    .transition(.opacity)
            } else if case .transient(let activity) = presentation {
                live(activity)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
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
        case .expanded, .pinned, .focused: return NotchShape(topRadius: 10, bottomRadius: 26)
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
                .transition(.opacity)
        }
        .padding(.top, (metrics.notch?.height ?? 0) + 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .foregroundStyle(.white)
    }

    private func tabBar(selected: FeatureID) -> some View {
        HStack(spacing: 2) {
            ForEach(engine.state.tabs, id: \.self) { tab in
                Button {
                    engine.send(.selectTab(tab))
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 26)
                        .background {
                            if tab == selected {
                                Capsule()
                                    .fill(.white.opacity(0.16))
                                    .matchedGeometryEffect(id: "selection", in: selection)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tab.title)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == selected ? .isSelected : [])
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.17, dampingFraction: 0.9), value: selected)
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
