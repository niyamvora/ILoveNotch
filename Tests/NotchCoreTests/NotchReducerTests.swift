// SPDX-License-Identifier: MIT
import Testing

@testable import NotchCore

private let song = Activity(feature: .media, duration: .seconds(2))
private let drop = Activity(feature: .shelf, duration: .seconds(1))

/// The state a fresh reducer reaches after `events`.
private func after(_ events: NotchEvent...) -> NotchState { after(events) }

private func after(_ events: [NotchEvent]) -> NotchState {
    var state = NotchState()
    for event in events { _ = state.handle(event) }
    return state
}

struct NotchReducerTests {
    @Test func startsHiddenAndShowRevealsTheCompactNotch() {
        var state = NotchState()
        #expect(state.presentation == .hidden)
        #expect(state.handle(.show).isEmpty)
        #expect(state.presentation == .compact)
    }

    @Test(arguments: [NotchEvent.pointerEntered, .clicked, .selectTab(.notes), .activity(song), .suspend, .resume])
    func hiddenIgnoresEverythingButShow(event: NotchEvent) {
        var state = NotchState()
        #expect(state.handle(event).isEmpty)
        #expect(state.presentation == .hidden)
    }

    @Test func hoverExpandsOnlyAfterTheDwell() {
        var state = after(.show)
        #expect(state.handle(.pointerEntered) == [.schedule(.hoverDwell, after: NotchTiming.hoverDwell)])
        #expect(state.presentation == .hoverArmed)
        #expect(state.handle(.deadline(.hoverDwell)).isEmpty)
        #expect(state.presentation == .expanded(tab: .media))
    }

    @Test func aQuickPassDoesNotExpand() {
        var state = after(.show, .pointerEntered)
        #expect(state.handle(.pointerExited) == [.cancel(.hoverDwell)])
        #expect(state.presentation == .compact)
    }

    @Test func clickingExpandsWithoutWaiting() {
        #expect(after(.show, .clicked).presentation == .expanded(tab: .media))
        var state = after(.show, .pointerEntered)
        #expect(state.handle(.clicked) == [.cancel(.hoverDwell)])
        #expect(state.presentation == .expanded(tab: .media))
    }

    @Test func leavingStartsTheCollapseGraceAndReturningCancelsIt() {
        var state = after(.show, .clicked)
        #expect(state.handle(.pointerExited) == [.schedule(.collapseGrace, after: NotchTiming.collapseGrace)])
        #expect(state.handle(.pointerEntered) == [.cancel(.collapseGrace)])
        // A deadline that fires late, after the pointer came back, must not collapse the notch.
        #expect(state.handle(.deadline(.collapseGrace)).isEmpty)
        #expect(state.presentation == .expanded(tab: .media))
    }

    @Test func theGraceRunningOutCollapses() {
        var state = after(.show, .clicked, .pointerExited)
        #expect(state.handle(.deadline(.collapseGrace)).isEmpty)
        #expect(state.presentation == .compact)
    }

    @Test(arguments: [NotchEvent.clickedOutside, .dismiss])
    func clickAwayAndEscapeCloseTheExpandedNotch(event: NotchEvent) {
        #expect(after(.show, .clicked, event).presentation == .compact)
    }

    @Test func pinnedStaysOpenUntilDismissed() {
        var state = after(.show, .clicked, .togglePin)
        #expect(state.presentation == .pinned(tab: .media))
        #expect(state.handle(.pointerExited).isEmpty)
        #expect(state.handle(.clickedOutside).isEmpty)
        #expect(state.presentation == .pinned(tab: .media))
        #expect(state.handle(.dismiss).isEmpty)
        #expect(state.presentation == .compact)
    }

    @Test func pinningCancelsAPendingCollapse() {
        var state = after(.show, .clicked, .pointerExited)
        #expect(state.handle(.togglePin) == [.cancel(.collapseGrace)])
        #expect(state.presentation == .pinned(tab: .media))
        #expect(state.handle(.togglePin).isEmpty)
        #expect(state.presentation == .expanded(tab: .media))
    }

    @Test(arguments: [false, true])
    func textInputReturnsToWhereItStarted(pinned: Bool) {
        var state = after(pinned ? [.show, .clicked, .togglePin] : [.show, .clicked])
        _ = state.handle(.beginTextInput)
        #expect(state.presentation == .focused(tab: .media, pinned: pinned))
        // Moving the pointer away mid-sentence must not close the notch.
        #expect(state.handle(.pointerExited).isEmpty)
        _ = state.handle(.endTextInput)
        #expect(state.presentation == (pinned ? .pinned(tab: .media) : .expanded(tab: .media)))
    }

    @Test func clickingAwayEndsTextInputButKeepsAPin() {
        #expect(after(.show, .clicked, .beginTextInput, .clickedOutside).presentation == .compact)
        let pinned = after(.show, .clicked, .togglePin, .beginTextInput, .clickedOutside)
        #expect(pinned.presentation == .pinned(tab: .media))
    }

    @Test func switchingTabsEndsTextInputAndKeepsThePin() {
        let unpinned = after(.show, .clicked, .beginTextInput, .selectTab(.notes))
        #expect(unpinned.presentation == .expanded(tab: .notes))
        let pinned = after(.show, .clicked, .togglePin, .beginTextInput, .selectTab(.notes))
        #expect(pinned.presentation == .pinned(tab: .notes))
    }

    @Test func theLastTabIsRemembered() {
        #expect(after(.show, .clicked, .selectTab(.notes), .dismiss, .clicked).presentation == .expanded(tab: .notes))
    }

    @Test func anActivityShowsUntilItsDeadline() {
        var state = after(.show)
        #expect(state.handle(.activity(song)) == [.schedule(.activityEnd, after: song.duration)])
        #expect(state.presentation == .transient(song))
        #expect(state.handle(.deadline(.activityEnd)).isEmpty)
        #expect(state.presentation == .compact)
    }

    @Test func aNewActivityReplacesTheCurrentOne() {
        var state = after(.show, .activity(song))
        #expect(state.handle(.activity(drop)) == [.schedule(.activityEnd, after: drop.duration)])
        #expect(state.presentation == .transient(drop))
    }

    @Test func hoveringAnActivityOpensItsFeature() {
        var state = after(.show, .activity(drop))
        let effects = state.handle(.pointerEntered)
        #expect(effects == [.cancel(.activityEnd), .schedule(.hoverDwell, after: NotchTiming.hoverDwell)])
        _ = state.handle(.deadline(.hoverDwell))
        #expect(state.presentation == .expanded(tab: .shelf))
        #expect(after(.show, .activity(drop), .clicked).presentation == .expanded(tab: .shelf))
    }

    @Test func activitiesDoNotInterruptAnOpenNotch() {
        var state = after(.show, .clicked)
        #expect(state.handle(.activity(song)).isEmpty)
        #expect(state.presentation == .expanded(tab: .media))
    }

    @Test func suspendingDropsPendingWorkAndResumingStartsCompact() {
        var state = after(.show, .clicked, .pointerExited)
        #expect(state.handle(.suspend) == [.cancel(.collapseGrace)])
        #expect(state.handle(.clicked).isEmpty)
        #expect(state.handle(.activity(song)).isEmpty)
        #expect(state.presentation == .suspended)
        _ = state.handle(.resume)
        #expect(state.presentation == .compact)
    }

    @Test(arguments: [
        [NotchEvent.show], [.show, .pointerEntered], [.show, .clicked], [.show, .clicked, .togglePin],
        [.show, .clicked, .beginTextInput], [.show, .activity(song)], [.show, .suspend],
    ])
    func hideWorksFromEveryStateAndCancelsItsDeadline(path: [NotchEvent]) {
        var state = after(path)
        let owned = state.presentation.deadline
        #expect(state.handle(.hide) == (owned.map { [.cancel($0)] } ?? []))
        #expect(state.presentation == .hidden)
        #expect(!state.pointerInside)
    }

    /// Drives random events through the reducer while simulating a correct timer layer, checking
    /// after every step the invariants that the engine and the surface rely on.
    @Test func randomEventStreamsKeepTheInvariants() throws {
        var rng = SplitMix64(state: 0x0A11_CE5E_ED00_0001)
        let inputs: [NotchEvent] =
            [
                .show, .hide, .pointerEntered, .pointerExited, .clicked, .clickedOutside, .dismiss, .togglePin,
                .beginTextInput, .endTextInput, .activity(song), .activity(drop), .suspend, .resume,
            ] + FeatureID.allCases.map(NotchEvent.selectTab)
        var state = NotchState()
        var pending: Set<Deadline> = []
        var visited: Set<Substring> = []

        for _ in 0..<20_000 {
            let event: NotchEvent
            if let deadline = pending.first, Bool.random(using: &rng) {
                pending.remove(deadline)
                event = .deadline(deadline)
            } else {
                event = inputs.randomElement(using: &rng)!
            }
            for effect in state.handle(event) {
                switch effect {
                case .schedule(let deadline, _): pending.insert(deadline)
                case .cancel(let deadline): pending.remove(deadline)
                }
            }
            visited.insert(String(describing: state.presentation).prefix { $0 != "(" })

            let owned = Set([state.presentation.deadline].compactMap { $0 })
            try #require(pending.isSubset(of: owned), "\(event) left \(pending) pending in \(state.presentation)")
            if let tab = state.presentation.openTab { try #require(tab == state.lastTab) }
            if state.presentation == .hoverArmed { try #require(state.pointerInside) }
        }
        #expect(visited.count == 8, "fuzzing only reached \(visited.sorted())")
    }
}

/// Small deterministic generator, so a fuzz failure replays exactly.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
