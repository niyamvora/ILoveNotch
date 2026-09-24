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
- [x] Closed, the notch hides behind the camera housing; hovering grows it slightly
- [x] Switching tabs slides the content across, and the selection moves with a jelly stretch
- [x] Resize the open notch in proportion with − and + beside the pin, down to a shorter smallest size
- [x] Tabs adapt to shorter notches: media drops its waveform, then shrinks its artwork; laps move beside the stopwatch
- [x] Pushing the pointer against the top edge over the notch opens it
- [x] Choose how the notch opens and closes (spring, jelly, pop, smooth, snappy, or instant), with a preview
- [x] Builds from a checkout update themselves from the menu bar (**Update OpenNotch**)

## v0.2: media and shelf (Phase 3)

- [x] Shows now-playing title, artist, artwork, and progress, from any app
- [x] Play/pause, next, and previous controls; clicking the artwork opens the player
- [x] Wavy seek bar you can drag to seek, and a waveform that moves while music plays
- [x] Brief live activity when the track changes
- [x] Drop files onto the notch to hold them on a shelf
- [x] Drag shelf files back out, preview with Quick Look, and send with AirDrop
- [x] Shelf survives relaunch and follows renamed files; missing files are shown, not silently dropped
- [x] Clear message when a feature is unavailable (for example, Media's fallback) or has nothing to show

## v0.3: productivity (Phase 4)

- [x] Today's calendar events, with a clear path when calendar access is off
- [x] Reminders-backed tasks: check off, add, pick a list; they sync to iPhone through iCloud
- [x] Recently completed tasks in a collapsible section; tap one to reopen it
- [x] Quick local notes that save as you type
- [x] Shortcut launcher that runs shortcuts in the background
- [x] Timer and stopwatch with rolling-digit animation and a "Timer done" live activity
- [x] Every stopwatch lap, newest first, in a scrolling list
- [x] Per-feature settings, including access status for Calendar and Reminders

## v0.3+: camera and system (Phase 5)

- [ ] Front-camera mirror
- [ ] Volume change indicator
- [ ] Charging and battery activity

## Later

- [ ] Replace the system volume HUD (v0.4)
- [ ] Brightness HUD and Bluetooth accessory battery (experimental)
- [ ] General notification mirror (deferred: no clean public API)
- [ ] Signed, notarized DMG on GitHub Releases with in-app updates ([Phase 7](updates.md#public-releases-phase-7))
