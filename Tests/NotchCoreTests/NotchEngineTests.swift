// SPDX-License-Identifier: MIT
import Testing

@testable import NotchCore

@MainActor
struct NotchEngineTests {
    @Test func presentationChangesAreReportedOnce() {
        let engine = NotchEngine()
        var changes: [NotchPresentationState] = []
        engine.onPresentationChange = { _, new in changes.append(new) }
        engine.send(.show)
        engine.send(.pointerExited)  // pointer bookkeeping only
        engine.send(.clicked)
        engine.send(.clicked)  // already open
        #expect(changes == [.compact, .expanded(tab: .media)])
    }

    @Test func timersFireThroughTheReducer() async throws {
        let engine = NotchEngine()
        engine.send(.show)
        engine.send(.pointerEntered)
        #expect(engine.pendingDeadlines == [.hoverDwell])
        try await Task.sleep(for: NotchTiming.hoverDwell * 5)
        #expect(engine.state.presentation == .expanded(tab: .media))
        #expect(engine.pendingDeadlines.isEmpty)
    }

    @Test func leavingAStateCancelsItsTimer() {
        let engine = NotchEngine()
        engine.send(.show)
        engine.send(.pointerEntered)
        engine.send(.pointerExited)
        #expect(engine.pendingDeadlines.isEmpty)
    }

    @Test func anInjectedDeadlineConsumesItsTimer() {
        let engine = NotchEngine()
        engine.send(.show)
        engine.send(.pointerEntered)
        engine.send(.deadline(.hoverDwell))
        #expect(engine.state.presentation == .expanded(tab: .media))
        #expect(engine.pendingDeadlines.isEmpty)
    }
}
