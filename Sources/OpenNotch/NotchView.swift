import SwiftUI

enum NotchTab: String, CaseIterable, Identifiable {
    case media, tray, tasks, notes
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .media: return "play.circle"
        case .tray:  return "tray.full"
        case .tasks: return "checklist"
        case .notes: return "note.text"
        }
    }
    var title: String { rawValue.capitalized }
}

struct NotchView: View {
    @EnvironmentObject var controller: NotchController
    @State private var tab: NotchTab = .media

    private var notchTop: CGFloat { NotchGeometry.notchHeight(for: controller.screen) }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: controller.isOpen ? 22 : 12, style: .continuous)
                .fill(Color.black)

            if controller.isOpen {
                VStack(spacing: 10) {
                    tabBar
                    Divider().overlay(Color.white.opacity(0.12))
                    content
                    Spacer(minLength: 0)
                }
                .padding(.top, notchTop + 8)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .foregroundStyle(.white)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        // Event-driven only: no timers. Hover in = open, hover out = close.
        .onHover { hovering in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                controller.isOpen = hovering
            }
        }
        .ignoresSafeArea()
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(NotchTab.allCases) { t in
                Button {
                    tab = t
                } label: {
                    Image(systemName: t.icon)
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 34, height: 28)
                        .background(tab == t ? Color.white.opacity(0.18) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help(t.title)
            }
        }
    }

    @ViewBuilder private var content: some View {
        // v1 placeholders — each becomes a real module (see README roadmap).
        VStack(spacing: 6) {
            Image(systemName: tab.icon).font(.system(size: 26, weight: .semibold))
            Text(tab.title).font(.headline)
            Text("Coming soon").font(.caption).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
