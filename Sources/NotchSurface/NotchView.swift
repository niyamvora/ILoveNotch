// SPDX-License-Identifier: MIT
import NotchCore
import SwiftUI

extension FeatureID {
    var symbol: String {
        switch self {
        case .media: "play.circle"
        case .shelf: "tray.full"
        case .tasks: "checklist"
        case .notes: "note.text"
        }
    }

    var title: String { rawValue.capitalized }
}

struct NotchView: View {
    let engine: NotchEngine
    let notchHeight: CGFloat

    var body: some View {
        let presentation = engine.state.presentation
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: presentation.openTab == nil ? 12 : 22, style: .continuous)
                .fill(Color.black)

            if let tab = presentation.openTab {
                VStack(spacing: 10) {
                    tabBar(selected: tab)
                    Divider().overlay(Color.white.opacity(0.12))
                    placeholder(for: tab)
                    Spacer(minLength: 0)
                }
                .padding(.top, notchHeight + 8)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .foregroundStyle(.white)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        // Event-driven only: hover and clicks go to the engine, which owns every timer.
        .onHover { engine.send($0 ? .pointerEntered : .pointerExited) }
        .onTapGesture { engine.send(.clicked) }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: presentation)
        .ignoresSafeArea()
    }

    private func tabBar(selected: FeatureID) -> some View {
        HStack(spacing: 6) {
            ForEach(FeatureID.allCases, id: \.self) { tab in
                Button {
                    engine.send(.selectTab(tab))
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 34, height: 28)
                        .background(
                            tab == selected ? Color.white.opacity(0.18) : .clear,
                            in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help(tab.title)
            }
        }
    }

    // Placeholder until each feature module lands (Phase 3 onward).
    private func placeholder(for tab: FeatureID) -> some View {
        VStack(spacing: 6) {
            Image(systemName: tab.symbol).font(.system(size: 26, weight: .semibold))
            Text(tab.title).font(.headline)
            Text("Coming soon").font(.caption).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
