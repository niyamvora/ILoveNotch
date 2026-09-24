// SPDX-License-Identifier: MIT
import CoreGraphics
import Testing

@testable import NotchSurface

/// Replaces the prototype's `--selftest` flag: the same invariants, run against
/// representative displays instead of whatever screens the build machine has.
struct NotchGeometryTests {
    static let screens = [
        CGRect(x: 0, y: 0, width: 1512, height: 982),  // 14-inch MacBook Pro
        CGRect(x: 0, y: 0, width: 1728, height: 1117),  // 16-inch MacBook Pro
        CGRect(x: -2560, y: 180, width: 2560, height: 1440),  // external display left of the built-in one
    ]
    static let notches = [CGSize(width: 185, height: 32), NotchGeometry.fallbackNotch]

    @Test(arguments: screens, notches)
    func framesHugTheTopCenterOfTheScreen(screen: CGRect, notch: CGSize) {
        let closed = NotchGeometry.closedFrame(screen: screen, notch: notch)
        let open = NotchGeometry.openFrame(screen: screen, notch: notch)

        #expect(abs(closed.midX - screen.midX) < 0.5)
        #expect(abs(open.midX - screen.midX) < 0.5)
        #expect(abs(closed.maxY - screen.maxY) < 0.5)
        #expect(abs(open.maxY - screen.maxY) < 0.5)
        #expect(closed.width > notch.width, "closed frame must cover the physical notch")
        #expect(open.width >= closed.width)
        #expect(open.height > closed.height)
        #expect(screen.contains(closed))
        #expect(screen.contains(open))
    }

    @Test func notchIsTheGapBetweenTheAuxiliaryAreas() {
        let size = NotchGeometry.notchSize(
            safeAreaTop: 32,
            left: CGRect(x: 0, y: 950, width: 662, height: 32),
            right: CGRect(x: 850, y: 950, width: 662, height: 32)
        )
        #expect(size == CGSize(width: 188, height: 32))
    }

    @Test func notchlessScreenFallsBackToThePill() {
        #expect(NotchGeometry.notchSize(safeAreaTop: 0, left: nil, right: nil) == NotchGeometry.fallbackNotch)
        // Insets without auxiliary areas are not trusted as a notch either.
        #expect(NotchGeometry.notchSize(safeAreaTop: 24, left: nil, right: nil) == NotchGeometry.fallbackNotch)
    }
}
