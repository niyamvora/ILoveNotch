# Updates

OpenNotch has two ways to stay current: builds made from a local checkout rebuild themselves
from it, and public releases will update through Sparkle.

## Builds from a checkout (today)

`make run` and `make install` record the checkout and commit a build came from in its
`Info.plist` (`OpenNotchSourceDirectory`, `OpenNotchCommit`). When that checkout is still on
the Mac, the menu bar item shows the running version and commit, for example
`OpenNotch 0.2.0 (8b4da5e)`, with a `+` when the checkout had uncommitted changes. Beside it is
**Update OpenNotch**, which is also in **Settings › About** and available as `make update`.

**Update OpenNotch** runs [`scripts/update.sh`](../scripts/update.sh), which:

1. fast-forwards `main` from GitHub when the checkout is on `main` with no local changes (any
   other branch, or uncommitted work, is built as it is and never touched);
2. builds a Release app, replaces `/Applications/OpenNotch.app`, and relaunches it.

The new build quits the running one when it takes its place. If the pull or the build fails,
the running app stays put and the menu offers **Update Failed: Show Log**. The log is at
`~/Library/Logs/OpenNotch/update.log`.

### Permissions across rebuilds

macOS ties Calendar, Reminders, and folder access to an app's code signature. An ad-hoc
signature changes with every build, so each rebuild would ask again. When the keychain has an
**Apple Development** certificate (Xcode › Settings › Accounts › Manage Certificates), `make`
signs with it instead. The app then keeps the same identity across rebuilds, and access
granted once stays granted. Pass `SIGNING_IDENTITY=` to force ad-hoc signing, as CI does by
having no certificate.

## Public releases (Phase 7)

People who download OpenNotch have no checkout, so their builds link to the Releases page
(**Check for Updates…**) until in-app updates land. The plan:

| Piece | Choice |
|-------|--------|
| In-app updates | [Sparkle 2](https://sparkle-project.org) (MIT) through `SPUStandardUpdaterController`, behind **Check for Updates…** |
| Feed | An appcast published with each release, every update signed with an EdDSA (ed25519) key |
| Distribution | Signed, notarized DMG on GitHub Releases; a Homebrew cask can follow |
| Automatic checks | Off until the user agrees: Sparkle asks on the second launch, and Settings has the toggle |

A tagged release (`v*`) runs a GitHub Actions workflow that:

1. builds a universal (Apple silicon and Intel) Release app;
2. signs it with a **Developer ID Application** certificate and the hardened runtime;
3. notarizes it with `notarytool`, then staples the ticket;
4. packages and signs the DMG;
5. signs the update and regenerates the appcast with Sparkle's `generate_appcast`;
6. publishes the DMG and appcast to the GitHub release.

It needs these repository secrets: the Developer ID certificate (`.p12` and its password), an
App Store Connect API key for notarization, and the Sparkle EdDSA private key. The matching
public key ships in the app's `Info.plist` as `SUPublicEDKey`. Developer ID signing and
notarization require a paid Apple Developer Program membership.

A build offers **Update OpenNotch** only when the checkout it records exists on the Mac with
`scripts/update.sh` in it. A release built by CI records the runner's path, which doesn't exist
on anyone's Mac, so it uses Sparkle.
