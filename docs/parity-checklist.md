# Parity checklist

User-visible behaviors OpenNotch should cover, grouped by target release. This
list describes behavior only. How any other app implements these features is
out of scope and must not be copied.

A box is checked once the behavior ships in a build you can run from `main`.
Each group names the [implementation plan](plan/implementation-plan.md) phase
that delivers it.

## v0.1: notch shell (Phases 1–2)

- [x] Opens on hover after a short dwell, or immediately on click or a two-finger pull down
- [x] Closes shortly after the pointer leaves; brief overshoots don't close it
- [x] Pin keeps it open; click-away closes it, and so does Escape while typing
- [x] Remembers the last open tab
- [x] Clicks beside the notch still reach the menu bar and the apps underneath
- [x] Stays out of full-screen apps and stops during sleep, display sleep, and screen lock
- [x] Works on notchless displays (floating pill) and, optionally, on every display
- [x] Menu-bar item for Settings, Sponsor, and Quit, reachable even if the notch misbehaves
- [x] Settings: launch at login, displays, turn features on or off, and reset
- [x] Respects Reduce Motion and Increase Contrast; VoiceOver labels and Open/Close actions
- [x] Dragging files over the notch opens it to the shelf

## v0.2: media and shelf (Phase 3)

- [ ] Shows now-playing title, artist, and artwork
- [ ] Play/pause, next, and previous controls
- [ ] Brief live activity when the track changes
- [ ] Drop files onto the notch to hold them on a shelf
- [ ] Drag shelf files back out, preview with Quick Look, and send with AirDrop
- [ ] Shelf survives relaunch; missing files are shown, not silently dropped
- [ ] Clear message when a feature is unavailable or a permission is denied

## v0.3: productivity (Phase 4)

- [ ] Today's calendar events
- [ ] Reminders-backed tasks with check-off
- [ ] Quick local notes
- [ ] Shortcut launcher
- [ ] Timer and stopwatch
- [ ] Per-feature settings

## v0.3+: camera and system (Phase 5)

- [ ] Front-camera mirror
- [ ] Volume change indicator
- [ ] Charging and battery activity

## Later

- [ ] Replace the system volume HUD (v0.4)
- [ ] Brightness HUD and Bluetooth accessory battery (experimental)
- [ ] General notification mirror (deferred: no clean public API)
- [ ] Signed, notarized DMG on GitHub Releases with in-app updates (Phase 7)
