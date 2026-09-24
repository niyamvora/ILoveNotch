# App Store listing (draft)

**Status: draft for review. Nothing here has been uploaded.** Character limits are App Store
Connect's.

The App Store edition is sandboxed: it has every tab except AI Usage, which reads other apps'
sign-ins. Media shows what's playing in Music and Spotify from their public notifications; a
sandboxed test app received them with the track details (macOS 26, September 2026). The listing,
screenshots, and preview must show only what this edition does.

## Identity

| Field | Draft | Limit |
|-------|-------|-------|
| Name | ILoveNotch | 30 |
| Subtitle | Your notch, finally useful | 30 |
| Bundle ID | `cafe.opennotch.app`: the app's today, so settings and permissions carry over. A new one (say `com.niyamvora.ilovenotch`) must be decided before the record exists, as it's permanent | permanent |
| SKU | `ilovenotch-mac` | internal |
| Primary category | Productivity (matches `LSApplicationCategoryType`) | |
| Secondary category | Utilities | |
| Age rating | 4+ (no objectionable content) | |
| Price | Free | |
| Copyright | 2026 Niyam Vora | |

## Promotional text (170)

Your MacBook's notch, put to work. Hover to see what's playing, drop files on a shelf, check off
tasks, and start a timer without leaving what you're doing.

## Description (4,000)

ILoveNotch turns the notch on your MacBook into a small, fast tray for the things you reach for all
day. Hover over the notch or click it, and it opens right where you're already looking.

MEDIA
See what's playing in Music and Spotify, with a wavy progress bar and a waveform that moves with
the sound.

SHELF
Drop files on the notch to keep them close, then drag them out, preview them with Quick Look, or
send them with AirDrop.

CALENDAR AND TASKS
Today's events at a glance, and your Reminders, so tasks you check off sync to your iPhone.

NOTES, SHORTCUTS, AND TIMER
Quick notes that save as you type, your shortcuts one click away, a timer, and a stopwatch with
laps.

MIRROR
A quick look at your camera before a call, only while its tab is open.

MADE FOR MAC
Native and light: no accounts, no tracking, and nothing running when you aren't using it. Choose
how it opens and closes, drag its corner to resize it, pin it open, and use it on every display. On
Macs without a notch it sits at the top of the screen as a small pill.

Free and open source.

## Keywords (100)

notch,menu bar,now playing,shelf,drag and drop,airdrop,reminders,calendar,timer,notes,dynamic island

## URLs

| Field | Draft |
|-------|-------|
| Support URL | https://github.com/niyamvora/ILoveNotch/issues |
| Marketing URL | https://github.com/niyamvora/ILoveNotch |
| Privacy Policy URL | https://github.com/niyamvora/ILoveNotch/blob/main/PRIVACY.md |

## Screenshots

Mac screenshots are 16:10: 2880×1800, 2560×1600, 1440×900, or 1280×800, up to 10. The designed
1440×900 set works as is. For this edition use the Shelf, Timer, Tasks, Notes, Calendar, and
Shortcuts shots, in that order, and not the three AI Usage ones. In those six:

- drop "AI usage" from the chip row;
- show content you own: no album artwork from real releases, no personal data, no test text.

## App preview (optional)

A Mac app preview is 1920×1080, 15 to 30 seconds, at most 30 fps and 500 MB, H.264 with a stereo
AAC track (256 kbps, 44.1 or 48 kHz). Use music you have the rights to, or none. To cut one from a
recording, starting 3 seconds in and running 25:

```bash
ffmpeg -ss 3 -t 25 -i recording.mov -f lavfi -t 25 -i anullsrc=r=48000:cl=stereo \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30,format=yuv420p" \
  -map 0:v -map 1:a -c:v libx264 -profile:v high -level 4.0 -crf 18 -c:a aac -b:a 256k -shortest app-preview.mp4
```

That writes a silent track; to keep the recording's own sound, replace `-map 1:a` with `-map 0:a`.

## Export compliance

`App/AppStore/Info.plist` sets `ITSAppUsesNonExemptEncryption` to `NO`: this edition makes no
network requests, so App Store Connect doesn't ask on each upload.

## App Privacy (answered in App Store Connect)

Data collection: **None**. ILoveNotch doesn't collect data or track. Calendar, Reminders, camera,
and system audio stay on the Mac and are never sent anywhere.

## Review notes

ILoveNotch is a menu-bar-style utility with no Dock icon. To open it, move the pointer to the notch
(or the pill at the top of the screen on Macs without a notch) or click the ILoveNotch item in the
menu bar and choose Settings. Calendar and Reminders access is requested only when the reviewer taps
Allow Access in those tabs. The Mirror tab is off until turned on in Settings › Features and uses the
camera only while it's open. Media shows what's playing in Music or Spotify; its waveform asks for
system audio recording permission and analyzes the sound on the Mac without recording it. No account
or sign-in is needed, and the app makes no network requests.
