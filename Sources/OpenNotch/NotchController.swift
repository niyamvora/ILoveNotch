import AppKit
import SwiftUI
import Combine

/// Owns the window and the open/closed state. Purely event-driven —
/// there is NO polling timer anywhere. Hover events flip `isOpen`,
/// which resizes the window. That is the whole engine.
@MainActor
final class NotchController: ObservableObject {
    @Published var isOpen = false

    let screen: NSScreen
    private var window: NotchWindow?
    private var cancellable: AnyCancellable?

    init(screen: NSScreen) { self.screen = screen }

    func show() {
        let root = NotchView().environmentObject(self)
        let window = NotchWindow(contentRect: NotchGeometry.closedWindowFrame(for: screen))
        window.contentView = NSHostingView(rootView: root)
        window.orderFrontRegardless()
        self.window = window

        // Resize the window whenever open/closed flips.
        cancellable = $isOpen
            .removeDuplicates()
            .sink { [weak self] open in self?.applyFrame(open: open) }
    }

    private func applyFrame(open: Bool) {
        guard let window else { return }
        let target = open ? NotchGeometry.openWindowFrame(for: screen)
                          : NotchGeometry.closedWindowFrame(for: screen)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(target, display: true)
        }
    }
}
