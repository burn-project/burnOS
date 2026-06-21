#!/usr/bin/env bash
# burnOS — apply burn logo launcher icons to Settings, Launcher3, and Burn app RRO.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="${1:?sync dir}"
ICONS="$SCRIPT_DIR/../branding/icons"

if [[ ! -d "$ICONS/mipmap-mdpi" ]]; then
  python3 "$SCRIPT_DIR/generate-launcher-icons.py"
fi

SETTINGS_DIR="$SYNC_DIR/packages/apps/Settings"
LAUNCHER_DIR="$SYNC_DIR/packages/apps/Launcher3"
RRO_RES="$SYNC_DIR/vendor/burn/overlay/BurnIconOverlay/res"

copy_icons() {
  local src_dir="$1"
  local dst_dir="$2"
  local name="$3"
  mkdir -p "$dst_dir"
  cp "$src_dir/$name" "$dst_dir/"
}

if [[ -d "$SETTINGS_DIR" ]]; then
  echo "==> Settings launcher icon"
  for dens in mipmap-mdpi mipmap-hdpi mipmap-xhdpi mipmap-xxhdpi mipmap-xxxhdpi; do
    mkdir -p "$SETTINGS_DIR/res/$dens"
    cp "$ICONS/$dens/ic_launcher_settings.png" "$SETTINGS_DIR/res/$dens/ic_launcher_settings.png"
  done
  cp "$SCRIPT_DIR/../overlays/settings/res/values/ic_launcher_background.xml" \
    "$SETTINGS_DIR/res/values/ic_launcher_background.xml"
  cp "$SCRIPT_DIR/../overlays/settings/res/drawable/ic_launcher_foreground.xml" \
    "$SETTINGS_DIR/res/drawable/ic_launcher_foreground.xml"
  echo "    ic_launcher_settings + adaptive foreground"
else
  echo "==> Settings not synced — skipping launcher icon"
fi

if [[ -d "$LAUNCHER_DIR" ]]; then
  echo "==> Launcher3 icon"
  for dens in mipmap-mdpi mipmap-hdpi mipmap-xhdpi mipmap-xxhdpi; do
    mkdir -p "$LAUNCHER_DIR/res/$dens"
    cp "$ICONS/$dens/ic_launcher_home_foreground.png" \
      "$LAUNCHER_DIR/res/$dens/ic_launcher_home_foreground.png"
  done
  echo "    ic_launcher_home_foreground"
else
  echo "==> Launcher3 not synced — skipping launcher icon"
fi

if [[ -d "$SYNC_DIR/vendor/burn/overlay/BurnIconOverlay" ]]; then
  echo "==> Burn app icon overlay (RRO)"
  for dens in mipmap-mdpi mipmap-hdpi mipmap-xhdpi mipmap-xxhdpi mipmap-xxxhdpi; do
    mkdir -p "$RRO_RES/$dens"
    cp "$ICONS/$dens/ic_launcher.png" "$RRO_RES/$dens/ic_launcher.png"
    cp "$ICONS/$dens/ic_launcher_round.png" "$RRO_RES/$dens/ic_launcher_round.png"
  done
  for dens in drawable-mdpi drawable-hdpi drawable-xhdpi drawable-xxhdpi drawable-xxxhdpi; do
    mkdir -p "$RRO_RES/$dens"
    cp "$ICONS/$dens/ic_launcher_foreground.png" "$RRO_RES/$dens/ic_launcher_foreground.png"
  done
  mkdir -p "$RRO_RES/mipmap-anydpi-v26" "$RRO_RES/values"
  cp "$SCRIPT_DIR/../vendor/overlay/BurnIconOverlay/res/mipmap-anydpi-v26/"*.xml \
    "$RRO_RES/mipmap-anydpi-v26/"
  cp "$SCRIPT_DIR/../vendor/overlay/BurnIconOverlay/res/values/ic_launcher_background.xml" \
    "$RRO_RES/values/ic_launcher_background.xml"
  echo "    BurnIconOverlay resources"
fi
