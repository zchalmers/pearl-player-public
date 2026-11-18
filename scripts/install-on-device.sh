#!/usr/bin/env bash
# Install a signed PearlPlayer.ipa on your iOS device over USB, from
# Linux. No Mac needed.
#
# Usage:  scripts/install-on-device.sh path/to/PearlPlayer.ipa
#
# Before it can work:
#   1. The phone is plugged into your Linux host with a data cable.
#   2. On the phone: Settings, Privacy and Security, Developer Mode, on (the
#      phone reboots once). This must be enabled for a development signed app.
#   3. On the phone: tap Trust on the "Trust This Computer" prompt.
#   4. usbmuxd is running here.
#
# pymobiledevice3 comes from `uv tool install pymobiledevice3`.
set -euo pipefail

IPA="${1:-}"
UDID="${UDID:?Set UDID to your own device identifier}"

if [[ -z "$IPA" || ! -f "$IPA" ]]; then
  echo "usage: $0 path/to/PearlPlayer.ipa" >&2
  exit 1
fi

export PATH="$HOME/.local/bin:$(brew --prefix 2>/dev/null)/bin:$PATH"

if ! command -v pymobiledevice3 >/dev/null 2>&1; then
  echo "pymobiledevice3 is missing. Install it with: uv tool install pymobiledevice3" >&2
  exit 1
fi

echo "==> usbmuxd"
if ! systemctl is-active --quiet usbmuxd; then
  echo "usbmuxd is not running. Starting it needs sudo."
  sudo systemctl start usbmuxd || true
fi

echo "==> devices seen by usbmuxd"
pymobiledevice3 usbmux list || true

echo "==> reaching the device"
pymobiledevice3 lockdown info --udid "$UDID" >/dev/null

echo "==> mounting the developer disk image (needed to install)"
pymobiledevice3 mounter auto-mount --udid "$UDID" || true

echo "==> installing $(basename "$IPA")"
pymobiledevice3 apps install "$IPA" --udid "$UDID"

echo "==> installed apps matching pearl"
pymobiledevice3 apps list --udid "$UDID" 2>/dev/null | grep -i -A2 pearl || true

echo "done"
