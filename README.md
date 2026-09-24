# OpenNotch

An **original, open-source** macOS menu-notch utility — turns the notch on Apple
Silicon MacBooks into an interactive tray for media, files, tasks, and notes.
Built native (SwiftUI + AppKit) with a **hard focus on low RAM and near-zero
idle CPU**.

> **Not affiliated with, endorsed by, or derived from any commercial notch app.**
> This is a clean-room implementation written from scratch. It contains no
> disassembled, decompiled, or copied third-party code or assets. Features are
> common-idea reimplementations; all code and art here are original or from
> permissively licensed (MIT) open-source libraries.

_Working name — pick a final name/logo before public release._

## Why

Notch utilities are genuinely useful, but the popular closed-source one is
unmaintained and drew complaints about heavy RAM/CPU use. OpenNotch is a free,
maintained, efficient alternative anyone can inspect and improve.

## Design principles (the efficiency story)

1. **No polling timers.** State changes come from events (hover, system
   notifications), never a run loop that wakes every frame. Idle app = idle CPU.
2. **Accessory app.** No Dock icon, no menu bar, never steals focus
   (`nonactivatingPanel`).
3. **Lazy feature loading.** A feature module does its work only while its tab
   is open; closed tabs cost nothing.
4. **Native, no Electron/webview.** Pure SwiftUI/AppKit.
5. **Measured, not assumed.** Each feature ships with an Instruments check;
   target: ~0% idle CPU, minimal steady-state RAM.

## Architecture

| File | Role |
|------|------|
| `main.swift` | Entry point; `.accessory` policy; `--selftest` hook |
| `AppDelegate.swift` | Picks the notched screen, starts the controller |
| `NotchGeometry.swift` | Notch rect from **public** APIs (`safeAreaInsets`, `auxiliaryTop*Area`) + self-check |
| `NotchWindow.swift` | Borderless, transparent, floating, non-activating panel |
| `NotchController.swift` | Owns the window + open/closed state; event-driven resize |
| `NotchView.swift` | SwiftUI content; tab bar (Media / Tray / Tasks / Notes) |

## Build & run

```bash
swift run OpenNotch            # run from source
swift run OpenNotch --selftest # geometry invariants self-check
./bundle.sh                    # produce OpenNotch.app (LSUIElement)
```

Requires macOS 14+ and a Swift 6 toolchain (Xcode 16+ or Swift.org toolchain).

## Roadmap

**Phase 0 — Foundation** ✅ _(done)_
- Clean-room repo, MIT license, `.gitignore`
- Notch detection via public APIs
- Expanding/collapsing notch window — event-driven, no timers
- Accessory app, four-tab shell scaffold
- Geometry self-check, compiles clean, runs

**Phase 1 — Core interactive notch (v1)**
- [ ] **Media / now-playing** + playback controls
      _(note: Apple restricted the private MediaRemote now-playing API in recent
      macOS; we evaluate the current best clean approach.)_
- [ ] **File tray** — drag-and-drop holding area + AirDrop hand-off
- [ ] **Tasks** — backed by Apple **Reminders** (EventKit); syncs to iPhone via iCloud, zero backend
- [ ] **Notes** — backed by Apple **Notes**; same free iCloud → iPhone sync

**Phase 2 — Ambient / system**
- [ ] Notification mirror (previews at the notch)
- [ ] Battery / charging HUD on plug-in
- [ ] Custom volume + brightness HUDs
- [ ] Calendar / today view

**Phase 3 — Extras & polish**
- [ ] Camera mirror (front-camera preview)
- [ ] Timer / stopwatch
- [ ] Optional original mascot (our own art — no third-party characters)
- [ ] Settings window, themes
- [ ] Signed + notarized builds, Sparkle auto-update

**Cross-cutting**
- [ ] Instruments pass per feature; document idle CPU + RAM in each PR

## Notes / Tasks sync

Tasks use Apple **Reminders**, notes use Apple **Notes**. Both already sync to
your iPhone through iCloud for free — no server to run. (Google **Keep** is
intentionally not used: it has no official API.)

## Sponsors

OpenNotch is free and open source. If it's useful to you,
[sponsor the project](https://github.com/sponsors/niyamvora) to help keep it
maintained.

<!-- ponytail: add a tiered logo table here (like chanhdai.com's README) once there are sponsors -->

## License

MIT — see [LICENSE](LICENSE).
