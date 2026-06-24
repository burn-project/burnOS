#!/usr/bin/env bash
# Prepare a Windows flash bundle: signed factory images + avb_pkmd.bin for flash-all.bat
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="${SYNC_DIR:-$HOME/burnOS-src}"
if [[ ! -d "$SYNC_DIR/.repo" && -d /root/burnOS-src/.repo ]]; then
  SYNC_DIR=/root/burnOS-src
fi
DEST="${1:-/mnt/c/Users/Mr. Rico/Downloads/burnOS-panther}"
DEVICE="${DEVICE:-panther}"
KEYS_DIR="${KEYS_DIR:-$SCRIPT_DIR/../keys/$DEVICE}"
SRC="$SYNC_DIR/out/target/product/$DEVICE"
HOST="$SYNC_DIR/out/host/linux-x86"
IMG_TOOL="$SYNC_DIR/build/make/tools/releasetools/img_from_target_files.py"

BUILD="$(tr -d '\r\n' < "$SRC/build_fingerprint-${DEVICE}.txt" | awk -F/ '{print $5}' | cut -d: -f1)"
BOOTLOADER_VER="$(grep '^require version-bootloader=' "$SRC/android-info.txt" | cut -d= -f2 | tr -d '\r')"
RADIO_VER="$(grep '^require version-baseband=' "$SRC/android-info.txt" | cut -d= -f2 | tr -d '\r')"

BOOTLOADER_IMG="bootloader-panther-${BOOTLOADER_VER}.img"
RADIO_IMG="radio-panther-${RADIO_VER}.img"
IMAGE_ZIP="image-panther-${BUILD}.zip"

SIGNED_IMG="$SYNC_DIR/releases/$BUILD/release-${DEVICE}-$BUILD/${DEVICE}-img-${BUILD}.zip"
TARGET_FILES="$SRC/obj/PACKAGING/target_files_intermediates/panther-target_files.zip"

mkdir -p "$DEST"

echo "==> burnOS flash bundle -> $DEST"
echo "    build: $BUILD"

cp -v "$SRC/bootloader.img" "$DEST/$BOOTLOADER_IMG"
cp -v "$SRC/radio.img" "$DEST/$RADIO_IMG"

if [[ -f "$SIGNED_IMG" ]]; then
  echo "==> Using signed image zip"
  cp -v "$SIGNED_IMG" "$DEST/$IMAGE_ZIP"
elif [[ -f "$DEST/$IMAGE_ZIP" && "${FORCE_IMAGE:-0}" != 1 ]]; then
  echo "    keep existing unsigned $IMAGE_ZIP"
  echo "    WARN: run sign-release.sh for a lockable build"
else
  echo "==> Generating unsigned $IMAGE_ZIP — may take several minutes"
  echo "    WARN: bootloader lock requires sign-release.sh first"
  python3 "$IMG_TOOL" -p "$HOST" "$TARGET_FILES" "$DEST/$IMAGE_ZIP"
fi

if [[ -f "$KEYS_DIR/avb_pkmd.bin" ]]; then
  cp -v "$KEYS_DIR/avb_pkmd.bin" "$DEST/"
elif [[ -f "$SYNC_DIR/keys/$DEVICE/avb_pkmd.bin" ]]; then
  cp -v "$SYNC_DIR/keys/$DEVICE/avb_pkmd.bin" "$DEST/"
else
  echo "    WARN: missing avb_pkmd.bin — bootloader lock will fail"
fi

if command -v unzip >/dev/null 2>&1; then
  unzip -qo "$TARGET_FILES" "VENDOR/firmware/dauntless/*" -d "$DEST/.tf-extract" 2>/dev/null || true
  if [[ -d "$DEST/.tf-extract/VENDOR/firmware/dauntless" ]]; then
    cp -rv "$DEST/.tf-extract/VENDOR/firmware/dauntless/"* "$DEST"/
    rm -rf "$DEST/.tf-extract"
  fi
fi

cp -v "$SCRIPT_DIR/../flash-all.bat" "$DEST"/

sed -i "s/set BUILD=.*/set BUILD=$BUILD/" "$DEST/flash-all.bat"
sed -i "s/set BOOTLOADER=.*/set BOOTLOADER=$BOOTLOADER_IMG/" "$DEST/flash-all.bat"
sed -i "s/set RADIO=.*/set RADIO=$RADIO_IMG/" "$DEST/flash-all.bat"

echo "==> Done"
ls -lh "$DEST/$BOOTLOADER_IMG" "$DEST/$RADIO_IMG" "$DEST/$IMAGE_ZIP" "$DEST/avb_pkmd.bin" "$DEST/flash-all.bat" 2>/dev/null || \
  ls -lh "$DEST/$BOOTLOADER_IMG" "$DEST/$RADIO_IMG" "$DEST/$IMAGE_ZIP" "$DEST/flash-all.bat"
