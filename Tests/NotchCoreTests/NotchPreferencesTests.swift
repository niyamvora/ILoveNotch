// SPDX-License-Identifier: MIT
import Foundation
import Testing

@testable import NotchCore

@MainActor
struct NotchPreferencesTests {
    /// A throwaway defaults domain per test.
    private let defaults = UserDefaults(suiteName: "NotchPreferencesTests.\(UUID().uuidString)")!

    @Test func everythingIsEnabledOnOneDisplayByDefault() {
        let preferences = NotchPreferences(defaults: defaults)
        #expect(preferences.tabs == FeatureID.allCases)
        #expect(!preferences.showOnAllDisplays)
    }

    @Test func choicesPersistAcrossLaunches() {
        let first = NotchPreferences(defaults: defaults)
        first.setEnabled(.media, false)
        first.showOnAllDisplays = true

        let second = NotchPreferences(defaults: defaults)
        #expect(!second.isEnabled(.media))
        #expect(second.tabs == FeatureID.allCases.filter { $0 != .media })
        #expect(second.showOnAllDisplays)
    }

    @Test func unknownStoredFeaturesAreIgnored() {
        defaults.set(["notes", "a-feature-from-the-future"], forKey: "disabledFeatures")
        #expect(NotchPreferences(defaults: defaults).disabledFeatures == [.notes])
    }

    @Test func resetRestoresTheDefaults() {
        let preferences = NotchPreferences(defaults: defaults)
        preferences.setEnabled(.shelf, false)
        preferences.showOnAllDisplays = true
        preferences.reset()
        #expect(preferences.tabs == FeatureID.allCases)
        #expect(!NotchPreferences(defaults: defaults).showOnAllDisplays)
    }

    @Test func observersRerunAfterEveryChange() async throws {
        let preferences = NotchPreferences(defaults: defaults)
        var seen: [[FeatureID]] = []
        observeContinuously { seen.append(preferences.tabs) }
        preferences.setEnabled(.tasks, false)
        try await Task.sleep(for: .milliseconds(50))
        preferences.setEnabled(.tasks, true)
        try await Task.sleep(for: .milliseconds(50))
        #expect(seen.count == 3)
        #expect(seen.last == FeatureID.allCases)
    }
}
