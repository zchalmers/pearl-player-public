> Historical engineering notes retained for context. Build and delivery instructions
> describe the original development workflow, not verification of this review copy.
> Run remote writes, uploads or device operations only after separate authorization.
> Use README.md for current configuration and validation limits.

# Agent task: library, settings and sources (branch `pearl/library`)

Read `docs/BUILD-BRIEF.md`, then `SPEC.md` sections 4.2 and 4.9, and the gesture
list in 4.3 (you build the screen that configures it, not the gesture maths).
Files you own:

- `App/Library/**` (new)
- `App/Settings/**` (new)
- `App/AppModel.swift` and the `RootView` in it
- `Packages/PearlKit/Sources/PearlKit/Store/**` (new)
- `Packages/PearlKit/Sources/PearlKit/Support/**` (new files only)
- matching test files under `Packages/PearlKit/Tests/PearlKitTests/` (new files only)

Do not touch `App/Player/**`, `App/Engine/**`, `Packages/PearlKit/Sources/PearlKit/Playback/**`
or `Gestures/**`. Another agent owns those.

## What to build

1. **Settings, complete.** Every option in the spec, in a searchable settings
   tree with sections: Gestures, Playback, Subtitles and audio defaults,
   Appearance, Sources, Storage, Diagnostics about and Advanced. Persisted
   between launches. `GestureSettings` already exists in PearlKit for the gesture
   section, everything else is yours to model, and the model belongs in
   `PearlKit/Store` with tests (round trip, defaults, migration tolerant).
2. **Stores**: resume positions per URL and per file, watched markers, recents,
   favorites, playlists (create, rename, reorder, delete), bookmarks, subtitle
   style presets, per file subtitle and audio delay, playback history. All
   JSON backed, all tested on Linux.
3. **Library screen**: Documents browsing, folder navigation, grid and list,
   search, sort by name, date, size or duration, thumbnails from the engine,
   resume progress bars, multi select for delete, move, rename and share, and
   the Files app integration the Info.plist already declares.
4. **Downloads**: queue a URL, download with progress and pause and resume,
   keep going in the background, show the list with sizes, play or delete a
   finished download.
5. **Network sources**: add, edit and remove SMB, NFS, FTP, SFTP, WebDAV and
   UPnP and DLNA sources, credentials in the Keychain (never in plain JSON or
   logs), browse the tree and hand the URL to the player. UPnP and DLNA
   discovery through VLCKit's media discoverer if it is reachable from the app
   layer, otherwise a manual add form is acceptable, and say which in
   `docs/agent-decisions.md`.
6. **Wi-Fi transfer**: a small HTTP server on the device that serves an upload
   page to a browser on the same network, with the address and a QR code shown
   in the app, files landing in the Documents folder where the library sees them.
7. **Folder lock**: optional Face ID or passcode lock per folder, using
   LocalAuthentication, off by default.
8. **The launcher**: `RootView` becomes a real home screen (recent, favorites,
   downloads, sources, settings), and the existing URL field and clipboard
   detection stay working. Presenting the player stays through
   `AppModel.present(_:)`, which the other agent's screen consumes.

## Non negotiables

- Anything that can live without a screen goes in `PearlKit` with a Linux test.
  Aim for the store and settings logic to be fully covered there.
- No invented numbers anywhere in the UI. Unknown means show nothing.
- No telemetry, no network calls except where the feature requires them.
- Run `make linux-test`, `make lint` and `make format` before every commit.
- Push to `pearl/library` and drive the GitHub Actions run to green. Report the
  run id in `docs/agent-decisions.md`.
