import AppKit

// Runnable self-check (ponytail): validates notch geometry without launching the UI.
//   swift run OpenNotch --selftest
if CommandLine.arguments.contains("--selftest") {
    NotchGeometry.selfCheck()
    print("selftest OK — notch geometry invariants hold on \(NSScreen.screens.count) screen(s)")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Accessory: no Dock icon, no menu bar, never steals focus. First efficiency lever.
app.setActivationPolicy(.accessory)
app.run()
