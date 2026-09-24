# OpenNotch

[![CI](https://github.com/niyamvora/OpenNotch/actions/workflows/ci.yml/badge.svg)](https://github.com/niyamvora/OpenNotch/actions/workflows/ci.yml)

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

1. **No polling timers.** State changes come from events (hover, clicks, system
   notifications). The only timers are one-shot deadlines, like the hover dwell,
   cancelled the moment they stop mattering. Idle app = idle CPU.
2. **Accessory app.** No Dock icon, no menu bar (`LSUIElement`), never steals
   focus (`nonactivatingPanel`).
3. **Lazy features.** Each feature module is `stopped`, `background` (cheap
   event observers only), or `foreground` (on screen). Hidden tabs cost nothing.
4. **Native, no Electron/webview.** Pure SwiftUI/AppKit.
5. **Measured, not assumed.** Signposts on every event, performance tests in CI,
   and an Instruments pass per feature against the
   [performance budgets](docs/plan/implementation-plan.md#8-performance-gates).

## Architecture

```text
hover, clicks, system callbacks
  → NotchEvent
  → NotchState.handle(_:)   pure reducer: next state + effects
  → NotchEngine             runs deadline timers, drives the feature lifecycle
  → NotchController         mirrors the presentation onto the panel
```

| Module | Role |
|--------|------|
| `App/` | App target generated from `project.yml`: entry point, picks the notched screen |
| `NotchCore` | State machine, feature lifecycle, `NotchEngine`, typed logging and signposts. No AppKit. |
| `NotchSurface` | Non-activating `NSPanel`, SwiftUI notch view, notch geometry from **public** APIs (`safeAreaInsets`, `auxiliaryTop*Area`) |
| `Tests/` | Unit tests (reducer transitions and fuzzing, engine, geometry) and XCTest performance tests |

The full design is in the [implementation plan](docs/plan/implementation-plan.md)
and the [architecture diagram](docs/plan/architecture.html).

## Build & run

Requires macOS 14.6+, Xcode 16+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```bash
make run                          # generate the Xcode project, build, and launch OpenNotch.app
make test                         # unit + performance tests (plain SwiftPM)
make check                        # everything CI runs: lint, tests, build, license check
make build CONFIGURATION=Release
```

`make project` generates `OpenNotch.xcodeproj` (git-ignored) for working in Xcode.
Watch the state machine live with:

```bash
log stream --level debug --predicate 'subsystem == "cafe.opennotch.app"'
```

## Roadmap

Phases follow the [implementation plan](docs/plan/implementation-plan.md#7-delivery-phases);
user-visible behaviors are tracked in the [parity checklist](docs/parity-checklist.md).

- [x] **Phase 0 — Repository and governance:** MIT license, contribution, security, and privacy policies, third-party notices
- [x] **Phase 1 — Build system and core:** XcodeGen app target, SwiftPM core libraries, Swift 6 strict concurrency, presentation state machine, feature lifecycle, logging and signposts, unit and performance tests, CI
- [ ] **Phase 2 — Production notch surface:** fixed panel with one animatable shape, click-away, Escape, drag, multi-display, menu-bar recovery, accessibility
- [ ] **Phase 3 — Useful core (v0.2):** media now-playing and controls, file shelf with Quick Look and AirDrop
- [ ] **Phase 4 — Productivity:** calendar, Reminders-backed tasks, local notes, shortcuts, timer
- [ ] **Phase 5 — Camera and system:** camera mirror, volume and battery activities, optional HUD replacement
- [ ] **Phase 6 — Visual and motion polish:** motion tokens, original icon and brand, themes, localization
- [ ] **Phase 7 — Hardening and public beta:** soak tests, signed and notarized releases, Sparkle updates

## Tasks and notes

Tasks will use Apple **Reminders** through EventKit, so they sync to your iPhone
over iCloud with no server to run. Notes are stored locally, with optional
iCloud sync later; driving Apple Notes through Apple Events was dropped as
brittle and permission-heavy. (Google **Keep** is intentionally not used: it has
no official API.)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Report vulnerabilities privately as
described in [SECURITY.md](SECURITY.md); privacy commitments are in
[PRIVACY.md](PRIVACY.md).

## Sponsors

OpenNotch is free and open source. If it's useful to you,
[sponsor the project](https://github.com/sponsors/niyamvora) to help keep it
maintained.

<!-- ponytail: add a tiered logo table here (like chanhdai.com's README) once there are sponsors -->

## License

MIT — see [LICENSE](LICENSE).
