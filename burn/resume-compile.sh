#!/usr/bin/env bash
# Resume ROM compile after adevtool + overlays (WSL).
set -euo pipefail

SYNC_DIR="${SYNC_DIR:-/root/burnOS-src}"
BURN_DIR="${BURN_DIR:-/mnt/c/adb/burnOS/burn}"
LOG="${LOG:-/root/burnOS-logs/build-panther.log}"
DEVICE="${DEVICE:-panther}"
JOBS="${JOBS:-6}"

echo "==> resuming compile only $(date)" | tee -a "$LOG"

su - build -s /bin/bash -c "
  set +u
  set -eo pipefail
  cd '$SYNC_DIR'
  source build/envsetup.sh
  export OFFICIAL_BUILD=true USE_CCACHE=1
  command -v ccache >/dev/null && ccache -M 50G 2>/dev/null || true
  lunch \"${DEVICE}-cur-user\"
  m productimage systemimage systemextimage target-files-package -j\"${JOBS}\"
" 2>&1 | tee -a "$LOG"

echo "==> compile finished $(date)" | tee -a "$LOG"
