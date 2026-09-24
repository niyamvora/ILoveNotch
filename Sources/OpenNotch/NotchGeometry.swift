import AppKit

/// All notch measurements come from PUBLIC AppKit APIs (safeAreaInsets,
/// auxiliaryTop*Area) — no private frameworks, no reverse engineering.
enum NotchGeometry {
    static let openWidth: CGFloat = 380
    static let openHeight: CGFloat = 260
    static let closedPadX: CGFloat = 20   // black lip flanking the physical notch
    static let closedPadY: CGFloat = 6
    // ponytail: fallback pill for Macs with no notch; tune if it looks off on external displays.
    static let fallbackNotch = CGSize(width: 200, height: 32)

    static func notchSize(for screen: NSScreen) -> CGSize {
        let top = screen.safeAreaInsets.top
        if top > 0, let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            return CGSize(width: max(0, r.minX - l.maxX), height: top)
        }
        return fallbackNotch
    }

    static func notchHeight(for screen: NSScreen) -> CGFloat { notchSize(for: screen).height }

    /// Small black rect hugging the notch — the resting hover target.
    static func closedWindowFrame(for screen: NSScreen) -> CGRect {
        let n = notchSize(for: screen)
        let w = n.width + closedPadX * 2
        let h = n.height + closedPadY
        let f = screen.frame
        return CGRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
    }

    /// Expanded panel hanging below the notch.
    static func openWindowFrame(for screen: NSScreen) -> CGRect {
        let f = screen.frame
        let w = max(openWidth, notchSize(for: screen).width + closedPadX * 2)
        return CGRect(x: f.midX - w / 2, y: f.maxY - openHeight, width: w, height: openHeight)
    }

    /// One runnable check (ponytail): fails loudly if the geometry math breaks.
    static func selfCheck() {
        let screens = NSScreen.screens
        assert(!screens.isEmpty, "no screens")
        for s in screens {
            let n = notchSize(for: s)
            let closed = closedWindowFrame(for: s)
            let open = openWindowFrame(for: s)
            assert(n.width > 0 && n.height > 0, "notch size must be positive")
            assert(abs(closed.midX - s.frame.midX) < 0.5, "closed not horizontally centered")
            assert(abs(open.midX - s.frame.midX) < 0.5, "open not horizontally centered")
            assert(abs(closed.maxY - s.frame.maxY) < 0.5, "closed must touch screen top")
            assert(abs(open.maxY - s.frame.maxY) < 0.5, "open must touch screen top")
            assert(open.width >= closed.width, "open must be at least as wide as closed")
            assert(open.height > closed.height, "open must be taller than closed")
            assert(s.frame.insetBy(dx: -1, dy: -1).contains(closed), "closed frame off-screen")
        }
    }
}
