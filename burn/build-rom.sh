#!/usr/bin/env bash
# burnOS ROM build — panther (Pixel 7). Run inside Ubuntu WSL.
# Usage: build-rom.sh [--fast]   (--fast skips repo sync when tree is already current)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="${SYNC_DIR:-$HOME/burnOS-src}"
BURN_DIR="${BURN_DIR:-$SCRIPT_DIR}"
LOG_DIR="${LOG_DIR:-$HOME/burnOS-logs}"
DEVICE="${DEVICE:-panther}"
JOBS="${JOBS:-10}"
FAST="${FAST:-0}"
LOG="$LOG_DIR/build-${DEVICE}.log"

for arg in "$@"; do
  case "$arg" in
    --fast) FAST=1 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--fast]"
      echo "  --fast  Skip repo sync (use when source tree is already synced)"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1

echo "==> burnOS build started $(date)"
echo "    device: $DEVICE"
echo "    sync:   $SYNC_DIR"
echo "    fast:   $([[ "$FAST" == 1 ]] && echo yes || echo no)"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# Node 24+ required by adevtool
NODE_MAJOR=0
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -v | sed 's/^v//' | cut -d. -f1)"
fi
if [[ "$NODE_MAJOR" -lt 24 ]]; then
  apt-get remove -y nodejs yarnpkg cmdtest 2>/dev/null || true
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  apt-get install -y -qq nodejs
fi
# Ubuntu's cmdtest/yarnpkg provides a fake `yarn` without --cwd; adevtool needs Node yarn.
apt-get remove -y yarnpkg cmdtest 2>/dev/null || true
hash -r
if ! yarn --version 2>/dev/null | grep -qE '^[0-9]'; then
  npm install -g yarn
fi

if ! id build >/dev/null 2>&1; then
  useradd -m -s /bin/bash build
fi
chmod 711 /root
if [[ "$FAST" != 1 ]]; then
  chown -R build:build "$SYNC_DIR" "$LOG_DIR"
else
  chown -R build:build "$SYNC_DIR" "$LOG_DIR"
fi

cd "$SYNC_DIR"
git config --global --add safe.directory "$SYNC_DIR"
git config --global --add safe.directory '*'
su - build -c "git config --global --add safe.directory '*' && git config --global --add safe.directory '$SYNC_DIR'"
if [[ "$FAST" == 1 ]]; then
  echo "==> --fast: skipping repo sync"
else
  echo "==> repo sync as root (fix checkout errors)"
  repo sync -j"$JOBS" -c --no-tags --no-clone-bundle --optimized-fetch
fi

INNER_SCRIPT="$LOG_DIR/burn-build-inner.sh"

cat > "$INNER_SCRIPT" <<'INNER'
#!/usr/bin/env bash
set -euo pipefail
SYNC_DIR="${SYNC_DIR:?}"
BURN_DIR="${BURN_DIR:?}"
DEVICE="${DEVICE:?}"
JOBS="${JOBS:?}"

cd "$SYNC_DIR"

echo "==> adevtool yarn install"
( cd vendor/adevtool && yarn install --silent )

# Stale partial factory downloads cause HTTP 416 on resume
shopt -s nullglob
for tmp in vendor/adevtool/dl/*.zip.tmp; do
  complete="${tmp%.tmp}"
  if [[ ! -f "$complete" ]]; then
    echo "==> removing incomplete factory download: $(basename "$tmp")"
    rm -f "$tmp"
  fi
done

# WSL: Android build prints nsjail sandbox warning to stderr; adevtool treats it as fatal
PATHS_TS="vendor/adevtool/src/config/paths.ts"
if [[ -f "$PATHS_TS" ]] && ! grep -q 'nsjail error' "$PATHS_TS"; then
  echo "==> patching adevtool for WSL nsjail stderr"
  sed -i "s/return line.endsWith('setpriority(5): Permission denied')/return line.endsWith('setpriority(5): Permission denied') || line.includes('Build sandboxing disabled due to nsjail error')/" "$PATHS_TS"
fi

echo "==> adevtool generate-all -d $DEVICE"
set +u
source build/envsetup.sh
set -u
vendor/adevtool/bin/run generate-all -d "$DEVICE"

echo "==> apply burnOS overlays"
SYNC_DIR="$SYNC_DIR" bash "$BURN_DIR/apply-overlays.sh"

echo "==> lunch + compile"
export OFFICIAL_BUILD=true
export USE_CCACHE=1
command -v ccache >/dev/null && ccache -M 50G 2>/dev/null || true
lunch "${DEVICE}-cur-user"
m productimage systemimage systemextimage target-files-package -j"$JOBS"
INNER

chmod +x "$INNER_SCRIPT"
chown build:build "$INNER_SCRIPT"

echo "==> node $(node -v)"
echo "==> running build as user: build"
su - build -s /bin/bash -c "SYNC_DIR='$SYNC_DIR' BURN_DIR='$BURN_DIR' DEVICE='$DEVICE' JOBS='$JOBS' bash '$INNER_SCRIPT'"

echo ""
echo "==> burnOS build finished $(date)"
echo "    log: $LOG"
echo "    images: $SYNC_DIR/out/target/product/$DEVICE/"
