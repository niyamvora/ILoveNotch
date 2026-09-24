# Releasing

How a signed, notarized OpenNotch reaches GitHub Releases and installed copies. The scripted part
is `make release VERSION=…` ([`scripts/release.sh`](../scripts/release.sh)); publishing is a
deliberate, manual step.

## One-time setup

1. **A Developer ID Application identity.** Only the Account Holder of the Apple Developer team
   can create one. Either:
   - sign in to Xcode with the Account Holder's Apple ID (Xcode › Settings › Accounts), and the
     export uses a cloud-managed Developer ID certificate; or
   - create a Developer ID Application certificate (Xcode › Settings › Accounts › Manage
     Certificates, or developer.apple.com › Certificates) so it's in the login keychain. With a
     local identity the DMG is signed and notarized too, not just the app.
2. **`release.env`.** Copy `release.env.example` and fill in the App Store Connect team API key
   (key path, key ID, issuer ID) and the team ID. It's git-ignored; never commit it or the key.
   The key notarizes; an Admin or Developer role is enough.
3. **Sparkle's signing key.** `.build/sparkle/bin/generate_keys` created an EdDSA key pair in the
   login keychain; its public half is `SUPublicEDKey` in `App/Info.plist`. Back up the private
   half somewhere safe (`generate_keys -x private-key-file` exports it, `-f` imports it on
   another Mac): without it, installed copies can't verify future updates.
4. **`gh`**, signed in with write access to the repository.

## Cutting a release

From a clean, up-to-date `main`:

```bash
make release VERSION=0.3.0          # or 0.3.0-beta.1 for a beta
```

It runs lint and tests, archives a Release build (universal, with no source checkout recorded, so
it updates through Sparkle), exports it signed with Developer ID and the hardened runtime,
notarizes and staples it, packages the DMG, adds the release to `appcast.xml` with its EdDSA
signature, and drafts a GitHub release with the DMG and `SHA256SUMS`. A version with a suffix
(`-beta.1`) becomes a pre-release.

Then:

1. Open the draft on GitHub, check the notes, and publish it.
2. Commit the updated `appcast.xml` through a pull request. Installed copies read it from `main`,
   so an update is offered only once both the release and the appcast are public.

## The App Store edition

The `OpenNotch App Store` scheme builds the sandboxed edition (see the
[plan](plan/implementation-plan.md#app-store-edition) for what it leaves out). Once:

1. Decide the bundle ID; it can't change after the first upload. Both editions use
   `cafe.opennotch.app` today.
2. Create the app record in App Store Connect (My Apps › + › New App, macOS, that bundle ID). The
   API can't create app records.
3. Add the app icon (see [brand assets](brand-assets.md)): builds without one fail validation.

Then, from a clean `main`:

```bash
make app-store VERSION=0.3.0
```

It archives the edition, signs it for the App Store with cloud-managed certificates through the
team API key in `release.env` (registering the bundle ID and profile the first time), and uploads
it. The build appears in App Store Connect › TestFlight once processed; submitting it for review
also needs the screenshots, the listing in [docs/app-store](app-store/metadata.md), and the App
Privacy answers ("Data Not Collected").

## Checks before publishing

- `spctl --assess --type execute --verbose` on the exported app says "Notarized Developer ID"
  (the script runs it).
- Install from the DMG on a Mac or user account that has never run OpenNotch: it opens without a
  Gatekeeper warning.
- Update an installed earlier release through **Check for Updates…**.
- Keep the previous DMG: rolling back is installing it over the new one.
