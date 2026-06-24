#!/usr/bin/env bash
# Fast path: skip productimage if already built; max jobs; sign + bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="${SYNC_DIR:-$HOME/burnOS-src}"
if [[ ! -d "$SYNC_DIR/.repo" && -d /root/burnOS-src/.repo ]]; then
  SYNC_DIR=/root/burnOS-src
fi
DEVICE="${DEVICE:-panther}"
JOBS="${JOBS:-$(nproc)}"
LOG_DIR="${LOG_DIR:-/root/burnOS-logs}"
LOG="$LOG_DIR/rebuild-fast-$(date +%Y%m%d-%H%M).log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1

echo "==> burnOS rebuild-fast started $(date)"
echo "    device: $DEVICE  jobs: $JOBS"
echo "    log: $LOG"

if [[ "$(id -un)" != build ]]; then
  echo "ERROR: run as build user"
  exit 1
fi

cd "$SYNC_DIR"
rm -f out/.lock
export OFFICIAL_BUILD=true USE_CCACHE=1
command -v ccache >/dev/null && ccache -M 50G 2>/dev/null || true
set +u
source build/envsetup.sh
lunch "${DEVICE}-cur-user" >/dev/null
set -u

# product.img already rebuilt; system + target-files only
m systemimage systemextimage target-files-package -j"$JOBS" || \
m systemimage systemextimage target-files-package -j"$JOBS"

BUILD="$(tr -d '\r\n' < "$SYNC_DIR/out/target/product/$DEVICE/build_fingerprint-${DEVICE}.txt" | awk -F/ '{print $5}' | cut -d: -f1)"
echo "==> compile finished build=$BUILD $(date)"

SYNC_DIR="$SYNC_DIR" bash "$SCRIPT_DIR/sign-release.sh" "$DEVICE" "$BUILD"
SYNC_DIR="$SYNC_DIR" bash "$SCRIPT_DIR/generate-flash-bundle.sh"

echo "==> DONE $(date) -> /mnt/c/Users/Mr. Rico/Downloads/burnOS-panther/"
