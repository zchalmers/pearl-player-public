> Historical engineering notes retained for context. Build and delivery instructions
> describe the original development workflow, not verification of this review copy.
> Run remote writes, uploads or device operations only after separate authorization.
> Use README.md for current configuration and validation limits.

# Agent task: the player and the engine (branch `pearl/player`)

Read `docs/BUILD-BRIEF.md`, then `SPEC.md` sections 4.3 through 4.8, then
`docs/vlckit-api-reference.md`. Files you own:

- `App/Player/**` (screen, view model, gesture surface, controls, HUDs, pickers)
- `App/Engine/**` (PlayerEngine protocol, VLCKit engine, PiP view)
- `Packages/PearlKit/Sources/PearlKit/Gestures/**`
- `Packages/PearlKit/Sources/PearlKit/Playback/**`
- matching test files under `Packages/PearlKit/Tests/PearlKitTests/` (new files only)

Do not touch `App/AppModel.swift`, `App/Library/**`, `App/Settings/**`,
`Packages/PearlKit/Sources/PearlKit/Store/**`. Another agent owns those.

## What to build

The headline feature, and the reason this app exists: **hold to fast forward**,
like YouTube. Press and hold anywhere on the picture, playback jumps to 2x and
keeps going at that rate, drag up while holding to climb through 3x, 4x up to
8x, drag back down to drop it, release returns to 1x. A badge shows the current
speed, the control overlay stays up during the gesture, a haptic ticks when the
speed changes, and the gesture never fights the double tap or the pan. The
plumbing is in `SeekMath.holdSpeed` and `PlayerViewModel.beginHold/updateHold/endHold`,
and `GestureCatcherView` already delivers long press movement. Make it feel
right, and add whatever the maths needs (a test for every rule you add).

Then, from the spec, in this order:

1. **Subtitles**: rich track picker, two tracks at once (dual language), sync
   offset with fine steps and a live readout, vertical position, full styling
   (font, size, bold, italic, text color, outline color and thickness, shadow,
   background box color and opacity, override embedded ASS styling), sidecar
   autoload matching the video file name, load from URL, and a subtitle search
   provider interface with a user supplied OpenSubtitles key that degrades
   gracefully when no key is set. Subtitle delay and style remembered per file.
2. **Quality picker**: when the source is an HLS master playlist, fetch it, list
   the variants with `HLSMasterPlaylist`, let the user pin one by playing that
   variant URI directly, and offer Auto to hand control back to the engine.
3. **Audio**: track picker with language, codec and channel detail, audio delay,
   10 band equalizer with presets, volume boost, mono downmix, passthrough
   toggle for AC3 and DTS.
4. **Video**: aspect ratio menu (fit, fill, stretch, original, 16:9, 4:3, 1:1,
   2.35:1), rotate and flip, video adjustments (brightness, contrast,
   saturation, hue, gamma), deinterlace, snapshot to Photos, record the current
   stream to a file, frame stepping while paused.
5. **Playback plumbing**: next and previous item, autoplay next, repeat modes,
   chapters and titles navigation, A-B loop with a visual band on the seek bar,
   sleep timer with a "finish this then stop" option, keep awake toggle, screen
   orientation lock, control lock that blocks gestures.
6. **Seek bar**: buffered range, chapter marks, A-B marks, thumbnail previews
   while scrubbing (VLCKit's thumbnailer, cache them, never block the gesture),
   precise scrubbing with the control style from the settings.
7. **Stats overlay**: the real numbers (codec, resolution, frame rate, bitrate,
   dropped frames, decoder, engine version) with a way to open it from the
   controls, and no invented values.
8. **Picture in Picture** wired end to end, plus AirPlay from the system route
   picker and the Chromecast and UPnP renderer list from VLCKit.

## Non negotiables

- Every engine capability stays behind `PlayerEngine`. SwiftUI never imports VLCKit.
- Game over is silent failure: if something cannot work, say so in the UI.
- Run `make linux-test`, `make lint` and `make format` before every commit.
- Push to `pearl/player` and drive the GitHub Actions run to green. Report the
  run id in `docs/agent-decisions.md`.
