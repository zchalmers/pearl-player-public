# Pearl Player - build specification

> Preserved design target and research. This is not a feature-completion or
> Apple-build verification claim. See README.md for current validation limits.

A full-featured iOS video player for Zach's iPhone 17 Pro Max, built to receive
streams handed off from Stremio and to beat Outplayer at the one thing Outplayer
is missing: YouTube-style hold to fast forward, on top of everything Outplayer,
VLC, Infuse and nPlayer already do.

| | |
|---|---|
| Product name | **Pearl Player** (rename is one string if Zach wants something else) |
| Bundle id | `org.example.pearlplayer` (example - override `PEARL_BUNDLE_ID` to match your own profile) |
| Device | iOS device selected by the operator, using their own UDID and profile |
| Toolchain | Xcode 27 (build 27A266a), iOS 27 SDK, Swift 6.4, deployment target iOS 26.0 |
| Engine | **VLCKit / libvlc 4.0.0-alpha.21** via SwiftPM (`virtualox/vlckit-spm`, exact pin) |
| Fallback engine | `rursache/VLCKitSPM` v4.0.0a19, then `kingslay/KSPlayer` if VLCKit cannot build on the iOS 27 SDK |
| Repo | Your review copy of `pearl-player` |
| Verify | Linux: `PearlKit` unit tests. CI: `xcode-27` macOS runner builds + runs simulator tests |
| Deliverable | Signed `PearlPlayer.ipa` installed on the device |

## 1. Why the engine decision is already made

AVPlayer cannot open MKV, which is what most Stremio/debrid streams are. Every
player Zach named (Outplayer, VLC, Infuse, nPlayer) ships its own demuxer.
libvlc gives the full container, codec, subtitle (including libass ASS/SSA
styling and PGS), audio track, network protocol and renderer support in one
dependency, plus Picture in Picture in the 4.0 series. So: VLCKit, with a thin
Swift wrapper of our own so the engine can be swapped without touching the UI.

## 2. What the three players actually ship (research, 2026-10-14)

| Feature | Outplayer | VLC iOS | Infuse | nPlayer |
|---|---|---|---|---|
| MKV / every container | yes | yes | yes | yes |
| 4K HDR | yes | yes | yes, DV P5/P8, HDR10+ | yes |
| Hold to fast forward | **NO** | no | no | no |
| Double tap seek | yes | yes | yes | yes |
| PiP | yes | yes | yes | yes |
| Subtitles styling | yes | yes, full SSA | yes | yes, SSA/ASS + fonts |
| Dual language subs | yes | multi-track | yes | yes |
| Audio track select | yes | yes | yes | yes |
| Subtitle sync | yes | yes | yes | yes |
| Speed control | yes | yes | yes | 0.5x-4x |
| Audio delay | n/a | yes | yes | yes |
| Equalizer | no | yes | no | no |
| Network protocols | SMB, Files | SMB, FTP, SFTP, NFS, UPnP, web | SMB, NFS, FTP, SFTP, WebDAV, UPnP, Plex, Emby, Jellyfin | WebDAV, FTP, SFTP, HTTP, SMB, UPnP |
| Chromecast | no | yes | Cast, AirPlay | yes, UPnP TV |
| Subtitle download | no | no | yes, OpenSubtitles | no |
| Chapters / playlists | yes | yes | yes | yes |
| Metadata library | Files only | no | yes, TMDB | yes |
| Wi-Fi upload | no | yes | yes | yes |
| Folder lock | no | no | parental controls | yes |
| Embedded browser | no | no | no | yes |
| Snapshot | no | yes | no | no |
| Record stream | no | yes | no | no |

Gap list we close: Outplayer's missing hold-to-ffwd, VLC's missing thumbnail
seekbar, Infuse's missing fine-grained seek gesture control, nPlayer's missing
modern UI, and all four's missing Stremio progress sync-back.

## 3. Stremio handoff contract (from stremio-core `src/deep_links/mod.rs`)

Stremio builds an `openPlayer` URL per platform and opens it. The iOS/native and
web client both use these exact forms:

| Stremio setting | URL it opens | Meaning |
|---|---|---|
| Outplayer | `outplayer://https://host/stream.mkv` | scheme-replaced URL, no encoding |
| VLC | `vlc-x-callback://x-callback-url/stream?url=<percent-encoded>` | x-callback-url form |
| Infuse | `infuse://x-callback-url/play?x-success=<enc>&x-error=<enc>&url=<enc>&position=<sec>` | with progress callback |
| M3U playlist | `data:` URI written out as `playlist.m3u` | downloads a playlist file |

So Pearl Player must:

1. Register `CFBundleURLSchemes`: `outplayer`, `vlc-x-callback`, `vlc`,
   `pearl`, `pearlplayer`.
2. Accept every form: `<scheme>://http(s)://...`, `<scheme>://` with a
   percent-encoded value (with and without a `url=` key), `x-callback-url/stream`
   and `x-callback-url/play`, and plain `http(s)://` handed over as a document
   open. Percent-decode, strip nested schemes, then play.
3. Register document types for video UTIs (`public.movie`, `public.video`,
   `public.audiovisual-content`, `public.mpeg-4`, `com.apple.quicktime-movie`,
   matroska/AVI/WebM UTIs) so "Open in" and the Safari/Files share sheet reach it
   too, without requiring a separate App ID for a Share Extension.
4. **Sync progress back to Stremio**: after playback, open
   `stremio:///detail/<type>/<id>/<videoId>?position=<seconds>&lastPlayedUrl=<url>`.
   stremio-web reads `position` on that URL and marks the video watched position
   (see `useExternalPlayerCallback.ts`). Offer auto-on-exit plus a manual
   "Sync to Stremio and go back" button.
5. Ship an in-app setup screen with the two ways to point Stremio at Pearl:
   - Stremio's own dropdown (pick `Outplayer` or `VLC` after deleting that app, so
     the scheme resolves to Pearl), and
   - a copy/paste Safari userscript for Stremio Web that rewrites stream clicks to
     `pearl://<stream-url>`, which works even with Outplayer or VLC still
     installed.

## 4. Feature set to implement (all of it)

### 4.1 Container, codec, decode
- MKV, MP4, M4V, MOV, AVI, TS/M2TS, WEBM, FLV, WMV, OGV, RMVB, VOB, 3GP, MPEG, DIVX, OGM, FLV, MXF
- H.264, H.265/HEVC, AV1, VP9, VC-1, MPEG-2, WMV3
- Hardware decode on with fallback to software, plus a manual toggle
- HDR10, HLG, HDR10+, Dolby Vision pass-through or tone map (engine dependent)
- AC3, E-AC3, DTS, AAC, FLAC, MP3, Opus, Vorbis, PCM, WMA, ALAC + stereo downmix
- Audio pass-through toggle for AC3/DTS when on a receiver or AirPlay

### 4.2 Sources
- Local files via Files app ("Open in Pearl", in-place open, folder browsing)
- Built-in library: folders, search, sort by name/date/size/duration, grid and
  list, favorites, playlists (create, rename, reorder, delete)
- Open network stream by URL, with **custom HTTP headers, User-Agent and Referer**
  per source (debrid streams need this), and network cache size control
- Remote servers: SMB/CIFS, NFS, FTP/FTPS/SFTP, WebDAV, UPnP/DLNA browse and play
- Downloads from URL with progress, pause, queue, delete, background continue
- Wi-Fi transfer: tiny embedded HTTP server with a browser upload page so the
  laptop can drop files onto the phone
- Clipboard link detection at launch ("Play the link you copied?")
- Resume positions per URL and per file, watched markers, recent history

### 4.3 Gestures (every one configurable)
- Single tap: show/hide controls
- Double tap left / right: seek -/+ N seconds (5/10/15/20/30/60, configurable)
- Double tap center: play/pause
- **Long press: hold to fast forward.** Hold for 2x, drag up while holding to
  climb 3x/4x/8x, drag down to drop back. Release returns to 1x. Haptic tick,
  on-screen "3x >>" HUD, works from the first second and cancels the control
  auto-hide.
- Horizontal drag: scrub, distance-scaled (short drag = second precision, longer =
  minute skips), with time delta HUD and thumbnail preview per position
- Vertical drag, left half: brightness (screen brightness with a HUD)
- Vertical drag, right half: volume (gain with a HUD, boost past 100 percent)
- Pinch: zoom from fit to fill and back, pan while zoomed
- Two finger tap: play/pause. Two finger vertical drag: subtitle vertical offset
- Edge double tap (screen edge within N points): chapter skip or +/- 30s
- Long press seek bar: variable-speed scrubbing
- Swipe down on video: dismiss player. Swipe up: expand to fullscreen

### 4.4 On-screen controls
- Top: back, title and source, cast, PiP, subtitle quick toggle, more menu
- Bottom: play/pause, prev/next, seek bar with buffered range, chapter marks and
  A-B markers, current and remaining time, speed menu, audio track, subtitle
  track, aspect ratio, rotate lock, playlist, sleep timer, lock controls
- Center: buffer spinner, error banner with retry, tap-to-play on stall
- HUDs: seek delta, speed, volume, brightness, subtitle offset
- Auto-hide with configurable delay, tap-lock, orientation lock, keep-awake
  toggle, stats overlay, clock and battery readout
- AirPlay picker, Chromecast/UPnP renderer list
- Thumbnail previews while scrubbing, generated from the engine

### 4.5 Subtitles
- Embedded tracks plus external SRT, ASS/SSA (full libass styling), VTT, SUB,
  MicroDVD, SMI, TXT, IDX/SUB, PGS, DVB, VobSub, image subs
- Auto-load sidecar file matching the video name, and a load-from-URL field
- Two subtitle tracks at once (primary + secondary), with per-track style
- Sync offset up and down in 0.05s steps, remembered per file
- Styling: font, size, bold, italic, text color, outline color and thickness,
  shadow, background box color and opacity, vertical position, override embedded
  ASS styling toggle
- Preferred language auto-select with a priority list, forced-subtitle handling
- Subtitle search and download behind a provider interface (OpenSubtitles with a
  user supplied key, plus the always-working local file and URL paths)
- Drag subtitles up and down directly on the video

### 4.6 Audio
- Track picker showing language, codec, channels, bitrate, title
- Audio delay plus and minus, remembered per file
- 10-band equalizer with presets, volume boost to 200 percent, normalize,
  mono/stereo swap, spatial audio toggle

### 4.7 Video and quality
- HLS master playlist parsing so the user can pick a variant (quality) by
  rewriting to the chosen variant URI, plus an "auto" entry that hands control
  back to the engine
- Live readout of current resolution, bitrate, codec, fps, decoder, dropped
  frames and buffer level in the stats overlay
- Aspect ratio: fit, fill, stretch, original, 1:1, 3:2, 4:3, 5:3, 16:9, 16:10,
  2.35:1, 2.39:1, custom
- Rotate 90/180/270, flip horizontal and vertical, zoom and pan
- Video adjustments: brightness, contrast, saturation, hue, gamma, deinterlace
  off/auto/on
- Video and subtitle delay, snapshot to Photos, record a segment of the stream

### 4.8 Playback plumbing
- Background audio playback, Now Playing artwork and metadata, lock screen and
  Control Center transport, headphone and remote command support
- Picture in Picture, AirPlay, Chromecast/UPnP renderers
- Speed 0.25x to 4x, pitch correction toggle, remember per source
- A-B loop, repeat one/all, shuffle, autoplay next, continue-watching prompt
- Chapters and titles navigation, bookmark creation
- Sleep timer with "finish the episode then stop"
- Frame stepping while paused, precise (frame-accurate) seeking while paused

### 4.9 Library, safety, polish
- Optional Face ID folder lock
- Wi-Fi transfer page, snapshot gallery, share and export to Files
- Settings for every option above, persisted, with search
- Diagnostics screen: engine version, decode mode, log tail, reset
- Siri / App Intents: "Play in Pearl" (URL), "Resume last video"
- Accessibility: VoiceOver labels on every control, Dynamic Type, reduced motion
- No default telemetry or app accounts. Playback and enabled network features use the network.
  Remote diagnostics require explicit operator configuration and may contain sensitive URLs.

## 5. Architecture

```
Projects/pearl-player/
  project.yml                 XcodeGen spec, one app target, VLCKitSPM dependency
  Makefile                    linux-test / linux-build / generate / build / test-sim / archive
  Packages/PearlKit/          Swift 6, Foundation only, no SwiftUI, no VLCKit
    Sources/PearlKit/
      DeepLink/               every Stremio and external URL form to a PlayRequest
      Playlist/               HLS master playlist parse + variant selection
      Library/                media item model, scanning, sorting, sidecar matching
      Store/                  settings model, resume store, playlist store, history
      Seek/                   gesture math: hold speed curve, scrub scaling, zones
      Sources/                URL and credential builders for SMB/WebDAV/FTP/UPnP
      Support/                time formatting, human sizes, language names, stats text
    Tests/PearlKitTests/      Swift Testing, every rule above
  App/
    PearlPlayerApp.swift      @main, scene, URL and document intake
    Engine/                   PlayerEngine protocol + VLCKitEngine + AVPlayerEngine fallback
    Player/                   PlayerView, PlayerViewModel, controls, HUDs, gestures
    Library/                  library, folders, downloads, network sources, Wi-Fi transfer
    Settings/                 full settings tree, subtitle style editor, diagnostics
    Resources/Info.plist      schemes, document types, background modes, launch screen
  AppTests/                   simulator integration tests (deep links, engine boot)
```

Rules for the implementation:

1. All logic that can live without SwiftUI and VLCKit lives in `PearlKit` and has
   a Linux-runnable test. If a rule matters, its test is in `PearlKitTests`.
2. The SwiftUI layer is thin: views plus a `PlayerViewModel` that talks to
   `PlayerEngine`. No engine type leaks past that protocol.
3. The Info.plist carries the iOS 27 hard gates: a launch screen declaration and
   a scene manifest, or the app will not launch.
4. Bundle id defaults to `org.example.pearlplayer`. Override `PEARL_BUNDLE_ID` to match your own profile.
5. No App Extensions, no WidgetKit target, no App Groups in the current app.
   Additional targets would require their own signing configuration.

## 6. Verification

| Layer | Where | Command |
|---|---|---|
| Core rules | your Linux host, seconds | `make linux-test` |
| Format and lint | your Linux host | `make lint`, `make format-check` |
| App compile + simulator tests | GitHub Actions `xcode-27` | `.github/workflows/ios.yml` |
| Device | iPhone 17 Pro Max | signed IPA install |

The Linux loop is the fast one and is expected to carry several hundred tests
across deep links, playlists, stores and gesture math.

## 7. Delivery

1. CI builds Release for `iphoneos` with code signing off, then signs with
   `Development.p12` plus `Development.mobileprovision` (kept as GitHub Actions
   secrets, never in the repo), packs `Payload/` into `PearlPlayer.ipa`, and
   uploads it as an artifact.
2. Install to the device over USB from your Linux host (`pymobiledevice3`) with
   Developer Mode on, or through SideStore on the phone as a fallback.
3. Keep the built-in setup screen that walks through pointing Stremio at Pearl.
