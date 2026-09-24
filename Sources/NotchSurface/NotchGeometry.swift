// SPDX-License-Identifier: MIT
import AppKit

/// All notch measurements come from PUBLIC AppKit APIs (safeAreaInsets,
/// auxiliaryTop*Area): no private frameworks, no reverse engineering.
/// The math is pure (rects in, rects out) so tests can run it without a real display.
enum NotchGeometry {
    static let openWidth: CGFloat = 380
    static let openHeight: CGFloat = 260
    static let closedPadX: CGFloat = 20  // black lip flanking the physical notch
    static let closedPadY: CGFloat = 6
    // ponytail: fallback pill for Macs with no notch; tune if it looks off on external displays.
    static let fallbackNotch = CGSize(width: 200, height: 32)

    /// The notch is the gap between the two auxiliary top areas; no insets means no notch.
    static func notchSize(safeAreaTop top: CGFloat, left: CGRect?, right: CGRect?) -> CGSize {
        guard top > 0, let left, let right else { return fallbackNotch }
        return CGSize(width: max(0, right.minX - left.maxX), height: top)
    }

    /// Small black rect hugging the notch: the resting hover target.
    static func closedFrame(screen: CGRect, notch: CGSize) -> CGRect {
        let w = notch.width + closedPadX * 2
        let h = notch.height + closedPadY
        return CGRect(x: screen.midX - w / 2, y: screen.maxY - h, width: w, height: h)
    }

    /// Expanded panel hanging below the notch.
    static func openFrame(screen: CGRect, notch: CGSize) -> CGRect {
        let w = max(openWidth, notch.width + closedPadX * 2)
        return CGRect(x: screen.midX - w / 2, y: screen.maxY - openHeight, width: w, height: openHeight)
    }
}

extension NotchGeometry {
    static func notchSize(for screen: NSScreen) -> CGSize {
        notchSize(
            safeAreaTop: screen.safeAreaInsets.top,
            left: screen.auxiliaryTopLeftArea,
            right: screen.auxiliaryTopRightArea
        )
    }

    static func closedFrame(for screen: NSScreen) -> CGRect {
        closedFrame(screen: screen.frame, notch: notchSize(for: screen))
    }

    static func openFrame(for screen: NSScreen) -> CGRect {
        openFrame(screen: screen.frame, notch: notchSize(for: screen))
    }
}
