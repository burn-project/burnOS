#!/usr/bin/env bash
# Compile, sign with release keys, and prepare Downloads flash bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="${SYNC_DIR:-$HOME/burnOS-src}"
if [[ ! -d "$SYNC_DIR/.repo" && -d /root/burnOS-src/.repo ]]; then
  SYNC_DIR=/root/burnOS-src
fi
DEVICE="${DEVICE:-panther}"
JOBS="${JOBS:-6}"
LOG_DIR="${LOG_DIR:-/root/burnOS-logs}"
LOG="$LOG_DIR/rebuild-signed-$(date +%Y%m%d-%H%M).log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1

echo "==> burnOS rebuild-signed started $(date)"
echo "    device: $DEVICE"
echo "    sync:   $SYNC_DIR"
echo "    log:    $LOG"

if [[ "$(id -un)" != build ]]; then
  echo "ERROR: run as build user, e.g.: wsl -d Ubuntu -u build bash burn/rebuild-signed.sh"
  exit 1
fi

cd "$SYNC_DIR"
rm -f out/.lock
export OFFICIAL_BUILD=true
export USE_CCACHE=1
command -v ccache >/dev/null && ccache -M 50G 2>/dev/null || true
set +u
source build/envsetup.sh
lunch "${DEVICE}-cur-user" >/dev/null
set -u
m productimage systemimage systemextimage target-files-package -j"$JOBS" || \
m productimage systemimage systemextimage target-files-package -j"$JOBS"

BUILD="$(tr -d '\r\n' < "$SYNC_DIR/out/target/product/$DEVICE/build_fingerprint-${DEVICE}.txt" | awk -F/ '{print $5}' | cut -d: -f1)"
echo "==> compile finished build=$BUILD $(date)"

SYNC_DIR="$SYNC_DIR" bash "$SCRIPT_DIR/sign-release.sh" "$DEVICE" "$BUILD"
SYNC_DIR="$SYNC_DIR" bash "$SCRIPT_DIR/generate-flash-bundle.sh"

echo ""
echo "==> burnOS rebuild-signed finished $(date)"
echo "    flash bundle: /mnt/c/Users/Mr. Rico/Downloads/burnOS-panther/"
echo "    signed image: $SYNC_DIR/releases/$BUILD/release-${DEVICE}-$BUILD/${DEVICE}-img-$BUILD.zip"
echo "    log: $LOG"
