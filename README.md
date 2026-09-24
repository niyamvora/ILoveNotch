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
2. **Accessory app.** No Dock icon (`LSUIElement`), one small menu bar item for
   Settings and Quit, and the notch never steals focus (`nonactivatingPanel`).
3. **Lazy features.** Each feature module is `stopped`, `background` (cheap
   event observers only), or `foreground` (on screen). Hidden tabs cost nothing.
4. **Native, no Electron/webview.** Pure SwiftUI/AppKit.
5. **Measured, not assumed.** Signposts on every event, performance tests in CI,
   and an Instruments pass per feature against the
   [performance budgets](docs/plan/implementation-plan.md#8-performance-gates).

## Architecture

```text
hover, clicks, drags, sleep/lock, display changes
  → NotchEvent
  → NotchState.handle(_:)   pure reducer: next state + effects
  → NotchEngine             one per display: runs deadline timers
  → FeatureHost             runs each feature at the highest phase any display asks for
  → NotchView               one animatable notch shape inside a fixed panel
```

| Module | Role |
|--------|------|
| `App/` | App target generated from `project.yml`: wires features in, menu bar item, Settings |
| `NotchCore` | State machine, `NotchEngine`, `FeatureHost` lifecycle, preferences, typed logging and signposts. No AppKit. |
| `NotchSurface` | Fixed click-through `NSPanel` per display, animatable `NotchShape`, `PanelCoordinator` (displays, sleep, lock), notch geometry from **public** APIs (`safeAreaInsets`, `auxiliaryTop*Area`) |
| `NotchFeatures` | Feature modules (Media, Shelf, Calendar, Tasks, Notes, Shortcuts, Timer), each a `NotchFeature` with its views and settings |
| `ThirdParty/` | [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3-Clause) as a git submodule |
| `Tests/` | Unit tests (reducer transitions and fuzzing, engine, feature host, preferences, geometry, features), offscreen snapshot tests, and XCTest performance tests |

The full design is in the [implementation plan](docs/plan/implementation-plan.md)
and the [architecture diagram](docs/plan/architecture.html).

## Build & run

Requires macOS 14.6+, Xcode 16+, and [Homebrew](https://brew.sh).

```bash
git clone --recurse-submodules https://github.com/niyamvora/OpenNotch.git
cd OpenNotch
make setup                        # installs XcodeGen (Brewfile) and fetches submodules
make run                          # generate the Xcode project, build, and launch OpenNotch.app
make install                      # build a Release app into /Applications and launch it
make test                         # unit, snapshot, and performance tests (plain SwiftPM)
make check                        # everything CI runs: lint, tests, build, license check
```

`make project` generates `OpenNotch.xcodeproj` (git-ignored) for working in Xcode.
Watch the state machine live with:

```bash
log stream --level debug --predicate 'subsystem == "cafe.opennotch.app"'
```

### Test it on your Mac

1. `make install` builds a Release app into `/Applications` and launches it.
   There's no Dock icon: look for the notch, and for the OpenNotch item in the
   menu bar (Settings…, Sponsor, Quit).
2. Quit other notch apps first; two apps can't share the notch.
3. Hover the notch (or click it, or pull down with two fingers), then try each
   tab. Calendar and Tasks ask for access the first time you tap **Allow Access**.
4. Local builds are ad-hoc signed, so macOS treats each rebuild as a new app and
   asks for Calendar and Reminders access again. Signed releases won't.
5. To start at login, turn on **Settings › General › Launch at login**.
6. To uninstall, choose **Quit** from the menu bar item and delete
   `/Applications/OpenNotch.app`; data lives in
   `~/Library/Application Support/OpenNotch`.

## Roadmap

Phases follow the [implementation plan](docs/plan/implementation-plan.md#7-delivery-phases);
user-visible behaviors are tracked in the [parity checklist](docs/parity-checklist.md).

- [x] **Phase 0 — Repository and governance:** MIT license, contribution, security, and privacy policies, third-party notices
- [x] **Phase 1 — Build system and core:** XcodeGen app target, SwiftPM core libraries, Swift 6 strict concurrency, presentation state machine, feature lifecycle, logging and signposts, unit and performance tests, CI
- [x] **Phase 2 — Production notch surface:** fixed panel with one animatable shape, click-away, Escape, drag, multi-display, menu-bar recovery, accessibility
- [x] **Phase 3 — Useful core (v0.2):** media now-playing and controls, file shelf with Quick Look and AirDrop
- [x] **Phase 4 — Productivity:** calendar, Reminders-backed tasks, local notes, shortcuts, timer, per-feature settings
- [ ] **Phase 5 — Camera and system:** camera mirror, volume and battery activities, optional HUD replacement
- [ ] **Phase 6 — Visual and motion polish:** motion tokens, original icon and brand, themes, localization
- [ ] **Phase 7 — Hardening and public beta:** soak tests, signed and notarized releases, Sparkle updates

## Now playing

Since macOS 15.4, only Apple's own processes may read system-wide now-playing
information. OpenNotch uses [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter),
which runs in the system `perl` (an Apple process) as a separate helper, so the
private framework never loads into OpenNotch. If a future macOS breaks it, Media
falls back to Music and Spotify's public notifications and says so.

## Tasks and notes

Tasks use Apple **Reminders** through EventKit, so they sync to your iPhone over
iCloud with no server to run. Notes are plain-text files in
`~/Library/Application Support/OpenNotch/Notes`, with optional iCloud sync
later; driving Apple Notes through Apple Events was dropped as brittle and
permission-heavy. (Google **Keep** is intentionally not used: it has no official
API.) Calendar and Reminders access is requested only when you tap **Allow
Access** in their tab.

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
