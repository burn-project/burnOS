#!/usr/bin/env bash
# Append inherit-product for vendor/burn/burn.mk into panther / lynx device makefiles.
set -euo pipefail

SYNC_DIR="${1:?sync dir}"
MARKER='inherit-product, vendor/burn/burn.mk'

patch_mk() {
  local mk="$1"
  if [[ ! -f "$mk" ]]; then
    return 0
  fi
  if grep -qF "$MARKER" "$mk" 2>/dev/null; then
    echo "    already patched: $mk"
    return 0
  fi
  {
    echo ""
    echo "# burnOS vendor (Burn app, preinstalls, device owner provisioning)"
    echo "\$(call inherit-product, vendor/burn/burn.mk)"
  } >> "$mk"
  echo "    patched: $mk"
}

while IFS= read -r mk; do
  patch_mk "$mk"
done < <(
  find "$SYNC_DIR/vendor/google_devices" -type f \( -name 'panther.mk' -o -name 'lynx.mk' \) 2>/dev/null
  find "$SYNC_DIR/device/google" -type f \( -name 'device-panther.mk' -o -name 'device-lynx.mk' -o -name 'aosp_panther.mk' -o -name 'aosp_lynx.mk' \) 2>/dev/null
)
