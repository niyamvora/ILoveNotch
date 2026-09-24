// SPDX-License-Identifier: MIT
import Testing

@testable import NotchCore

/// Records every phase the engine moves it through.
@MainActor
private final class RecordingFeature: NotchFeature {
    let id: FeatureID
    private(set) var history: [FeaturePhase] = []
    var phase: FeaturePhase = .stopped { didSet { history.append(phase) } }

    init(_ id: FeatureID) { self.id = id }
}

@MainActor
struct NotchEngineTests {
    @Test func featuresFollowTheActivationPolicy() {
        let media = RecordingFeature(.media)
        let notes = RecordingFeature(.notes)
        let engine = NotchEngine(features: [media, notes])

        engine.send(.show)
        #expect(media.phase == .background && notes.phase == .background)
        engine.send(.clicked)
        #expect(media.phase == .foreground && notes.phase == .background)
        engine.send(.selectTab(.notes))
        #expect(media.phase == .background && notes.phase == .foreground)
        engine.send(.suspend)
        #expect(media.phase == .stopped && notes.phase == .stopped)
        #expect(media.history == [.background, .foreground, .background, .stopped])
    }

    @Test func aLiveActivityBringsItsFeatureForward() {
        let shelf = RecordingFeature(.shelf)
        let engine = NotchEngine(features: [shelf])
        engine.send(.show)
        engine.send(.activity(Activity(feature: .shelf, duration: .seconds(60))))
        #expect(shelf.phase == .foreground)
        engine.send(.dismiss)
        #expect(shelf.phase == .background)
    }

    @Test func phasesOnlyChangeWhenThePolicyDoes() {
        let media = RecordingFeature(.media)
        let engine = NotchEngine(features: [media])
        engine.send(.show)
        engine.send(.clicked)
        engine.send(.pointerEntered)  // moving inside the open notch changes no presentation
        engine.send(.togglePin)  // pinned still shows media
        #expect(media.history == [.background, .foreground])
    }

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
