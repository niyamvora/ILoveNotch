# Parity checklist

User-visible behaviors OpenNotch should cover, grouped by target release. This
list describes behavior only. How any other app implements these features is
out of scope and must not be copied.

## v0.1: notch shell

- [ ] Opens on hover after a short dwell, or immediately on click
- [ ] Closes shortly after the pointer leaves; brief overshoots don't close it
- [ ] Pin keeps it open; Escape and click-away close it
- [ ] Remembers the last open tab
- [ ] Hides during full-screen apps, sleep, and screen lock
- [ ] Works on notchless displays (floating pill) and across multiple displays
- [ ] Menu-bar item for Settings, permissions, reset, and Quit

## v0.2: media and shelf

- [ ] Shows now-playing title, artist, and artwork
- [ ] Play/pause, next, and previous controls
- [ ] Brief live activity when the track changes
- [ ] Drop files onto the notch to hold them on a shelf
- [ ] Drag shelf files back out, preview with Quick Look, and send with AirDrop
- [ ] Shelf survives relaunch; missing files are shown, not silently dropped

## v0.3: productivity and system

- [ ] Today's calendar events
- [ ] Reminders-backed tasks with check-off
- [ ] Quick local notes
- [ ] Shortcut launcher
- [ ] Timer and stopwatch
- [ ] Front-camera mirror
- [ ] Volume change indicator
- [ ] Charging and battery activity

## Later

- [ ] Replace the system volume HUD (v0.4)
- [ ] Brightness HUD and Bluetooth accessory battery (experimental)
- [ ] General notification mirror (deferred: no clean public API)
