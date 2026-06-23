#!/usr/bin/env bash
# Prepare a Windows flash bundle: renamed factory images + image zip for flash-all.bat
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="${SYNC_DIR:-$HOME/burnOS-src}"
DEST="${1:-/mnt/c/Users/Mr. Rico/Downloads/burnOS-panther}"
SRC="$SYNC_DIR/out/target/product/panther"
TARGET_FILES="$SRC/obj/PACKAGING/target_files_intermediates/panther-target_files.zip"
HOST="$SYNC_DIR/out/host/linux-x86"
IMG_TOOL="$SYNC_DIR/build/make/tools/releasetools/img_from_target_files.py"

BUILD="$(tr -d '\r\n' < "$SRC/build_fingerprint-panther.txt" | awk -F/ '{print $5}' | cut -d: -f1)"
BOOTLOADER_VER="$(grep '^require version-bootloader=' "$SRC/android-info.txt" | cut -d= -f2 | tr -d '\r')"
RADIO_VER="$(grep '^require version-baseband=' "$SRC/android-info.txt" | cut -d= -f2 | tr -d '\r')"

BOOTLOADER_IMG="bootloader-panther-${BOOTLOADER_VER}.img"
RADIO_IMG="radio-panther-${RADIO_VER}.img"
IMAGE_ZIP="image-panther-${BUILD}.zip"

mkdir -p "$DEST"

echo "==> burnOS flash bundle -> $DEST"
echo "    build: $BUILD"

cp -v "$SRC/bootloader.img" "$DEST/$BOOTLOADER_IMG"
cp -v "$SRC/radio.img" "$DEST/$RADIO_IMG"

if [[ ! -f "$DEST/$IMAGE_ZIP" ]]; then
  echo "==> Generating $IMAGE_ZIP — may take several minutes"
  python3 "$IMG_TOOL" -p "$HOST" "$TARGET_FILES" "$DEST/$IMAGE_ZIP"
else
  echo "    keep existing $IMAGE_ZIP"
fi

if command -v unzip >/dev/null 2>&1; then
  unzip -qo "$TARGET_FILES" "VENDOR/firmware/dauntless/*" -d "$DEST/.tf-extract" || true
  if [[ -d "$DEST/.tf-extract/VENDOR/firmware/dauntless" ]]; then
    cp -rv "$DEST/.tf-extract/VENDOR/firmware/dauntless/"* "$DEST"/
    rm -rf "$DEST/.tf-extract"
  fi
fi

cp -v "$SCRIPT_DIR/../flash-all.bat" "$DEST"/

# Keep BUILD id in the bat copy (portable bundle uses fixed names above)
sed -i "s/set BUILD=.*/set BUILD=$BUILD/" "$DEST/flash-all.bat"
sed -i "s/set BOOTLOADER=.*/set BOOTLOADER=$BOOTLOADER_IMG/" "$DEST/flash-all.bat"
sed -i "s/set RADIO=.*/set RADIO=$RADIO_IMG/" "$DEST/flash-all.bat"

echo "==> Done"
ls -lh "$DEST/$BOOTLOADER_IMG" "$DEST/$RADIO_IMG" "$DEST/$IMAGE_ZIP" "$DEST/flash-all.bat"
