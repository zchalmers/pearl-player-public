# Publication preparation report

## Status and scope

This is a local review candidate, not an approved publication. The export has fresh history with one initial commit and no remote. The original GitHub repository remains private. No GitHub settings, repositories, secrets or source history were changed during preparation.

The application, Swift package, existing tests, assets, workflows and useful engineering documentation were retained. No application feature was removed and no new dependencies, repository tests or CI jobs were added.

## Changes

- Replaced personal provisioning identifiers with a generic bundle identifier and an overridable `PEARL_BUNDLE_ID` build setting. The release workflow uses the `IOS_BUNDLE_ID` repository variable and checks the same chosen identifier after building.
- Removed the personal development-team setting, signing identity and certificate-password fallback. The signing helper now requires explicit repository, identity and password configuration.
- Removed the default device identifier from the USB installer. A user must supply their own `UDID` before the installer can proceed.
- Removed personal download-host instructions and local publishing defaults. The local signing helper only makes an extra copy when `PUBLISH_DIR` is explicitly configured.
- Changed remote diagnostics to require a valid HTTPS `PEARL_REMOTE_LOG_URL` process environment value. Missing or invalid configuration skips both queuing and requests. The logger's batching and text POST contract remain available when enabled.
- Replaced the personal background-download namespace with a bundle-derived identifier and made URL-type names follow the configured bundle identifier. The registered URL schemes are unchanged.
- Replaced a synthetic private-network test address with an RFC5737 documentation address, including the expected result. No parser or test behavior was changed.
- Updated README setup, architecture, signing, diagnostics and validation guidance. Scrubbed the specification and historical build notes in place rather than dropping their engineering content.
- Extended ignore rules for signing inputs, local environment files, archives and exports. Build outputs were removed after verification, not merely left ignored.

## Removed source files

| Path | Reason |
|---|---|
| `.devin/blueprint.yaml` | Machine-specific execution harness configuration, not application or engineering documentation. |
| `exports/PearlPlayer.ipa.sha256` | Stale checksum for a compiled export that is not included in the source candidate. Future builds calculate their own checksums. |

The temporary Swift build cache created during verification was also removed. It was not part of the original export.

## Preservation

- Original export: 89 files. Review candidate: 88 files, including this report.
- All 38 Swift files retained. Swift source line counts are 6,075 before and 6,082 after preparation.
- All 28 VLCKit reference headers are byte-for-byte unchanged, including upstream copyright, license notices and contact information.
- `SPEC.md`, `docs/BUILD-BRIEF.md`, task briefs, decision notes, build investigations and the VLCKit API reference remain present.
- The immutable source export was checked against a saved file-hash manifest and was unchanged.

## Verification performed

| Check | Result |
|---|---|
| `make linux-test` with Swift 6.4.1 on Linux | Passed, 56 tests in 7 suites. |
| `make linux-build` | Passed. |
| `make format-check` | Exit 0, with one existing line-length warning in an unchanged Apple integration test file. |
| `make lint` | Exit 0, 24 warnings. Read-only source baseline had the same warning count and no new warning messages were introduced. |
| Bash syntax for all three shell helpers | Passed. |
| Workflow YAML, project YAML and embedded workflow Bash syntax | Passed local parsing and syntax checks. This is not execution of the workflows. |
| Application Info.plist parsing | Passed, URL types retained. |
| Missing signing and device configuration | Helpers rejected missing required values before external operations. Repository, identity and password were each checked separately for the signing helper. |
| Logger configuration check outside the repository | Four cases passed using a network recorder and small VLCKit protocol stubs. Unset, malformed and non-HTTPS values produced no queued lines or requests. An explicitly configured HTTPS value preserved POST method, text content type and all submitted lines. No actual network collector was contacted. |
| Full candidate privacy and artifact checks | No personal endpoints, source signing identifiers, standalone certificate-password default, real device identifiers, credentials or prohibited artifacts detected by the checks used. |
| Source preservation and upstream headers | Passed. |

The logger check exercises adapted logger control flow with substitute protocol types and network I/O. It does not compile or validate the Apple application or VLCKit binary.

## Judgment calls

Historical task and build documents remain under their original filenames with a context notice. Their old branch names, run references and delivery examples are historical material, not instructions executed during this preparation or claims that those builds were reproduced.

Generic URL tokens, sample torrent identifiers, example domains and public media test URLs were retained as fixtures. A short numeric signing-password pattern also occurs inside longer synthetic magnet hashes. Those test values are not configured credentials and were not rewritten. Public dependency attribution and upstream email addresses were intentionally preserved.

## Residual risks

- No Apple simulator, device build, signing, IPA installation, renderer control or real playback validation was performed. The retained Apple workflows name a runner whose availability has not been checked.
- VLCKit is pinned to an alpha release. Rebuilding requires the external package and compatible Apple tooling. The specification includes design goals that are not established as completed features by the Linux tests.
- Enabled diagnostics can disclose media URLs and playback details. The mechanism has no collector authentication option and should only target an operator-controlled HTTPS endpoint with suitable access and retention controls.
- Wi-Fi transfer accepts unauthenticated plaintext uploads while enabled. Use a trusted local network. Media history and source URLs can contain private information at runtime.
- Signing and secret-upload helpers retain their operational behavior for explicit future use. Review them before supplying credentials or authorizing remote writes or device installation.
- Upstream notices are preserved. This preparation does not choose an application license or settle distribution obligations for linked third-party binaries.
- Automated patterns and manual review do not prove the absence of every possible secret or identifying detail. Owner review is still required before publication.
