# Privacy

OpenNotch is local-first.

- No accounts, analytics, telemetry, or device fingerprinting.
- The network is used for two things only: the update check against GitHub
  Releases, and the AI Usage providers you turn on (below). With no provider
  on, the AI Usage tab never touches the network.
- Everything OpenNotch creates (settings, notes, shelf items) stays on your Mac.
- System permissions (Calendar, Reminders, Camera, and so on) are requested only
  when you enable the feature that needs them. Denying one disables only that
  feature.
- The Mirror tab is off until you turn it on, and uses the camera only while
  that tab is open. Nothing is recorded or saved.
- Replacing the macOS volume display is off until you turn it on. It asks for
  Accessibility access to catch the volume keys; OpenNotch takes only the three
  volume keys and passes every other event through untouched.
- To move the media waveform with the music, OpenNotch listens to your Mac's
  audio output, and macOS asks for "system audio recording" permission the first
  time. It listens only while the Media tab is open and something plays, turns
  the sound into loudness per frequency band as it plays, and never records,
  stores, or sends audio. Turn it off in Settings › Features › Media.

## AI Usage

The AI Usage tab shows how much of your AI coding plans you've used. Its
providers come from [OpenUsage](https://github.com/robinebers/openusage). Every
provider is off until you turn it on, and nothing reaches the network before
that.

To find which tools are signed in on this Mac, when you open the tab or its
settings, and to read a provider's sign-in when it refreshes, OpenNotch:

- Reads the sign-in each tool keeps on this Mac: its files (like
  `~/.codex/auth.json` or Cursor's settings database) and its keychain items,
  through `/usr/bin/security`. The sign-ins stay in memory. macOS may ask you
  to allow a keychain read.
- May run your login shell once (`$SHELL -ilc env`) to see settings and API
  keys you export there, such as `CLAUDE_CONFIG_DIR` or `OPENROUTER_API_KEY`.
  Only non-secret settings (config folders, sign-in endpoints) are remembered.
- Keeps an API key you paste in **Settings › AI Usage** (for OpenRouter or
  Z.ai) in your login keychain, as "OpenNotch AI Usage", never in a file.
  **Remove** there deletes it.

For each provider you turn on, OpenNotch:

- Sends your sign-in only to that provider's own service, to ask for your
  usage. Antigravity is asked through its language server on this Mac, found
  with `ps` and `lsof`.
- When a sign-in has expired, renews it with that provider and saves the new
  token back where its tool keeps it, the same way the tool would. For
  Antigravity, it asks you to open Antigravity instead.
- Reads the tool's local session logs (Claude Code, Codex, and others) to
  estimate what you've spent. Prices come from public price lists: LiteLLM
  (raw.githubusercontent.com), models.dev, and OpenUsage's price supplement
  (robinebers.github.io). OpenNotch downloads them about once an hour while a
  provider refreshes. These requests carry nothing about you or your usage.

Refreshes happen when you open the tab, every five minutes while it stays open,
and in the background only if you choose an interval in Settings (off by
default). Results are cached in `~/Library/Application Support/OpenNotch/` so
the tab paints at once. Turning a provider off deletes its cached results. The
Mac App Store edition doesn't include the AI Usage tab.

A change that weakens any of these points must say so in its pull request and
update this file.
