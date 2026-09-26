# Parity checklist

User-visible behaviors ILoveNotch should cover, grouped by target release. This
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
- [x] Resize the open notch by dragging its bottom-right corner, between a smallest and a largest size
- [x] The tab row holds the tabs, the pin, and Settings; more tabs make the tabs narrower, never crowded
- [x] No scroll bars over the notch's content; long lists and pages fade at their edges instead
- [x] Tabs adapt to shorter notches: media drops its waveform, then shrinks its artwork; laps move beside the stopwatch
- [x] Pushing the pointer against the top edge over the notch opens it
- [x] Choose how the notch opens and closes (spring, jelly, pop, smooth, snappy, or instant), with a preview
- [x] Builds from a checkout update themselves from the menu bar (**Update ILoveNotch**)

## v0.2: media and shelf (Phase 3)

- [x] Shows now-playing title, artist, artwork, and progress, from any app
- [x] Play/pause, next, and previous controls; clicking the artwork opens the player
- [x] Wavy seek bar you can drag to seek
- [x] Waveform that follows the music's loudness across frequencies (with system audio permission)
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

## Tasks, Calendar, and Notes revamp

- [x] Tasks grouped by due date (Overdue, Today, Tomorrow, Next 7 Days, Later, No Date) or by list
- [x] Quick add that reads dates, times, "!"-style priorities, "#list", and repeats as you type
- [x] Hover actions on a task: due date, priority, list, rename, delete, and block time in Calendar
- [x] Alerts at the due time through Reminders, and a due task shown on the notch with Done and Snooze
- [x] Calendar lists tasks due today and adds events typed in plain words
- [x] Your own events edited in place (title and time) or deleted, from hover buttons, a double-click, or the context menu; invitations are left to Calendar
- [x] Notes with hover highlights, a sliding selection, colors, pins, search, and sort
- [x] A note's unticked checklist items ("- [ ]") sent to Tasks in one click
- [x] Notes in a folder of your choice (such as iCloud Drive) to reach them on iPhone, where files you named keep their names; share to Apple Notes
- [x] Control-Option-N opens a new note from any app

## v0.3+: camera and system (Phase 5)

- [x] Front-camera mirror, off until turned on; the camera runs only while the Mirror tab is open
- [x] Volume change indicator with a meter, following the output device
- [x] Charging and battery activity: charger in or out, 20% and 10% left, and full
- [x] Replace the macOS volume display (opt-in, needs Accessibility access)
- [x] Bluetooth accessory battery when it connects (experimental: Apple keyboards, mice, and trackpads)
- [x] Each system activity can be turned off in Settings › Features › System

## v0.5: AI usage (Phase 8)

- [x] Usage tab: session and weekly limits, credits, spend, and reset countdowns per AI coding subscription
- [x] Providers: Antigravity, Claude, Codex, Copilot, Cursor, Devin, Grok, Ollama, OpenCode, OpenRouter, Z.ai
- [x] Each provider off until turned on; no refresh while hidden unless a background interval is chosen
- [x] Pace for each limit: plenty left, cutting it close, or when it runs out
- [x] Spend for today, yesterday, and the last 30 days, and the daily usage trend
- [x] Live activity when a limit is close or resets
- [x] A card per provider that's on, and back from a provider's detail to the cards
- [x] Cards share the width: one spans it, two split it, and a last short row sits centered
- [x] Cards fit the notch at any size: the grid picks the columns, and each card shows what its size holds (the ring, then fewer limits) instead of being cut off
- [x] A tray under the cards offers every other provider; the ones signed in on this Mac are in color
- [x] API keys for OpenRouter and Z.ai, pasted in Settings › AI Usage and kept in the keychain
- [x] Provider logos from theSVG

## v1.1: the roadmap's picks

- [x] Join meeting: a Join button on events with a Zoom, Google Meet, Teams, Webex, Whereby, Jitsi, or FaceTime link in their URL, location, or notes; right-click copies the link
- [x] A countdown in the closed notch for the five minutes before a meeting with a link, opening with its name; hovering it opens the Calendar tab
- [x] A keyboard shortcut from any app (⌃⌥O, recorded in Settings › General) opens the notch on the display under the pointer; it, Escape, or a click away closes it
- [x] Keep Awake in the Timer tab: the Mac and its display stay awake for 30 minutes to 4 hours or until turned off, shown in the closed notch with the time left; it ends when the Mac sleeps anyway, on quit, or when the Timer tab is turned off
- [x] Show in Notch: a Shortcuts action and an `ilovenotch://show` link put a message and a symbol in the notch for 1 to 30 seconds, in both editions, without taking focus
- [x] Agent status: an Agents tab lists Claude Code and Codex sessions, working, waiting for approval, or finished, with a button back to each one's terminal
- [x] While an agent waits for approval the closed notch shows it until it's answered, and a session that finishes while its app is in the background is announced
- [x] Connecting a tool adds hooks to its own settings next to any others, and disconnecting removes exactly those; GitHub build only
- [x] Clipboard history, off until turned on: text, links, images, and files, newest first, searchable, with favorites that stay; click (or Return) copies one again
- [x] ⌃⌥V opens the Clipboard tab from any app with the search field ready
- [x] Skips what the copying app marks secret or temporary and copies from password managers; guides the user to "Paste from Other Apps" when macOS would ask each time
- [x] Notch on every display: a display without a notch gets one drawn inside its menu bar, as tall as the bar and as wide as the Mac's own notch (or a MacBook's); Settings › General picks Notch or Pill per display

## Later

- [ ] Brightness display (blocked: Apple silicon has no public API to read or set brightness)
- [ ] AirPods and other Bluetooth batteries (blocked: no public API)
- [ ] General notification mirror (deferred: no clean public API)
- [x] Signed, notarized DMG on GitHub Releases with in-app updates ([1.0.0](updates.md#public-releases))
- [x] Sandboxed Mac App Store edition ([1.0.0 in review](plan/implementation-plan.md#app-store-edition))
