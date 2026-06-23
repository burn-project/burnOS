#!/usr/bin/env bash
# Auto-advance burnOS build: wait for adevtool, then overlays + compile (WSL).
set -euo pipefail

SYNC_DIR="${SYNC_DIR:-/root/burnOS-src}"
BURN_DIR="${BURN_DIR:-/mnt/c/adb/burnOS/burn}"
LOG="${LOG:-/root/burnOS-logs/build-panther.log}"
DEVICE="${DEVICE:-panther}"
JOBS="${JOBS:-10}"

log() { echo "==> [watch] $* $(date)" | tee -a "$LOG"; }

log "pipeline watcher started"

vendor_ready() {
  [[ -d "$SYNC_DIR/vendor/$DEVICE" ]] || [[ -d "$SYNC_DIR/vendor/google_devices/$DEVICE" ]]
}

while pgrep -f 'adevtool/bin/run generate-all' >/dev/null 2>&1; do
  log "waiting for adevtool generate-all..."
  sleep 60
done

if ! vendor_ready; then
  log "vendor/$DEVICE missing — running resume-adevtool"
  bash "$BURN_DIR/resume-adevtool.sh"
fi

if ! vendor_ready; then
  log "ERROR: vendor tree for $DEVICE still missing after adevtool"
  exit 1
fi

log "adevtool complete — apply overlays + compile"
su - build -s /bin/bash -c "
  set +u
  set -eo pipefail
  cd '$SYNC_DIR'
  source build/envsetup.sh
  echo '==> apply burnOS overlays'
  SYNC_DIR='$SYNC_DIR' bash '$BURN_DIR/apply-overlays.sh'
  echo '==> lunch + compile'
  export OFFICIAL_BUILD=true USE_CCACHE=1
  command -v ccache >/dev/null && ccache -M 50G 2>/dev/null || true
  lunch \"${DEVICE}-cur-user\"
  m vendorbootimage vendorkernelbootimage target-files-package -j\"${JOBS}\"
" 2>&1 | tee -a "$LOG"

log "pipeline finished — images: $SYNC_DIR/out/target/product/$DEVICE/"
