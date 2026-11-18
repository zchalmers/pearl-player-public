#!/usr/bin/env bash
# One-time: put your own signing material into your repository's secrets.
# This updates GitHub secrets only when you explicitly run the script.
# Set REPO, SIGN_IDENTITY and P12_PASSWORD before running it.
# Usage: bash scripts/set-signing-secrets.sh
set -euo pipefail

KIT="${IOS_DEV_KIT:-$HOME/ios-dev}"
REPO="${REPO:?Set REPO to your own owner/repository}"

CERT="$KIT/certs/Development.p12"
PROFILE="$KIT/profiles/Development.mobileprovision"
IDENTITY="${SIGN_IDENTITY:?Set SIGN_IDENTITY to your own signing identity}"
P12_PASSWORD="${P12_PASSWORD:?Set P12_PASSWORD to your certificate password}"

for file in "$CERT" "$PROFILE"; do
  [[ -f "$file" ]] || { echo "missing $file" >&2; exit 1; }
done

base64 -w0 "$CERT" > /tmp/pearl-dev-p12.b64
base64 -w0 "$PROFILE" > /tmp/pearl-dev-profile.b64

gh secret set P12_BASE64 --repo "$REPO" < /tmp/pearl-dev-p12.b64
gh secret set P12_PASSWORD --repo "$REPO" --body "$P12_PASSWORD"
gh secret set PROFILE_BASE64 --repo "$REPO" < /tmp/pearl-dev-profile.b64
gh secret set SIGN_IDENTITY --repo "$REPO" --body "$IDENTITY"

rm -f /tmp/pearl-dev-p12.b64 /tmp/pearl-dev-profile.b64
echo "secrets set on $REPO:"
gh secret list --repo "$REPO"
