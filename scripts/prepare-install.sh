#!/usr/bin/env bash
# Take the unsigned IPA that the macOS build produces, sign it here on Linux with
# your own certificate (zsign is a cross platform codesign
# alternative, so no Mac and no CI are involved), verify it, and put it somewhere
# the phone can reach.
#
# Usage:
#   scripts/prepare-install.sh                      # pull builds/ipa from origin
#   scripts/prepare-install.sh path/to/some.ipa     # sign a local file instead
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KIT="${IOS_DEV_KIT:-$HOME/ios-dev}"
CERT="$KIT/certs/Development.p12"
PROFILE="$KIT/profiles/Development.mobileprovision"
P12_PASSWORD="${P12_PASSWORD:?Set P12_PASSWORD to your certificate password}"
ZSIGN="${ZSIGN:-/tmp/zsign/bin/zsign}"
PUBLISH_DIR="${PUBLISH_DIR:-}"
export PEARL_BUNDLE_ID="${PEARL_BUNDLE_ID:-org.example.pearlplayer}"

cd "$REPO_DIR"
mkdir -p exports

if [[ $# -ge 1 ]]; then
  unsigned="$1"
else
  echo "==> fetching the builds/ipa branch"
  git fetch -q origin builds/ipa
  unsigned="exports/PearlPlayer-unsigned.ipa"
  git show origin/builds/ipa:exports/PearlPlayer-unsigned.ipa > "$unsigned"
fi

[[ -f "$unsigned" ]] || { echo "no unsigned IPA at $unsigned" >&2; exit 1; }
[[ -x "$ZSIGN" ]] || { echo "zsign is not built at $ZSIGN (build it in /tmp/zsign/build/linux)" >&2; exit 1; }

echo "==> unsigned IPA: $(du -h "$unsigned" | cut -f1)"

# Entitlements come out of the profile so the signature can never disagree with
# it, exactly as the macOS workflow did.
python3 - "$PROFILE" > /tmp/pearl-entitlements.plist <<'PY'
import plistlib, subprocess, sys
raw = subprocess.run(["openssl", "smime", "-inform", "der", "-verify", "-noverify",
                      "-in", sys.argv[1]], capture_output=True, check=True).stdout
plistlib.dump(plistlib.loads(raw)["Entitlements"], sys.stdout.buffer)
PY

echo "==> signing with $CERT"
"$ZSIGN" -k "$CERT" -p "$P12_PASSWORD" -m "$PROFILE" \
  -e /tmp/pearl-entitlements.plist \
  -o exports/PearlPlayer-signed.ipa \
  "$unsigned"

echo "==> verifying the package"
rm -rf /tmp/pearl-ipa-check && mkdir -p /tmp/pearl-ipa-check
unzip -q exports/PearlPlayer-signed.ipa -d /tmp/pearl-ipa-check
APP=/tmp/pearl-ipa-check/Payload/PearlPlayer.app
ls "$APP" | head -10
[[ -f "$APP/embedded.mobileprovision" ]] || { echo "embedded.mobileprovision is missing" >&2; exit 1; }
[[ -d "$APP/_CodeSignature" ]] || { echo "_CodeSignature is missing" >&2; exit 1; }
ls "$APP/Frameworks" 2>/dev/null || true
python3 - "$APP/Info.plist" <<'PY'
import os, plistlib, sys
plist = plistlib.load(open(sys.argv[1], "rb"))
schemes = [s for entry in plist.get("CFBundleURLTypes", []) for s in entry.get("CFBundleURLSchemes", [])]
print("bundle id:", plist.get("CFBundleIdentifier"))
print("schemes:", schemes)
print("executable:", plist.get("CFBundleExecutable"))
assert plist.get("CFBundleIdentifier") == os.environ["PEARL_BUNDLE_ID"]
for needed in ("outplayer", "vlc-x-callback", "pearl"):
    assert needed in schemes, f"missing scheme {needed}"
print("package checks passed")
PY

shasum -a 256 exports/PearlPlayer-signed.ipa

# Optionally copy to a directory you manage. No upload or hosting is performed.
if [[ -n "$PUBLISH_DIR" ]]; then
  mkdir -p "$PUBLISH_DIR"
  cp exports/PearlPlayer-signed.ipa "$PUBLISH_DIR/PearlPlayer.ipa"
  echo "copied: $PUBLISH_DIR/PearlPlayer.ipa"
fi
echo
echo "install over USB from this machine:"
echo "  scripts/install-on-device.sh exports/PearlPlayer-signed.ipa"
