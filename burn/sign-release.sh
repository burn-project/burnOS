#!/usr/bin/env bash
# Sign a completed target-files build with burnOS release keys → factory flash bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="${1:?device codename (panther|lynx)}"
BUILD_NUMBER="${2:-}"
SYNC_DIR="${SYNC_DIR:-$HOME/burnOS-src}"
if [[ ! -d "$SYNC_DIR/.repo" && -d /root/burnOS-src/.repo ]]; then
  SYNC_DIR=/root/burnOS-src
fi
JOBS="${JOBS:-6}"
KEYS_DIR="${KEYS_DIR:-$SCRIPT_DIR/../keys/$DEVICE}"

if [[ ! -d "$SYNC_DIR/.repo" ]]; then
  echo "ERROR: not a sync tree: $SYNC_DIR"
  exit 1
fi

if [[ ! -f "$KEYS_DIR/avb.pem" ]]; then
  echo "ERROR: no keys in $KEYS_DIR — run: bash burn/generate-keys.sh $DEVICE"
  exit 1
fi

TARGET_FILES="$SYNC_DIR/out/target/product/$DEVICE/obj/PACKAGING/target_files_intermediates/${DEVICE}-target_files.zip"
if [[ ! -f "$TARGET_FILES" ]]; then
  echo "ERROR: missing target-files: $TARGET_FILES"
  echo "       Run a full compile first (resume-compile.sh)."
  exit 1
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(tr -d '\r\n' < "$SYNC_DIR/out/target/product/$DEVICE/build_fingerprint-${DEVICE}.txt" | awk -F/ '{print $5}' | cut -d: -f1)"
fi

echo "==> burnOS sign-release"
echo "    device: $DEVICE"
echo "    build:  $BUILD_NUMBER"
echo "    keys:   $KEYS_DIR"

mkdir -p "$SYNC_DIR/keys/$DEVICE"
rsync -a "$KEYS_DIR/" "$SYNC_DIR/keys/$DEVICE/"

if [[ "$(id -un)" == build ]]; then
  RUNNER=(bash)
else
  RUNNER=(su build -s /bin/bash)
fi

"${RUNNER[@]}" <<EOF
set -eo pipefail
cd '$SYNC_DIR'
rm -f out/.lock
source build/envsetup.sh
lunch '${DEVICE}-cur-user' >/dev/null
export password=
export BUILD_NUMBER='$BUILD_NUMBER'
export TARGET_PRODUCT='$DEVICE'

OTATOOLS="out/host/linux-x86/obj/ETC/otatools-packagelinux_glibc_x86_64_intermediates/otatools-packagelinux_glibc_x86_64"
if [[ ! -f "\$OTATOOLS" ]]; then
  echo "==> building otatools-package (one-time, ~10-20 min)"
  m otatools-package -j$JOBS
fi

echo "==> finalize + generate-release"
script/finalize.sh
script/generate-release.sh '$DEVICE' '$BUILD_NUMBER'
EOF

RELEASE_DIR="$SYNC_DIR/releases/$BUILD_NUMBER/release-${DEVICE}-$BUILD_NUMBER"
echo ""
echo "==> Signed release ready:"
echo "    $RELEASE_DIR"
echo ""
echo "Next: bash burn/generate-flash-bundle.sh"
