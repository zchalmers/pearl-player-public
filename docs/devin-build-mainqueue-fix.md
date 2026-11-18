> Historical engineering notes retained for context. Build and delivery instructions
> describe the original development workflow, not verification of this review copy.
> Run remote writes, uploads or device operations only after separate authorization.
> Use README.md for current configuration and validation limits.
> Bundle checks below use the generic default. Adapt them if you override `PEARL_BUNDLE_ID`.

You are building **Pearl Player**, a native iOS 27 video player, on a macOS machine that has Xcode. Repo: `zchalmers/pearl-player`, branch `master` (HEAD is `5c0a084`). Clone it and work in it.

## 0. Environment facts from the previous session on this image (verified)
- `xcode-select` points at Xcode 26.6 (Swift 6.3.3), which cannot resolve `PearlKit` (`swift-tools-version: 6.4`).
  Every `xcodebuild`/`swift` call needs `DEVELOPER_DIR=/Applications/Xcode-27.0-RC.app/Contents/Developer` (Xcode 27.0 RC, Swift 6.4).
- `xcodegen` is already installed (if not: `brew install xcodegen xcbeautify`).
- Known test-host quirk, unrelated to this task: tests that call `present()` (fullScreenCover) get killed by the iOS launch watchdog at about 22-24 seconds under testmanagerd. Those deaths also happen on unmodified master. Do not chase them.

## 1. What changed and what has to be proven
The app was installed on the physical phone and **crashed immediately on the play tap**. Crash report frames, faulting thread 11:

```
libdispatch.dylib  _dispatch_assert_queue_fail
libdispatch.dylib  dispatch_assert_queue
libswift_Concurrency.dylib  _swift_task_checkIsolatedSwift
PearlPlayer  0x75ab8
VLCKit  __HandleStateChanged_block_invoke
VLCKit  -[VLCEventsHandler handleEvent:]
VLCKit  HandleStateChanged
VLCKit  on_state_changed
VLCKit  vlc_player_input_HandleState
```

Cause: `VLCEventsDefaultConfiguration` returns `dispatchQueue = nil, isAsync = NO`, so VLCKit runs its delegate callbacks synchronously on a libvlc input thread. The project sets `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`, so `VLCKitEventBridge` is main actor isolated and the Swift concurrency runtime traps when it is called from that thread.

Fix in `5c0a084`: both events configurations are now `VLCEventsLegacyConfiguration()` (main queue, async). A new test `playsARealStream` in `AppTests/PearlPlayerTests.swift` loads and plays a real HLS stream for ten seconds so the callback path runs.

Prove it:
```bash
export DEVELOPER_DIR=/Applications/Xcode-27.0-RC.app/Contents/Developer
xcodebuild -version                       # must print Xcode 27
cd pearl-player
xcodegen generate
set +e
xcodebuild -project PearlPlayer.xcodeproj -scheme PearlPlayer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test > .build/test.log 2>&1
echo "test exit: $?"
set -e
xcbeautify < .build/test.log | tail -60
```
Report the pass/fail list by test name, not just the summary. `playsARealStream` must pass. If it traps, the fix did not work: read the crash before changing anything.

## 2. Manual launch check (the strongest evidence)
Install the built app on the booted simulator, open a real stream through the URL scheme, and confirm the process stays alive and actually plays:
```bash
APP=$(find .build/DerivedData/Build/Products -name 'PearlPlayer.app' -maxdepth 3 | head -1)
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install booted "$APP"
xcrun simctl launch booted org.example.pearlplayer
sleep 3
xcrun simctl openurl booted "outplayer://https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"
sleep 15
xcrun simctl spawn booted launchctl list | grep -i pearlplayer || echo "process gone"
```
Report whether the process is still running after the openurl and whether any new `.ips` appeared in `~/Library/Logs/DiagnosticReports`.

## 3. Unsigned device build and IPA
No certificate exists here and that is fine: the operator signs it on Linux with the operator-supplied certificate. Produce an unsigned Release archive:
```bash
set +e
xcodebuild -project PearlPlayer.xcodeproj -scheme PearlPlayer \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath .build/PearlPlayer.xcarchive \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  archive > .build/archive.log 2>&1
echo "archive exit: $?"
set -e
APP=.build/PearlPlayer.xcarchive/Products/Applications/PearlPlayer.app
ls -l "$APP" "$APP/Frameworks/VLCKit.framework/VLCKit"
python3 - "$APP/Info.plist" <<'PY'
import plistlib, sys
plist = plistlib.load(open(sys.argv[1], "rb"))
schemes = [s for entry in plist.get("CFBundleURLTypes", []) for s in entry.get("CFBundleURLSchemes", [])]
print("bundle id:", plist.get("CFBundleIdentifier"))
print("schemes:", schemes)
print("executable:", plist.get("CFBundleExecutable"))
missing = [k for k in ("outplayer", "vlc-x-callback", "pearl") if k not in schemes]
if plist.get("CFBundleIdentifier") != "org.example.pearlplayer" or missing or "UILaunchScreen" not in plist:
    print("PLIST REGRESSION", missing)
    raise SystemExit(1)
PY
rm -rf .build/Payload && mkdir -p .build/Payload exports
cp -R "$APP" .build/Payload/
(cd .build && zip -qry ../exports/PearlPlayer-unsigned.ipa Payload)
ls -lh exports/PearlPlayer-unsigned.ipa
shasum -a 256 exports/PearlPlayer-unsigned.ipa
unzip -l exports/PearlPlayer-unsigned.ipa | head -14
```
The IPA must contain `Payload/PearlPlayer.app/Frameworks/VLCKit.framework/VLCKit` (about 49 MB) or the app cannot start.

## 4. Hand the IPA back
Push it on the build branch, force-updating it, and do not touch master:
```bash
git fetch origin builds/ipa
git checkout -B builds/ipa origin/builds/ipa
cp exports/PearlPlayer-unsigned.ipa exports/PearlPlayer-unsigned.ipa
git add -f exports/PearlPlayer-unsigned.ipa
git commit -m "Unsigned PearlPlayer.ipa with main-queue libvlc callbacks"
git push -f origin builds/ipa
shasum -a 256 exports/PearlPlayer-unsigned.ipa
```
If `builds/ipa` does not exist, create it from master content only (`git checkout --orphan builds/ipa`, add the IPA, commit, push).

## 5. Report
Short and factual: the exact `xcodebuild -version`, the test results by name, whether `playsARealStream` passed, the simulator launch/openurl result, the archive result, the plist check, the IPA size and SHA-256, and anything you could not verify. Report real command output, never what you intended to happen.

## Discipline
Commit after every meaningful step. Do not rewrite unrelated code, do not silence tests, do not change `project.yml` settings. If you hit a usage or context limit, commit and push whatever is coherent immediately and write the exact remaining steps into `docs/verification-status.md`.
