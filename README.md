# Pearl Player

Pearl Player is a native iOS video player with Stremio link handoff and configurable playback gestures.

The player accepts direct media URLs, local documents and external-player links from Stremio. Its hold-to-fast-forward gesture temporarily raises playback speed, while the library keeps recent items, resume positions, favorites and playlists. VLCKit supplies container, codec, subtitle and renderer support rather than relying on AVPlayer alone for formats such as MKV.

`SPEC.md` preserves the feature specification and engine research. It is a design target, not proof that every requested feature works. `docs/` preserves task briefs, development decisions, build investigations and VLCKit API reference headers with their upstream notices.

## Architecture

- `Packages/PearlKit/`: Foundation-only Swift package for URL intake, playlists, HLS variant parsing, Stremio callbacks, gesture math, settings and JSON stores. Its existing tests run on Linux without Apple frameworks.
- `App/AppModel.swift`: routes incoming links, documents and clipboard suggestions into playback and records history and progress.
- `App/Engine/`: `PlayerEngine` interface, VLCKit implementation, video host, Picture in Picture integration and optional remote diagnostics.
- `App/Player/`: SwiftUI playback controls, player view model and UIKit gesture handling.
- `App/Library/` and `App/Settings/`: local browsing, downloads, collections, network-source metadata, Keychain credential storage, folder authentication and Wi-Fi transfer.
- `App/Resources/Info.plist`: URL schemes, supported document types, launch configuration and background-audio declaration.
- `project.yml`: XcodeGen specification. The generated Xcode project is not committed.
- `AppTests/`: Apple-platform integration tests, including engine initialization and stream playback.

## Notable engineering decisions

1. URL parsing lives outside the UI and engine. It handles scheme swaps, percent encoding, nested wrappers, playlist data URIs and the stripped inner colon seen in incoming iOS links.
2. The player UI depends on `PlayerEngine`, leaving VLCKit-specific track, renderer and playback plumbing in the engine layer.
3. The engine shares one `VLCLibrary`, assigns a media list before playing and uses legacy main-queue event delivery. The retained build notes explain the lifetime and Swift isolation crashes behind those choices.
4. Gesture math is independently testable. Holding temporarily changes speed and releasing restores the selected playback rate.
5. Settings and library metadata use lock-protected atomic JSON writes. Network-source passwords are stored separately in the device-only Keychain, not in the metadata JSON.
6. Stremio progress return is built from the callback supplied with a handoff. A plain external-player link without a callback cannot provide the same return path.

## Stack and prerequisites

- Swift 6.4 package tools, Foundation and Swift Testing.
- SwiftUI, UIKit, AVFoundation, MediaPlayer, Network, Security and LocalAuthentication on iOS.
- VLCKit 4.0.0-alpha.21 through the exact `virtualox/vlckit-spm` dependency pin.
- XcodeGen and Make. SwiftLint is optional for the lint target.
- The project specifies iOS 26 minimum, Xcode 27 and the iOS 27 SDK. Apple builds require a compatible macOS environment and simulator runtime.

## Local development

With Swift 6.4 or a compatible newer toolchain on PATH:

```bash
make linux-test
make linux-build
make format-check
make lint           # requires swiftlint
```

On a Mac with the required Xcode and XcodeGen installed:

```bash
make generate
make build
make test-sim
```

`make format` rewrites Swift formatting. `make archive` produces an unsigned archive and does not install it anywhere.

The retained `.github/workflows/ios.yml` runs Linux core checks and defines an Apple simulator job. Both Apple workflows currently name an `xcode-27` runner. Availability of that runner label has not been verified for this review copy. Review runner selection before enabling them.

## Signing and installation

Use your own certificate and provisioning profile. No signing material is included.

The generic default bundle identifier is `org.example.pearlplayer`. `project.yml` defines `PEARL_BUNDLE_ID`, which can be overridden in an Xcode build:

```bash
xcodebuild -project PearlPlayer.xcodeproj -scheme PearlPlayer \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath .build/PearlPlayer.xcarchive \
  PEARL_BUNDLE_ID=org.example.yourplayer \
  CODE_SIGNING_ALLOWED=NO archive
```

Choose an identifier registered in your own profile, not the example above. The project leaves the development team empty. Configure your team and profile for direct Xcode signing. The retained release workflow instead builds unsigned, takes entitlements from the supplied profile, signs embedded frameworks before the app, verifies the package and uploads an IPA artifact.

For that workflow, set the repository variable `IOS_BUNDLE_ID` to your registered identifier and provide secrets `P12_BASE64`, `P12_PASSWORD`, `PROFILE_BASE64` and `SIGN_IDENTITY`. The helper `scripts/set-signing-secrets.sh` requires explicit `REPO`, `SIGN_IDENTITY` and `P12_PASSWORD` environment variables. It reads `certs/Development.p12` and `profiles/Development.mobileprovision` under `IOS_DEV_KIT`, defaulting to `$HOME/ios-dev`. Running the helper changes repository secrets, so do so only when you intend that remote write.

Alternatively, `scripts/prepare-install.sh path/to/unsigned.ipa` signs locally with zsign and checks the package. Set `P12_PASSWORD`, `PEARL_BUNDLE_ID`, `IOS_DEV_KIT` and `ZSIGN` for your environment. With no IPA argument, the script fetches a `builds/ipa` branch from a separately configured origin. There is no remote configured in this review copy. Output stays in `exports/` unless you explicitly set `PUBLISH_DIR` to an additional local destination. The script does not host or upload the result.

For a separately authorized USB installation from Linux:

```bash
UDID=YOUR_DEVICE_UDID scripts/install-on-device.sh exports/PearlPlayer-signed.ipa
```

This requires pymobiledevice3, usbmuxd, a trusted USB connection and Developer Mode where required by the signing method. The installation helper can start usbmuxd through sudo. SideStore or another compatible on-device signer is an alternative. The app has no extension, widget or App Group targets. Adding such targets would require separate signing configuration.

## Stremio handoff

Pearl registers `outplayer`, `vlc`, `vlc-x-callback`, `pearl` and `pearlplayer`. Stremio's external-player dropdown can reach it through the Outplayer or VLC choice when those apps do not claim the same scheme. Scheme ownership is not guaranteed when competing apps are installed.

The in-app setup screen also supplies a Safari userscript that rewrites Stremio Web stream links to Pearl links with a progress callback. Stremio's own forms include `outplayer://<url>`, `vlc-x-callback://x-callback-url/stream?url=...`, an Infuse-shaped callback link and a playlist data URI.

When a handoff includes a callback, exiting playback can return a URL such as:

```text
stremio:///detail/<type>/<id>/<videoId>?position=<seconds>&lastPlayedUrl=<url>
```

Pearl plays direct streams. Magnet and torrent links require a separate stream engine and produce an explanatory notice instead.

## Optional diagnostics and local-network safety

Remote logging is disabled by default. To enable it for a debugging run, set `PEARL_REMOTE_LOG_URL` in the app's process environment, for example through an Xcode scheme, to your own HTTPS collector. No endpoint is bundled and missing, malformed or non-HTTPS values skip logging. Restart the app after changing the value.

The collector receives POST requests containing newline-separated UTF-8 app events and libvlc messages with `Content-Type: text/plain; charset=utf-8`. Logs can include complete media URLs, credentials in URLs and playback details. Use only a collector you control and protect its access and retention. There is no collector authentication configuration in the current mechanism.

Wi-Fi transfer runs only while its screen is visible and accepts unauthenticated plaintext HTTP uploads. Use it only on a trusted local network. Playback, downloads, renderer discovery and user-enabled diagnostics can use the network. Local histories and URLs can contain sensitive information.

## Validation limits

Preparation exercised the existing PearlKit Linux tests and build. It did not build SwiftUI or VLCKit, run an Apple simulator, sign an IPA or install to a device. The publication report records the exact checks performed. Apple runner availability, real playback, gesture behavior, codec support, signing and device installation remain unverified for this review copy. Historical build notes are preserved as context, not new build evidence.
