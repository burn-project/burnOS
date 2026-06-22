#!/usr/bin/env bash
# Resume adevtool generate-all after factory images are cached (WSL).
set -euo pipefail

SYNC_DIR="${SYNC_DIR:-/root/burnOS-src}"
DEVICE="${DEVICE:-panther}"
LOG="${LOG:-/root/burnOS-logs/build-panther.log}"

PATHS_TS="$SYNC_DIR/vendor/adevtool/src/config/paths.ts"
if [[ -f "$PATHS_TS" ]] && ! grep -q 'nsjail error' "$PATHS_TS"; then
  echo "==> patching adevtool for WSL nsjail stderr" | tee -a "$LOG"
  sed -i "s/return line.endsWith('setpriority(5): Permission denied')/return line.endsWith('setpriority(5): Permission denied') || line.includes('Build sandboxing disabled due to nsjail error')/" "$PATHS_TS"
fi

echo "==> resuming adevtool generate-all -d $DEVICE $(date)" | tee -a "$LOG"
su - build -s /bin/bash -c "cd '$SYNC_DIR' && set +u && source build/envsetup.sh && set -u && vendor/adevtool/bin/run generate-all -d '$DEVICE'" 2>&1 | tee -a "$LOG"
