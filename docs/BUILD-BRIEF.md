> Historical engineering notes retained for context. Build and delivery instructions
> describe the original development workflow, not verification of this review copy.
> Run remote writes, uploads or device operations only after separate authorization.
> Use README.md for current configuration and validation limits.

# Build brief for coding agents

You are building **Pearl Player**, a native iOS 27 video player in Swift 6, for
Zach's iPhone 17 Pro Max. Read `SPEC.md` first: it is the contract, and it lists
every feature that must exist. Then read `README.md` for the layout and the
signing constraints.

## The hard facts of this machine

- This host is Linux. There is **no Xcode, no simulator, no iOS SDK here**, so
  nothing that imports SwiftUI, UIKit, AVFoundation or VLCKit can be compiled
  locally. Do not claim a UI change is tested.
- `Packages/PearlKit` is Foundation only. It builds and its tests run here in
  seconds. **Every rule that can live without a screen belongs there, with a
  test.** This is your real local gate:

```bash
export PATH="$HOME/.local/share/swiftly/bin:$HOME/.local/bin:$PATH"
make linux-test          # swift test, must stay green
make lint                # swiftlint, must have no errors
make format              # swift format --in-place, run before every commit
```

- The Apple build runs in GitHub Actions on a `xcode-27` macOS runner. That is
  how SwiftUI code gets verified, and it costs wall-clock time and macOS CI
  minutes, so **batch your changes** rather than pushing a fix per file.

## Your compile loop

```bash
git add -A && git commit -m "<what changed>" && git push origin HEAD
gh run list --limit 3                      # find your run
gh run watch <run-id> --exit-status        # wait for it
gh run view <run-id> --log-failed          # read the failures
```

Fix the failures, commit, push again. Do not merge to master: the supervisor
merges. Do not push to a branch that is not yours.

## Rules

1. **Stay inside your file ownership.** Two agents work in parallel. Touching the
   other's files creates conflicts that cost more than they save.
2. **Commit often, in small coherent steps.** A cutoff that leaves a clean tree
   is recoverable, a lost dirty tree is not. Push what works even if the feature
   is unfinished, as long as it compiles.
3. **Never halt on a question.** No one is going to answer mid-run. Decide, write
   the decision and the reasoning into `docs/agent-decisions.md` under your own
   heading, and keep going. Product judgement calls are yours to make; note them.
4. **No fabrication.** If a command fails, report the exact command and the exact
   error. Never invent test output, never claim a build passed without the run id.
5. **VLCKit API is not guesswork.** `docs/vlckit-api-reference.md` is the real
   4.0.0-alpha.21 API, generated from the shipped headers. Read it before writing
   engine code. If something is not in there, it does not exist.
6. **iOS 27 gates:** `Info.plist` must keep its launch screen declaration and its
   scene manifest, or the app will not launch on the device.
7. **Bundle id defaults to `org.example.pearlplayer`.** Override `PEARL_BUNDLE_ID`
   to match your own signing profile. Extensions would need separate App IDs.
8. **Do not touch** `project.yml`, `App/Resources/Info.plist`, `Packages/PearlKit/Package.swift`,
   or `.github/workflows/ios.yml` unless the supervisor asks. New Swift files under
   `App/` are picked up automatically by XcodeGen.
9. Write like a person: no em dashes, no semicolons, no startup jargon. Comments
   explain why, not what. Match the existing files.
