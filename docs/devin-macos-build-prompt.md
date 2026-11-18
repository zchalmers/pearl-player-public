> Historical engineering notes retained for context. Build and delivery instructions
> describe the original development workflow, not verification of this review copy.
> Run remote writes, uploads or device operations only after separate authorization.
> Use README.md for current configuration and validation limits.
> Bundle checks below use the generic default. Adapt them if you override `PEARL_BUNDLE_ID`.

You are building **Pearl Player**, a native iOS 27 video player, on a macOS environment that has Xcode. Repo: `zchalmers/pearl-player`, branch `master`. Clone it and work in it.

## 1. Toolchain
```bash
xcodebuild -version                     # expect Xcode 27
which xcodegen || brew install xcodegen xcbeautify
xcodegen generate
```

## 2. Run the simulator tests and report exactly what happened
```bash
set +e
mkdir -p .build
xcodebuild -project PearlPlayer.xcodeproj -scheme PearlPlayer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test > .build/build.log 2>&1
status=$?
set -e
xcbeautify < .build/build.log || tail -60 .build/build.log
if [ "$status" -ne 0 ]; then
  grep -n -B4 -A8 "error:" .build/build.log | head -300
  RESULT="$(ls -d .build/DerivedData/Logs/Test/*.xcresult | head -1)"
  xcrun xcresulttool get test-results summary --path "$RESULT" --format json | head -60
fi
```

**What is under test.** A previous crash was captured and read: `EXC_BAD_ACCESS (SIGSEGV), KERN_INVALID_ADDRESS at 0x0000000000000004` with the frames `vlc_mutex_trylock` -> `libvlc_media_list_lock` -> `libvlc_media_list_player_play_item` -> `-[VLCMediaListPlayer playMedia:]_block_invoke` on a dispatch worker thread. Cause: calling `playMedia:` on a `VLCMediaListPlayer` that never had a `mediaList` assigned, so libvlc locked a NULL media list. The current commit `Engine: always set the media list before playing` always assigns a `VLCMediaList` first and then calls `play()`, and `play()` is guarded with `guard listPlayer.mediaList != nil`.

Confirm whether the crash is gone. If it is **not** gone, extract the crash report from the xcresult and read the real frames before changing anything:
```bash
# .ips attachments are zstd compressed
zstd -d -c "<xcresult>/Data/data.0~<ref>" > /tmp/crash.ips
python3 - <<'PY'
import json
text = open("/tmp/crash.ips", encoding="utf-8", errors="replace").read()
header, _, body = text.partition("\n")
data = json.loads(body)
print("exception:", data["exception"])
for index, thread in enumerate(data.get("threads", [])):
    if thread.get("triggered"):
        for frame in thread.get("frames", [])[:14]:
            image = data.get("usedImages", [{}])[frame.get("imageIndex", 0)]
            print("   ", image.get("name"), frame.get("symbol") or hex(frame.get("imageOffset", 0)))
PY
```
Then fix the cause in `App/Engine/VLCKitEngine.swift` and re-run. Do not silence a test to make the suite pass.

## 3. Unsigned device build and IPA
No certificate exists in this environment, and that is fine: this IPA is for an on-device sideloading installer that re-signs it, so it must be an unsigned Release archive.
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
python3 - "$APP/Info.plist" <<'PY'
import plistlib, sys
plist = plistlib.load(open(sys.argv[1], "rb"))
schemes = [s for entry in plist.get("CFBundleURLTypes", []) for s in entry.get("CFBundleURLSchemes", [])]
print("bundle id:", plist.get("CFBundleIdentifier"))
print("schemes:", schemes)
print("launch screen:", "UILaunchScreen" in plist, "scene manifest:", "UIApplicationSceneManifest" in plist)
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
unzip -l exports/PearlPlayer-unsigned.ipa | head -12
```
If the plist check fails, the `INFOPLIST_FILE: App/Resources/Info.plist` setting in `project.yml` has regressed (XcodeGen's `info:` block silently generates a replacement plist, which is why it is not used). Fix it and rebuild.

## 4. Hand the IPA back
The IPA has to travel to the operator's machine, so push it on its own branch:
```bash
git checkout -b builds/ipa
git add -f exports/PearlPlayer-unsigned.ipa
git commit -m "Unsigned, simulator tested PearlPlayer.ipa"
git push -u origin builds/ipa
```
Do not touch `master`. Also print the SHA-256 and the byte size of the pushed file.

## 5. Report
Short and factual: the test result with counts, whether the media-list crash is gone, the archive result, the plist check, the IPA name, size and SHA-256, the branch you pushed, and anything you could not verify. Report real command output, never what you intended to happen. If a command fails, give the exact command and its exact error.

## Discipline
Commit after every meaningful step. If you sense a usage or context limit coming, commit and push whatever is coherent immediately and write the exact remaining steps and blockers into `docs/verification-status.md`. Preserving work beats starting something new.
