// SPDX-License-Identifier: MIT
import AppKit
import NotchCore
import SwiftUI

/// Owns the panel and mirrors the engine's presentation onto it. Purely event-driven:
/// hover and clicks go into the engine, presentation changes come back out. No polling.
@MainActor
public final class NotchController {
    private let screen: NSScreen
    private let engine = NotchEngine()
    private var window: NotchWindow?

    public init(screen: NSScreen) { self.screen = screen }

    public func show() {
        let window = NotchWindow(contentRect: NotchGeometry.closedFrame(for: screen))
        let notchHeight = NotchGeometry.notchSize(for: screen).height
        window.contentView = NSHostingView(rootView: NotchView(engine: engine, notchHeight: notchHeight))
        self.window = window
        engine.onPresentationChange = { [weak self] old, new in self?.render(from: old, to: new) }
        Log.surface.info("Showing the notch on \(self.screen.localizedName, privacy: .public)")
        engine.send(.show)
    }

    private func render(from old: NotchPresentationState, to new: NotchPresentationState) {
        guard let window else { return }
        switch new {
        case .hidden, .suspended:
            window.orderOut(nil)
            return
        default:
            break
        }
        let open = new.openTab != nil
        let target = open ? NotchGeometry.openFrame(for: screen) : NotchGeometry.closedFrame(for: screen)
        guard window.isVisible else {
            // Reappearing after hide or suspend: snap to the right size, don't animate from a stale one.
            window.setFrame(target, display: false)
            window.orderFrontRegardless()
            return
        }
        guard open != (old.openTab != nil) else { return }

        Log.signposter.emitEvent("panel frame", "\(open ? "open" : "closed", privacy: .public)")
        // ponytail: AppKit animates the frame while SwiftUI springs the content, two animation owners.
        // Phase 2 replaces this with a fixed-size panel and one animatable notch shape.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(target, display: true)
        }
    }
}
