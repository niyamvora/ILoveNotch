// SPDX-License-Identifier: MIT
import Foundation
import SwiftUI

/// Where OpenNotch keeps its local data: ~/Library/Application Support/OpenNotch.
public enum AppSupport {
    public static func file(_ name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appending(path: "OpenNotch", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: name)
    }
}

/// Shown instead of a feature when it can't work: unavailable on this Mac, or a permission denied.
/// Always says why and, when there is one, offers the fix.
public struct FeatureUnavailableView: View {
    let symbol: String
    let title: String
    let message: String
    let action: (label: String, perform: () -> Void)?

    public init(symbol: String, title: String, message: String, action: (label: String, perform: () -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 22, weight: .semibold)).opacity(0.8)
            Text(title).font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            if let action {
                Button(action.label, action: action.perform)
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

extension URL {
    /// Opens a System Settings privacy pane, e.g. "Privacy_Calendars".
    public static func privacySettings(_ pane: String) -> URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
    }
}
