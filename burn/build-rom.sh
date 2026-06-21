#!/usr/bin/env bash
# burnOS ROM build — panther (Pixel 7). Run inside Ubuntu WSL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_DIR="${SYNC_DIR:-/root/burnOS-src}"
BURN_DIR="${BURN_DIR:-$SCRIPT_DIR}"
LOG_DIR="${LOG_DIR:-/root/burnOS-logs}"
DEVICE="${DEVICE:-panther}"
JOBS="${JOBS:-10}"
LOG="$LOG_DIR/build-${DEVICE}.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1

echo "==> burnOS build started $(date)"
echo "    device: $DEVICE"
echo "    sync:   $SYNC_DIR"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# Node 24+ required by adevtool
NODE_MAJOR=0
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -v | sed 's/^v//' | cut -d. -f1)"
fi
if [[ "$NODE_MAJOR" -lt 24 ]]; then
  apt-get remove -y nodejs yarnpkg 2>/dev/null || true
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  apt-get install -y -qq nodejs
fi
command -v yarn >/dev/null 2>&1 || npm install -g yarn

if ! id build >/dev/null 2>&1; then
  useradd -m -s /bin/bash build
fi
chmod 711 /root
chown -R build:build "$SYNC_DIR" "$LOG_DIR"

cd "$SYNC_DIR"
git config --global --add safe.directory "$SYNC_DIR"
git config --global --add safe.directory '*'
echo "==> repo sync as root (fix checkout errors)"
repo sync -j"$JOBS" -c --no-tags --no-clone-bundle

cat > /tmp/burn-build-inner.sh <<'INNER'
#!/usr/bin/env bash
set -euo pipefail
SYNC_DIR="${SYNC_DIR:?}"
BURN_DIR="${BURN_DIR:?}"
DEVICE="${DEVICE:?}"
JOBS="${JOBS:?}"

cd "$SYNC_DIR"

echo "==> adevtool yarn install"
yarn install --cwd vendor/adevtool --silent

echo "==> adevtool generate-all -d $DEVICE"
source build/envsetup.sh
adevtool generate-all -d "$DEVICE"

echo "==> apply burnOS overlays"
SYNC_DIR="$SYNC_DIR" bash "$BURN_DIR/apply-overlays.sh"

echo "==> lunch + compile"
export OFFICIAL_BUILD=true
export USE_CCACHE=1
command -v ccache >/dev/null && ccache -M 50G 2>/dev/null || true
lunch "${DEVICE}-cur-user"
m vendorbootimage vendorkernelbootimage target-files-package -j"$JOBS"
INNER

chmod +x /tmp/burn-build-inner.sh
chown build:build /tmp/burn-build-inner.sh

echo "==> node $(node -v)"
echo "==> running build as user: build"
su - build -c "SYNC_DIR='$SYNC_DIR' BURN_DIR='$BURN_DIR' DEVICE='$DEVICE' JOBS='$JOBS' bash /tmp/burn-build-inner.sh"

echo ""
echo "==> burnOS build finished $(date)"
echo "    log: $LOG"
echo "    images: $SYNC_DIR/out/target/product/$DEVICE/"
