> Historical engineering notes retained for context. Build and delivery instructions
> describe the original development workflow, not verification of this review copy.
> Run remote writes, uploads or device operations only after separate authorization.
> Use README.md for current configuration and validation limits.

## library agent

- Persisted settings and library metadata as atomic JSON documents in the Documents directory. Passwords are excluded
  from source JSON and stored in the device-only Keychain.
- UPnP and DLNA use the same manual source form as the other network protocols. The VLCKit media discoverer is owned by
  the engine layer, which this task explicitly cannot change. The saved URL still goes through `AppModel.present(_:)`.
- File thumbnails use Quick Look at the library boundary. Duration sorting falls back to file name when duration metadata
  is unknown, so the interface never invents a duration.
- Wi-Fi transfer is intentionally active only while its screen is visible. It uses an ephemeral TCP port, a browser upload
  page, HTTP PUT, and a QR code. Uploaded files land directly in Documents.
- Folder locks use device-owner authentication, which allows Face ID or the device passcode, and remain off until a folder
  is explicitly added to the lock set.
- CI run `38526497119` passed PearlKit and exposed two library compile errors, which were fixed in `0b46d6d`.
- Replacement CI run `38526690964` passed PearlKit and reported no errors in `App/Library/**`, `App/Settings/**`, the
  PearlKit stores, or the library-owned code in `AppModel.swift`.
- The simulator job in `38526690964` remains blocked only by files this agent was forbidden to edit. Exact remaining
  steps are for the engine/player owner to fix the `VLCKitEngine` and `VLCPictureInPictureView` Objective-C protocol
  conformances and VLCKit Swift API names in `App/Engine/**`, plus replace the unavailable `translation` call on
  `UILongPressGestureRecognizer` in `App/Player/GestureCatcherView.swift`. After those changes land, rebase or merge them
  into `pearl/library`, rerun the three local gates, push, and watch the new iOS run to green.
