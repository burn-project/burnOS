#!/usr/bin/env bash
# Append inherit-product for vendor/burn/burn.mk into panther / lynx device makefiles.
set -euo pipefail

SYNC_DIR="${1:?sync dir}"
MARKER='inherit-product, vendor/burn/burn.mk'

find "$SYNC_DIR/device/google" -type f \( -name 'device-panther.mk' -o -name 'device-lynx.mk' -o -name 'aosp_panther.mk' -o -name 'aosp_lynx.mk' \) 2>/dev/null | while read -r mk; do
  if grep -qF "$MARKER" "$mk" 2>/dev/null; then
    echo "    already patched: $mk"
    continue
  fi
  {
    echo ""
    echo "# burnOS vendor (Burn app, wallpaper, device owner provisioning)"
    echo "\$(call inherit-product, vendor/burn/burn.mk)"
  } >> "$mk"
  echo "    patched: $mk"
done
