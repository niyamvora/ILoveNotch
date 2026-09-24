// SPDX-License-Identifier: MIT
import CoreGraphics
import NotchCore
import SwiftUI
import Testing

@testable import NotchSurface

private let macBookPro14 = NotchMetrics(
    screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
    left: CGRect(x: 0, y: 950, width: 662, height: 32), right: CGRect(x: 850, y: 950, width: 662, height: 32))
private let macBookPro16 = NotchMetrics(
    screen: CGRect(x: 0, y: 0, width: 1728, height: 1117), safeAreaTop: 38,
    left: CGRect(x: 0, y: 1079, width: 764, height: 38), right: CGRect(x: 964, y: 1079, width: 764, height: 38))
/// A notchless external display to the left of the built-in one.
private let external = NotchMetrics(
    screen: CGRect(x: -2560, y: 180, width: 2560, height: 1440), safeAreaTop: 0, left: nil, right: nil)

private let song = Activity(feature: .media, symbol: "music.note", title: "Song", duration: .seconds(2))

struct NotchMetricsTests {
    static let displays = [macBookPro14, macBookPro16, external]
    static let presentations: [NotchPresentationState] = [
        .compact, .hoverArmed, .transient(song), .expanded(tab: .media), .pinned(tab: .notes),
        .focused(tab: .notes, pinned: false),
    ]

    @Test(arguments: displays)
    func thePanelIsPinnedToTheTopCenterOfItsDisplay(metrics: NotchMetrics) {
        let panel = metrics.panelFrame
        #expect(abs(panel.midX - metrics.screen.midX) < 0.5)
        #expect(abs(panel.maxY - metrics.screen.maxY) < 0.5)
        #expect(metrics.screen.contains(panel))
    }

    @Test(arguments: displays, presentations)
    func everyStateFitsInsideTheFixedPanel(metrics: NotchMetrics, presentation: NotchPresentationState) {
        let size = metrics.size(for: presentation)
        #expect(size.width <= metrics.panelFrame.width)
        #expect(size.height + metrics.topInset <= metrics.panelFrame.height)
    }

    @Test(arguments: displays)
    func statesGrowInTheRightOrder(metrics: NotchMetrics) {
        let compact = metrics.size(for: .compact)
        let hover = metrics.size(for: .hoverArmed)
        let live = metrics.size(for: .transient(song))
        let open = metrics.size(for: .expanded(tab: .media))
        #expect(hover.width > compact.width && hover.height > compact.height, "hover gives visible feedback")
        #expect(live.width > compact.width && live.height == compact.height, "activities widen, not deepen")
        #expect(open.width > live.width && open.height > compact.height)
        if let notch = metrics.notch {
            #expect(compact.width > notch.width && compact.height > notch.height, "the lip covers the notch")
        }
    }

    @Test func theNotchIsTheGapBetweenTheAuxiliaryAreas() {
        #expect(macBookPro14.notch == CGSize(width: 188, height: 32))
        #expect(macBookPro14.topInset == 0)
    }

    @Test func notchlessDisplaysGetAFloatingPill() {
        #expect(external.notch == nil)
        #expect(external.size(for: .compact) == NotchMetrics.pill)
        #expect(external.topInset == NotchMetrics.pillInset)
    }

    @Test func insetsWithoutAuxiliaryAreasAreNotANotch() {
        let metrics = NotchMetrics(
            screen: CGRect(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 24, left: nil, right: nil)
        #expect(metrics.notch == nil)
    }
}

struct NotchShapeTests {
    private let rect = CGRect(x: 0, y: 0, width: 200, height: 40)

    @Test func theNotchOutlineIsFlushWithTheTopAndRoundedBelow() {
        let path = NotchShape(topRadius: 6, bottomRadius: 10).path(in: rect)
        let bounds = path.boundingRect
        #expect(abs(bounds.minY) < 0.01 && abs(bounds.maxY - 40) < 0.01)
        #expect(abs(bounds.minX) < 0.01 && abs(bounds.maxX - 200) < 0.01)
        #expect(path.contains(CGPoint(x: 4, y: 0.5)), "top corners flare out along the top edge")
        #expect(!path.contains(CGPoint(x: 1, y: 20)), "below the flare the sides are inset")
        #expect(!path.contains(CGPoint(x: 7, y: 39.5)), "bottom corners are rounded")
        #expect(path.contains(CGPoint(x: 100, y: 20)))
    }

    @Test func aFloatingOutlineIsACapsule() {
        let path = NotchShape(topRadius: 0, bottomRadius: 100, flushTop: false).path(in: rect)
        #expect(path.contains(CGPoint(x: 100, y: 20)))
        #expect(!path.contains(CGPoint(x: 1, y: 1)), "no square corners")
    }
}
