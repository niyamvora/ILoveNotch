# Contributing to ILoveNotch

Thanks for helping. ILoveNotch is a clean-room, MIT-licensed project, so a few
rules matter more than usual.

## Where to start

- **Question or idea?** Open a [Discussion](https://github.com/niyamvora/ILoveNotch/discussions).
- **Bug or feature request?** Open an [issue](https://github.com/niyamvora/ILoveNotch/issues/new/choose)
  with its template. For anything bigger than a small fix, agree on the approach in the
  issue before writing the PR.
- **Looking for something to do?** Try [good first issues](https://github.com/niyamvora/ILoveNotch/labels/good%20first%20issue).

## Clean-room rules

- Write original code. Never copy code, assets, icons, or strings from
  closed-source apps, and never paste code from GPL-licensed projects.
- Never commit third-party app bundles, extracted binaries, or disassembly.
  `.gitignore` blocks the common cases; don't work around it.
- Dependencies must be permissively licensed (MIT, BSD, Apache-2.0, ISC, zlib)
  and listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Describe features by behavior (see [docs/parity-checklist.md](docs/parity-checklist.md)),
  never by how another app implements them.

## Development

Build and test commands live in the [README](README.md#build--run). Run
`make check` before pushing; CI runs the same targets.

## Branches

`main` is what ships. `dev` is where work lands first, and it reaches `main`
by fast-forward, so both keep the same commits:

```text
feat/xyz ──merge──▶ dev ──pull request, CI──▶ main
```

1. **Branch off `dev`** for each change. Parallel work, such as another Claude
   session, gets its own branch:
   `git switch dev && git pull && git switch -c feat/xyz`
2. **Build and test it** on your Mac: `make install`.
3. **Merge it into `dev`** without a pull request: CI doesn't run on `dev`, so
   one would add a step and check nothing. Rebase first if `dev` moved:
   `git rebase dev feat/xyz && git switch dev && git merge --ff-only feat/xyz && git push`,
   then delete the branch.
4. **Open one pull request from `dev` into `main`** when `dev` is ready to ship.
   CI runs there, in about three and a half minutes. A draft waits until it's
   marked ready for review, and a change to docs alone passes without building.
   To run CI without a pull request, use the Actions tab.
5. **Once it's green, `make ship`.** It fast-forwards `main` to `dev`, only if
   `dev` is what the pull request tested and every required check passed, and
   GitHub marks the pull request merged. The commits keep their hashes, so
   `dev`, `main`, and every open branch stay in step.

Don't merge that pull request with its **Rebase and merge** button: the button
copies the commits onto `main` with new hashes. The Sync dev workflow then puts
`dev` back on `main`, but a branch still open off the old `dev` carries stale
copies and needs `git rebase --onto origin/dev <old dev> <branch>`, and a local
`dev` needs `git fetch && git reset --hard origin/dev`.

A pull request from outside goes straight into `main` and is merged with that
button; then bring `dev` up with
`git switch dev && git rebase origin/main && git push --force-with-lease`.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/):

```text
type(scope): imperative summary under 72 characters

Optional body explaining why the change is needed, wrapped at 72.
```

Types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`,
`style`, `chore`. Scopes are module names such as `core` or `surface`. Keep each
commit to one logical change that builds and passes tests on its own.

## Pull requests

- Keep PRs small and focused; fill in the template.
- CI must pass before merge.
- Feature PRs report idle CPU and memory measured with Instruments. The budgets
  are in the [implementation plan](docs/plan/implementation-plan.md#8-performance-gates).
- Prefer rebase over squash when the history tells a story; `main` takes no
  merge commits.

## Versioning and releases

ILoveNotch follows [Semantic Versioning](https://semver.org/) with `vX.Y.Z` tags.
Before 1.0, each minor version is a milestone (`v0.1` notch shell, `v0.2` media
and shelf, `v0.3` productivity) and patches are fixes. Releases ship as signed,
notarized DMGs on GitHub Releases.
