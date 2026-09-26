// SPDX-License-Identifier: MIT
import Carbon

/// The system-wide Control-Option-N shortcut that starts a new note. A Carbon hot key needs no
/// Accessibility or Input Monitoring access, works in the App Sandbox, and costs nothing until the
/// keys are pressed.
@MainActor
final class QuickNoteHotKey {
    var onPress: (() -> Void)?

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    /// The registered instance, for the C callback, which can't capture context.
    fileprivate static weak var active: QuickNoteHotKey?

    func start() {
        guard hotKey == nil else { return }
        Self.active = self
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), hotKeyPressed, 1, &pressed, nil, &handler)
        guard installed == noErr else { return }
        let id = EventHotKeyID(signature: OSType(0x4E4F_5445), id: 1)  // "NOTE"
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_N), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { stop() }  // another app already owns the shortcut
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
        if Self.active === self { Self.active = nil }
    }
}

/// Carbon's callback for the hot key. Carbon delivers hot keys on the main thread.
private func hotKeyPressed(_ call: EventHandlerCallRef?, _ event: EventRef?, _ context: UnsafeMutableRawPointer?)
    -> OSStatus
{
    MainActor.assumeIsolated { QuickNoteHotKey.active?.onPress?() }
    return noErr
}
