#!/usr/bin/env bash
# Apply burnOS UI/menu overlays to a synced source tree.
# Run after repo sync: bash burn/apply-overlays.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="${SYNC_DIR:-$HOME/burnOS-src}"
STRIP_TOOL="$SCRIPT_DIR/tools/strip_preference_keys.py"
BURN_APK_SRC="${BURN_APK_SRC:-$SCRIPT_DIR/prebuilt/Burn.apk}"  # optional override

if [[ ! -d "$SYNC_DIR/.repo" ]]; then
  echo "ERROR: Not a repo sync tree: $SYNC_DIR"
  echo "       Wait for repo sync, or set SYNC_DIR=/path/to/burnOS-src"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 required for menu stripping"
  exit 1
fi

read_keys() {
  local file="$1"
  grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' || true
}

strip_from_file() {
  local xml="$1"
  local keys_file="$2"
  if [[ ! -f "$xml" ]]; then
    echo "    skip: $xml not synced yet"
    return 0
  fi
  mapfile -t keys < <(read_keys "$keys_file")
  if [[ ${#keys[@]} -eq 0 ]]; then
    return 0
  fi
  python3 "$STRIP_TOOL" "$xml" "${keys[@]}"
}

echo "==> burnOS apply-overlays"
echo "    sync dir: $SYNC_DIR"

# --- vendor/burn (Burn APK, priv-app, device owner provision) ---
echo "==> vendor/burn"
mkdir -p "$SYNC_DIR/vendor/burn"
rsync -a --delete \
  --exclude 'prebuilt/*.apk' \
  "$SCRIPT_DIR/vendor/" "$SYNC_DIR/vendor/burn/"

mkdir -p "$SYNC_DIR/vendor/burn/prebuilt"
for apk in Burn FDroid ThreemaLibre Zerion WireGuard; do
  src="$SCRIPT_DIR/prebuilt/${apk}.apk"
  if [[ -f "$src" ]]; then
    cp "$src" "$SYNC_DIR/vendor/burn/prebuilt/${apk}.apk"
    echo "    ${apk}.apk installed ($(du -h "$SYNC_DIR/vendor/burn/prebuilt/${apk}.apk" | awk '{print $1}'))"
  else
    echo "    WARN: missing $src"
  fi
done

bash "$SCRIPT_DIR/tools/patch-device-mk.sh" "$SYNC_DIR"
bash "$SCRIPT_DIR/tools/apply-launcher-icons.sh" "$SYNC_DIR"

if [[ -d "$SYNC_DIR/packages/apps/CarrierConfig" ]] || [[ -d "$SYNC_DIR/packages/apps/CarrierConfig2" ]]; then
  bash "$SCRIPT_DIR/tools/apply-carrier-config.sh" "$SYNC_DIR"
else
  echo "==> CarrierConfig not synced yet — skipping operator name"
fi

SETTINGS_DIR="$SYNC_DIR/packages/apps/Settings"
LAUNCHER_DIR="$SYNC_DIR/packages/apps/Launcher3"
FRAMEWORKS_RES="$SYNC_DIR/frameworks/base/core/res/res"

if [[ -d "$SETTINGS_DIR" ]]; then
  echo "==> Settings overlays"
  cp "$SCRIPT_DIR/overlays/settings/res/values/burn_config.xml" \
    "$SETTINGS_DIR/res/values/burn_config.xml"
  cp "$SCRIPT_DIR/overlays/settings/res/values/burn_about_strings.xml" \
    "$SETTINGS_DIR/res/values/burn_about_strings.xml"
  mkdir -p "$SETTINGS_DIR/res/layout" "$SETTINGS_DIR/res/xml" "$SETTINGS_DIR/res/drawable-nodpi"
  cp "$SCRIPT_DIR/overlays/settings/res/layout/burn_about_disclaimer.xml" \
    "$SETTINGS_DIR/res/layout/burn_about_disclaimer.xml"
  cp "$SCRIPT_DIR/overlays/settings/res/layout/burn_about_header.xml" \
    "$SETTINGS_DIR/res/layout/burn_about_header.xml"
  cp "$SCRIPT_DIR/overlays/settings/res/layout/burn_legal_header.xml" \
    "$SETTINGS_DIR/res/layout/burn_legal_header.xml"
  cp "$SCRIPT_DIR/overlays/settings/res/drawable-nodpi/"*.png \
    "$SETTINGS_DIR/res/drawable-nodpi/"
  cp "$SCRIPT_DIR/overlays/settings/res/xml/burn_about_use_liability.xml" \
    "$SETTINGS_DIR/res/xml/burn_about_use_liability.xml"
  mkdir -p "$SETTINGS_DIR/src/com/android/settings/deviceinfo/aboutphone"
  cp "$SCRIPT_DIR/overlays/settings/src/com/android/settings/deviceinfo/aboutphone/BurnUseLiabilityFragment.java" \
    "$SETTINGS_DIR/src/com/android/settings/deviceinfo/aboutphone/BurnUseLiabilityFragment.java"
  python3 "$SCRIPT_DIR/tools/patch-about-disclaimer.py" "$SYNC_DIR"
  strip_from_file "$SETTINGS_DIR/res/xml/top_level_settings.xml" \
    "$SCRIPT_DIR/overlays/settings/remove_top_level_keys.txt"
  strip_from_file "$SETTINGS_DIR/res/xml/location_services.xml" \
    "$SCRIPT_DIR/overlays/settings/remove_location_service_keys.txt"
else
  echo "==> Settings not synced yet — skipping"
fi

if [[ -d "$LAUNCHER_DIR" ]]; then
  echo "==> Launcher3 overlays"
  for ws_file in default_workspace_5x5.xml default_workspace_6x5.xml; do
    cp "$SCRIPT_DIR/overlays/launcher3/res/xml/$ws_file" \
      "$LAUNCHER_DIR/res/xml/$ws_file"
    echo "    updated $ws_file"
  done
else
  echo "==> Launcher3 not synced yet — skipping"
fi

if [[ -d "$FRAMEWORKS_RES" ]]; then
  echo "==> Wallpaper (home + lock) — BURN PRIVACY"
  mkdir -p "$FRAMEWORKS_RES/drawable-nodpi" "$FRAMEWORKS_RES/values"
  cp "$SCRIPT_DIR/branding/wallpaper/default_wallpaper.png" \
    "$FRAMEWORKS_RES/drawable-nodpi/default_wallpaper.png"
  cp "$SCRIPT_DIR/branding/wallpaper/default_lock_wallpaper.png" \
    "$FRAMEWORKS_RES/drawable-nodpi/default_lock_wallpaper.png"
  cp "$SCRIPT_DIR/overlays/frameworks-base/res/values/burn_wallpaper.xml" \
    "$FRAMEWORKS_RES/values/burn_wallpaper.xml"
  cp "$SCRIPT_DIR/overlays/frameworks-base/res/values/burn_system_defaults.xml" \
    "$FRAMEWORKS_RES/values/burn_system_defaults.xml"
  cp "$SCRIPT_DIR/overlays/frameworks-base/res/values/burn_carrier_privacy.xml" \
    "$FRAMEWORKS_RES/values/burn_carrier_privacy.xml"
  echo "    dark mode default (config_defaultNightMode=2)"
  echo "    carrier privacy overlay (empty preinstalled carrier app list)"
else
  echo "==> frameworks/base not synced yet — skipping wallpaper"
fi

POLICY_JAVA="$SYNC_DIR/frameworks/base/services/core/java/com/android/server/pm/permission/DefaultPermissionGrantPolicy.java"
if [[ -f "$POLICY_JAVA" ]] || [[ -f "$SYNC_DIR/frameworks/base/services/core/java/com/android/server/pm/DefaultPermissionGrantPolicy.java" ]]; then
  echo "==> Carrier permission grant patch"
  python3 "$SCRIPT_DIR/tools/patch-carrier-permission-grants.py" "$SYNC_DIR"
else
  echo "==> DefaultPermissionGrantPolicy not synced yet — skipping carrier grant patch"
fi

FRAMEWORK_DEFAULTS="$SYNC_DIR/frameworks/base/packages/SettingsProvider/res/values/defaults.xml"
if [[ -f "$FRAMEWORK_DEFAULTS" ]]; then
  if grep -q 'def_wifi_scan_always_available">0<' "$FRAMEWORK_DEFAULTS"; then
    echo "==> Wi-Fi scan default already off (GrapheneOS baseline)"
  else
    echo "WARN: def_wifi_scan_always_available is not 0 — review $FRAMEWORK_DEFAULTS"
  fi
fi

echo ""
echo "==> Overlay pass complete."
echo "    Re-run after sync finishes if any components were skipped."
