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
    /// Where the notch is centered: the middle of the gap, which can sit a hair off the display's
    /// center (half a point left on a 14" MacBook Pro), or the display's center without a notch.
    var centerX: CGFloat

    static let flare: CGFloat = 6  // the outline's flared top corners, which meet the screen edge
    static let pill = CGSize(width: 180, height: 26)  // resting shape on a notchless display
    static let pillInset: CGFloat = 3  // gap above the floating pill
    static let hoverGrowth = CGSize(width: 12, height: 4)  // hover feedback
    static let activityWing: CGFloat = 96  // room beside the notch for a live activity
    static let overshootRoom: CGFloat = 1.08  // springy and jelly animations briefly overshoot

    /// The notch is the gap between the two auxiliary top areas; no insets means no notch.
    init(screen: CGRect, safeAreaTop: CGFloat, left: CGRect?, right: CGRect?) {
        self.screen = screen
        centerX = screen.midX
        if safeAreaTop > 0, let left, let right {
            notch = CGSize(width: max(0, right.minX - left.maxX), height: safeAreaTop)
            centerX = (left.maxX + right.minX) / 2
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

    /// The camera housing, or on a notchless display the pill that stands in for it.
    var housing: CGSize { notch ?? Self.pill }

    /// Resting shape: inside the camera housing, so a closed notch can't be seen. The gap between the
    /// auxiliary areas already includes the cutout's flared top corners (about 4 pt; its bottom
    /// corners are about 8 pt), so the outline's wider flare keeps its body inside the housing's
    /// sides, and it stops a point short of the housing's bottom edge. On notchless displays, a pill.
    var compactSize: CGSize {
        guard let notch else { return Self.pill }
        return CGSize(width: notch.width, height: notch.height - 1)
    }

    /// The open notch at the user's chosen size: never narrower than the notch plus room for the
    /// tabs, never larger than the display allows.
    func expandedSize(_ chosen: CGSize) -> CGSize {
        CGSize(
            width: min(max(chosen.width, housing.width + 80), screen.width - 32),
            height: min(chosen.height, screen.height * 0.6))
    }

    func size(
        for presentation: NotchPresentationState, expanded: CGSize = NotchPreferences.defaultExpandedSize
    ) -> CGSize {
        switch presentation {
        case .hidden, .suspended, .compact:
            compactSize
        case .hoverArmed:
            CGSize(width: housing.width + Self.hoverGrowth.width, height: housing.height + Self.hoverGrowth.height)
        case .transient:
            CGSize(width: housing.width + Self.activityWing * 2, height: housing.height)
        case .expanded, .pinned, .focused:
            expandedSize(expanded)
        }
    }

    /// Gap between the top of the display and the shape: none on a notch, a little above a pill.
    var topInset: CGFloat { notch == nil ? Self.pillInset : 0 }

    /// The fixed panel: big enough for every state at the largest size the notch can be resized to,
    /// with room for springy overshoot, pinned to the top and centered on the notch. The window never
    /// moves or resizes; only the shape inside it animates.
    var panelFrame: CGRect {
        let largest = [
            size(for: .hoverArmed), size(for: .transient(Self.sizingActivity)),
            size(for: .expanded(tab: .media), expanded: NotchPreferences.maximumExpandedSize),
        ]
        let width = min(largest.map(\.width).max()! * Self.overshootRoom, screen.width)
        let height = min(largest.map(\.height).max()! * Self.overshootRoom + topInset, screen.height)
        return CGRect(x: centerX - width / 2, y: screen.maxY - height, width: width, height: height)
    }

    private static let sizingActivity = Activity(feature: .media, symbol: "", title: "", duration: .zero)
}
