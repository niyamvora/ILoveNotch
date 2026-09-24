// SPDX-License-Identifier: MIT
import AppKit
import NotchCore

/// Sizes and placement of one display's notch surface. Measurements come from PUBLIC AppKit APIs
/// (safeAreaInsets, auxiliaryTop*Area): no private frameworks. The math is pure, so tests run it
/// against representative displays instead of whatever screens the build machine has.
struct NotchMetrics: Equatable {
    /// The display's frame in global coordinates.
    var screen: CGRect
    /// The physical notch, or nil on a notchless display.
    var notch: CGSize?

    static let lip = CGSize(width: 20, height: 6)  // black lip around the physical notch
    static let pill = CGSize(width: 180, height: 26)  // resting shape on a notchless display
    static let pillInset: CGFloat = 3  // gap above the floating pill
    static let hoverGrowth = CGSize(width: 12, height: 4)  // hover feedback
    static let activityWing: CGFloat = 96  // room beside the notch for a live activity
    static let expanded = CGSize(width: 460, height: 290)

    /// The notch is the gap between the two auxiliary top areas; no insets means no notch.
    init(screen: CGRect, safeAreaTop: CGFloat, left: CGRect?, right: CGRect?) {
        self.screen = screen
        if safeAreaTop > 0, let left, let right {
            notch = CGSize(width: max(0, right.minX - left.maxX), height: safeAreaTop)
        }
    }

    init(screen: NSScreen) {
        self.init(
            screen: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            left: screen.auxiliaryTopLeftArea,
            right: screen.auxiliaryTopRightArea
        )
    }

    /// Resting shape: a black lip hugging the physical notch, or a small pill on notchless displays.
    var compactSize: CGSize {
        guard let notch else { return Self.pill }
        return CGSize(width: notch.width + Self.lip.width * 2, height: notch.height + Self.lip.height)
    }

    var expandedSize: CGSize {
        CGSize(width: max(Self.expanded.width, compactSize.width + 80), height: Self.expanded.height)
    }

    func size(for presentation: NotchPresentationState) -> CGSize {
        switch presentation {
        case .hidden, .suspended, .compact:
            compactSize
        case .hoverArmed:
            CGSize(
                width: compactSize.width + Self.hoverGrowth.width,
                height: compactSize.height + Self.hoverGrowth.height)
        case .transient:
            CGSize(width: compactSize.width + Self.activityWing * 2, height: compactSize.height)
        case .expanded, .pinned, .focused:
            expandedSize
        }
    }

    /// Gap between the top of the display and the shape: none on a notch, a little above a pill.
    var topInset: CGFloat { notch == nil ? Self.pillInset : 0 }

    /// The fixed panel: big enough for every state and pinned to the top center, so the window
    /// never moves or resizes; only the shape inside it animates.
    var panelFrame: CGRect {
        let states: [NotchPresentationState] = [.hoverArmed, .transient(Self.sizingActivity), .expanded(tab: .media)]
        let sizes = states.map(size(for:))
        let width = sizes.map(\.width).max()!
        let height = sizes.map(\.height).max()! + topInset
        return CGRect(x: screen.midX - width / 2, y: screen.maxY - height, width: width, height: height)
    }

    private static let sizingActivity = Activity(feature: .media, symbol: "", title: "", duration: .zero)
}
