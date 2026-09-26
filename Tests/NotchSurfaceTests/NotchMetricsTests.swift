// SPDX-License-Identifier: MIT
import CoreGraphics
import NotchCore
import SwiftUI
import Testing

@testable import NotchSurface

/// As measured on hardware: the gap sits half a point left of the display's center.
private let macBookPro14 = NotchMetrics(
    screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
    left: CGRect(x: 0, y: 950, width: 663, height: 32), right: CGRect(x: 848, y: 950, width: 664, height: 32))
private let macBookPro16 = NotchMetrics(
    screen: CGRect(x: 0, y: 0, width: 1728, height: 1117), safeAreaTop: 38,
    left: CGRect(x: 0, y: 1079, width: 764, height: 38), right: CGRect(x: 964, y: 1079, width: 764, height: 38))
/// A notchless external display to the left of the built-in one.
private let external = NotchMetrics(
    screen: CGRect(x: -2560, y: 180, width: 2560, height: 1440), safeAreaTop: 0, left: nil, right: nil)
/// The same display with a notch drawn in its 24 pt menu bar, as wide as the MacBook's.
private let externalWithNotch = NotchMetrics(
    screen: CGRect(x: -2560, y: 180, width: 2560, height: 1440), safeAreaTop: 0, left: nil, right: nil,
    standIn: CGSize(width: 185, height: 24))

private let song = Activity(feature: .media, symbol: "music.note", title: "Song", duration: .seconds(2))
private let volume = Activity(
    feature: nil, symbol: "speaker.wave.2.fill", title: "50%", level: 0.5, duration: .seconds(1))

struct NotchMetricsTests {
    static let displays = [macBookPro14, macBookPro16, external, externalWithNotch]
    static let presentations: [NotchPresentationState] = [
        .compact, .hoverArmed, .transient(song), .transient(volume), .expanded(tab: .media), .pinned(tab: .notes),
        .focused(tab: .notes, pinned: false),
    ]

    @Test(arguments: displays)
    func thePanelIsPinnedToTheTopAndCenteredOnTheNotch(metrics: NotchMetrics) {
        let panel = metrics.panelFrame
        #expect(abs(panel.midX - metrics.centerX) < 0.001)
        #expect(abs(panel.maxY - metrics.screen.maxY) < 0.5)
        #expect(metrics.screen.contains(panel))
    }

    @Test(arguments: displays)
    func aLevelActivityKeepsToTheNotchsWidth(metrics: NotchMetrics) {
        let level = metrics.size(for: .transient(volume))
        let housing = metrics.housing
        #expect(level.width <= housing.width + NotchMetrics.hoverGrowth.width, "no wings beside the notch")
        #expect(level.width < metrics.size(for: .transient(song)).width)
        if metrics.notch != nil {
            #expect(level.height == housing.height + NotchMetrics.meterDepth, "its row sits under the camera")
        } else {
            #expect(level == housing, "inside the pill")
        }
    }

    @Test(arguments: displays)
    func anOngoingActivityGrowsNarrowerWingsThanAOneShotOne(metrics: NotchMetrics) {
        let awake = Activity(feature: .timer, symbol: "cup.and.saucer.fill", title: "Awake", duration: .zero)
        var state = NotchState()
        _ = state.handle(.show)
        _ = state.handle(.setOngoing(awake))
        let resting = metrics.size(for: state)
        #expect(resting.height == metrics.housing.height, "it stays in the menu bar")
        #expect(resting.width > metrics.housing.width && resting.width < metrics.size(for: .transient(song)).width)
        _ = state.handle(.clicked)
        #expect(metrics.size(for: state) == metrics.size(for: .expanded(tab: .timer)), "open, it's an open notch")
    }

    @Test(arguments: displays)
    func aPointerPushedAgainstTheTopEdgeIsOverTheNotch(metrics: NotchMetrics) {
        let compact = metrics.size(for: .compact)
        let frame = metrics.hoverFrame(for: compact, in: metrics.panelFrame)
        #expect(frame.contains(CGPoint(x: metrics.centerX, y: metrics.screen.maxY)), "the top edge is exactly maxY")
        let below = metrics.screen.maxY - metrics.topInset - compact.height - 0.5
        #expect(!frame.contains(CGPoint(x: metrics.centerX, y: below)), "below the notch is not over it")
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
        let housing = metrics.housing
        #expect(compact.width <= housing.width && compact.height <= housing.height)
        #expect(hover.width > housing.width && hover.height > housing.height, "hover shows past the housing")
        #expect(live.width > housing.width && live.height == housing.height, "activities widen, not deepen")
        #expect(open.width > live.width && open.height > housing.height)
    }

    /// The housing as measured on hardware: the gap between the auxiliary areas, with top corners
    /// that flare about 4 pt and bottom corners of about 8 pt when it's 32 pt tall.
    @Test(arguments: [macBookPro14, macBookPro16]) @MainActor
    func aClosedNotchHidesBehindTheCameraHousing(metrics: NotchMetrics) throws {
        let notch = try #require(metrics.notch)
        let housing = NotchShape(topRadius: notch.height / 8, bottomRadius: notch.height / 4)
            .path(in: CGRect(origin: .zero, size: notch))
        let size = metrics.size(for: .compact)
        let resting = NotchView.shape(for: .compact, on: metrics)
            .path(in: CGRect(x: (notch.width - size.width) / 2, y: 0, width: size.width, height: size.height))
        // Every Retina pixel the closed notch covers, around and under the housing, must be hidden.
        var showing: [CGPoint] = []
        for x in stride(from: -19.75, to: notch.width + 20, by: 0.5) {
            for y in stride(from: 0.25, to: notch.height + 10, by: 0.5) {
                let pixel = CGPoint(x: x, y: y)
                if resting.contains(pixel), !housing.contains(pixel) { showing.append(pixel) }
            }
        }
        #expect(showing.isEmpty, "shows past the housing at \(showing.prefix(4))")
        #expect(resting.contains(CGPoint(x: notch.width / 2, y: 1)), "and it's still there to hover over")
    }

    @Test(arguments: displays)
    func everyResizeFitsInsideTheFixedPanel(metrics: NotchMetrics) {
        for chosen in [NotchPreferences.minimumExpandedSize, NotchPreferences.maximumExpandedSize] {
            let size = metrics.size(for: .expanded(tab: .media), expanded: chosen)
            let panel = metrics.panelFrame
            #expect(size.width <= panel.width && size.height + metrics.topInset <= panel.height)
        }
    }

    @Test func theChosenSizeIsUsedButLeavesRoomBesideTheNotch() {
        #expect(macBookPro14.size(for: .pinned(tab: .notes), expanded: CGSize(width: 600, height: 380)).width == 600)
        let tiny = macBookPro14.size(for: .expanded(tab: .media), expanded: CGSize(width: 100, height: 300))
        #expect(tiny.width == macBookPro14.housing.width + 80)
    }

    @Test func theNotchIsTheGapBetweenTheAuxiliaryAreas() {
        #expect(macBookPro14.notch == CGSize(width: 185, height: 32))
        #expect(macBookPro14.centerX == 755.5, "half a point left of the display's center")
        #expect(external.centerX == external.screen.midX)
        #expect(macBookPro14.topInset == 0)
    }

    @Test func notchlessDisplaysGetAFloatingPill() {
        #expect(external.notch == nil)
        #expect(external.size(for: .compact) == NotchMetrics.pill)
        #expect(external.topInset == NotchMetrics.pillInset)
    }

    @Test func aDisplayWithoutANotchCanHaveOneDrawnInsideItsMenuBar() {
        #expect(externalWithNotch.notch == CGSize(width: 185, height: 24))
        #expect(externalWithNotch.topInset == 0, "flush with the top edge, like a real one")
        #expect(externalWithNotch.size(for: .compact) == CGSize(width: 185, height: 23), "inside the menu bar")
        #expect(externalWithNotch.centerX == externalWithNotch.screen.midX)
        let real = NotchMetrics(
            screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            left: CGRect(x: 0, y: 950, width: 663, height: 32), right: CGRect(x: 848, y: 950, width: 664, height: 32),
            standIn: CGSize(width: 100, height: 20))
        #expect(real.notch == CGSize(width: 185, height: 32), "a real notch wins over a stand-in")
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
