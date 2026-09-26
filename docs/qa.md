# QA

The [QA matrix](plan/implementation-plan.md#9-qa-matrix) as a checklist for each release. Checked
items are covered by automated tests or were verified on hardware for the current release
candidate; the rest are manual passes still to run before a public release.

## Automated (every pull request)

- [x] Reducer: every transition, suspension from sleep, display sleep, and lock, and 50,000
  random events against its invariants (`NotchReducerTests`)
- [x] Engine: timers, pointer reality checks, and 1,000 hover cycles without growth
  (`NotchEngineTests`, `NotchEnginePerformanceTests`)
- [x] Geometry: every state fits the panel on notched and notchless displays; the closed notch
  hides inside the camera housing; a pointer at the top edge counts (`NotchMetricsTests`)
- [x] Feature lifecycle: every feature starts, suspends, resumes, and releases everything,
  including the media helper, the audio tap, and the camera (`FeatureLifecycleTests`)
- [x] Media parsing, the fallback without the helper, the spectrum analyzer, system activities,
  shelf persistence, EventKit mapping, notes, shortcuts, and timers
- [x] Snapshots of every state and tab render

## Performance

Run `scripts/soak.sh` (default 10 minutes; `scripts/soak.sh 480` for the 8-hour soak) against
the installed app. Gates are in the [plan](plan/implementation-plan.md#8-performance-gates).

| Run | CPU median / p95 | Memory (footprint) | Drift |
|-----|------------------|--------------------|-------|
| 2026-09-24, idle, 1 min, 14" MacBook Pro (Mac17,9), macOS 26 | 0.0% / 0.0% | 42 MB | 0 MB |
| 2026-09-24, 30 min, same Mac, mostly idle | 0.0% / 0.2% | 41–51 MB at rest; 130 MB peak for about a minute while the notch was in use | +3 MB |
| 8-hour idle | to run | | |
| 8-hour active | to run | | |

The media helper, a separate process, used about 7 MB. In the 30-minute run the notch was used
once (60% CPU in that sample): memory rose to 130 MB and was back to 41 MB within a minute, so
it's released, not leaked. The 120 MB gate is for the resting notch; a gate for the open notch is
still to be set.

## Hardware checks

- [x] Notch geometry and top-edge hover on a 14" MacBook Pro
- [x] Clicks beside the notch reach the menu bar and apps underneath
- [x] Volume activity from a real volume change, with the meter
- [ ] Sleep and wake, display sleep, and screen lock: the notch hides and comes back
- [ ] Plugging in and removing an external display; changing resolution and scaling
- [ ] Clamshell mode with an external display
- [ ] Full-screen apps: no notch over them
- [ ] Notchless external display: the floating pill
- [ ] Charger in and out: the battery activity
- [ ] Camera mirror: allow, deny, and revoke while running; the camera light turns off when the tab closes
- [ ] Waveform: allow and deny system audio capture; switching output devices while playing
- [ ] Replace the volume display: grant and revoke Accessibility while running
- [ ] Media: Apple Music, Spotify, a browser, and QuickTime; kill the helper (`pkill -f mediaremote-adapter`) and check Media falls back
- [ ] Shelf: deleted, moved, and corrupt files
- [ ] Permissions granted, denied, and revoked while running (Calendar, Reminders)
- [ ] Tasks: quick add in plain words, a timed task's alert on the notch and on iPhone, Snooze, and Block Time
- [ ] Notes in an iCloud Drive folder: edits reach the iPhone's Files app, and a file named there keeps its name
- [ ] Control-Option-N starts a note from another app and hands the keyboard back when the notch closes
- [ ] Light and dark mode, Increase Contrast, Reduce Motion, Reduce Transparency, VoiceOver, keyboard-only use

## Operating systems

- [ ] macOS 14.6
- [ ] macOS 15.6
- [x] macOS 26 (development)
- [ ] macOS 27
