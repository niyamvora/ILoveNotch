# Privacy

OpenNotch is local-first.

- No accounts, analytics, telemetry, or device fingerprinting.
- No network requests while idle. The only planned network use is an optional,
  user-controlled update check against GitHub Releases.
- Everything OpenNotch creates (settings, notes, shelf items) stays on your Mac.
- System permissions (Calendar, Reminders, Camera, and so on) are requested only
  when you enable the feature that needs them. Denying one disables only that
  feature.
- To move the media waveform with the music, OpenNotch listens to your Mac's
  audio output, and macOS asks for "system audio recording" permission the first
  time. It listens only while the Media tab is open and something plays, turns
  the sound into loudness per frequency band as it plays, and never records,
  stores, or sends audio. Turn it off in Settings › Features › Media.

A change that weakens any of these points must say so in its pull request and
update this file.
