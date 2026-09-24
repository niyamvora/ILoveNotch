// SPDX-License-Identifier: MIT
import CoreGraphics
import Foundation
import Testing

@testable import NotchCore

@MainActor
struct NotchPreferencesTests {
    /// A throwaway defaults domain per test.
    private let defaults = UserDefaults(suiteName: "NotchPreferencesTests.\(UUID().uuidString)")!
    /// Every tab except those that start off, like the camera mirror.
    private let defaultTabs = FeatureID.allCases.filter { !NotchPreferences.offByDefault.contains($0) }

    @Test func everythingButTheMirrorIsEnabledOnOneDisplayByDefault() {
        let preferences = NotchPreferences(defaults: defaults)
        #expect(preferences.tabs == defaultTabs)
        #expect(!preferences.isEnabled(.mirror))
        #expect(!preferences.showOnAllDisplays)
        #expect(preferences.showsVolume && preferences.showsBattery)
        #expect(!preferences.replacesVolumeDisplay && !preferences.showsAccessoryBattery)
    }

    @Test func choicesPersistAcrossLaunches() {
        let first = NotchPreferences(defaults: defaults)
        first.setEnabled(.media, false)
        first.showOnAllDisplays = true
        first.showsBattery = false

        let second = NotchPreferences(defaults: defaults)
        #expect(!second.isEnabled(.media))
        #expect(second.tabs == defaultTabs.filter { $0 != .media })
        #expect(second.showOnAllDisplays)
        #expect(!second.showsBattery)
    }

    @Test func aFeatureThatStartsOffDoesSoOnceThenFollowsTheUser() {
        // An update from before the mirror existed: some choices stored, the mirror never seen.
        defaults.set(["notes"], forKey: "disabledFeatures")
        let updated = NotchPreferences(defaults: defaults)
        #expect(!updated.isEnabled(.mirror) && !updated.isEnabled(.notes))

        updated.setEnabled(.mirror, true)
        #expect(NotchPreferences(defaults: defaults).isEnabled(.mirror), "turned on, it stays on")
    }

    @Test func unknownStoredFeaturesAreIgnored() {
        defaults.set(["notes", "a-feature-from-the-future"], forKey: "disabledFeatures")
        let disabled = NotchPreferences(defaults: defaults).disabledFeatures
        #expect(disabled == [.notes, .mirror], "and the mirror starts off")
    }

    @Test func resetRestoresTheDefaults() {
        let preferences = NotchPreferences(defaults: defaults)
        preferences.setEnabled(.shelf, false)
        preferences.showOnAllDisplays = true
        preferences.resizeExpanded(to: CGSize(width: 600, height: 400))
        preferences.setEnabled(.mirror, true)
        preferences.replacesVolumeDisplay = true
        preferences.reset()
        #expect(preferences.tabs == defaultTabs)
        #expect(preferences.expandedSize == NotchPreferences.defaultExpandedSize)
        #expect(!preferences.replacesVolumeDisplay)
        #expect(!NotchPreferences(defaults: defaults).showOnAllDisplays)
    }

    @Test func theNotchSizePersistsWithinItsLimits() {
        let preferences = NotchPreferences(defaults: defaults)
        preferences.resizeExpanded(to: CGSize(width: 600, height: 380))
        #expect(NotchPreferences(defaults: defaults).expandedSize == CGSize(width: 600, height: 380))
        preferences.resizeExpanded(to: CGSize(width: 5000, height: 10))
        #expect(preferences.expandedSize == CGSize(width: 720, height: 230))
        defaults.set([10.0, 9999.0], forKey: "expandedSize")  // a hand-edited value is clamped too
        #expect(NotchPreferences(defaults: defaults).expandedSize == CGSize(width: 414, height: 480))
    }

    @Test func theAnimationStylePersistsAndFallsBackToSpring() {
        #expect(NotchPreferences(defaults: defaults).animationStyle == .spring)
        NotchPreferences(defaults: defaults).animationStyle = .jelly
        #expect(NotchPreferences(defaults: defaults).animationStyle == .jelly)
        defaults.set("wobbly-from-the-future", forKey: "animationStyle")
        #expect(NotchPreferences(defaults: defaults).animationStyle == .spring)
    }

    @Test func plusAndMinusResizeInProportion() {
        let preferences = NotchPreferences(defaults: defaults)
        var larger: [CGSize] = []
        while let next = preferences.expandedSizeStep(larger: true) {
            preferences.resizeExpanded(to: next)
            larger.append(preferences.expandedSize)
        }
        #expect(larger.map(\.width) == [515, 575, 644, 718], "+ stops at the largest size")
        var smaller: [CGSize] = []
        while let next = preferences.expandedSizeStep(larger: false) {
            preferences.resizeExpanded(to: next)
            smaller.append(preferences.expandedSize)
        }
        #expect(smaller.map(\.width) == [644, 575, 515, 460, 414, 414], "− steps back down")
        #expect(smaller.suffix(2).map(\.height) == [261, 230], "and ends on a shorter size at the same width")

        let steps = NotchPreferences.expandedSizeSteps
        let aspect = NotchPreferences.defaultExpandedSize.width / NotchPreferences.defaultExpandedSize.height
        for step in steps.dropFirst() {
            #expect(abs(step.width / step.height - aspect) < 0.01, "the height follows the width")
        }
        #expect(steps.allSatisfy { NotchPreferences.clamped($0) == $0 }, "every step is within the limits")
    }

    @Test func observersRerunAfterEveryChange() async throws {
        let preferences = NotchPreferences(defaults: defaults)
        var seen: [[FeatureID]] = []
        observeContinuously { seen.append(preferences.tabs) }
        preferences.setEnabled(.tasks, false)
        #expect(await eventually { seen.count == 2 })
        preferences.setEnabled(.tasks, true)
        #expect(await eventually { seen.count == 3 })
        #expect(seen.last == defaultTabs)
    }
}
