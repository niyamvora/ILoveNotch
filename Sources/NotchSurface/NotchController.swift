// SPDX-License-Identifier: MIT
import AppKit
import Combine
import SwiftUI

/// Owns the window and the open/closed state. Purely event-driven:
/// there is NO polling timer anywhere. Hover events flip `isOpen`,
/// which resizes the window. That is the whole engine.
@MainActor
public final class NotchController: ObservableObject {
    @Published var isOpen = false

    let screen: NSScreen
    private var window: NotchWindow?
    private var cancellable: AnyCancellable?

    public init(screen: NSScreen) { self.screen = screen }

    public func show() {
        let root = NotchView().environmentObject(self)
        let window = NotchWindow(contentRect: NotchGeometry.closedFrame(for: screen))
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
        let target = open ? NotchGeometry.openFrame(for: screen) : NotchGeometry.closedFrame(for: screen)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(target, display: true)
        }
    }
}
