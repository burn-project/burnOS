#!/usr/bin/env bash
# burnOS WSL bootstrap — run inside Ubuntu 24.04 (WSL2) or compatible Debian/Ubuntu.
# Requires ~300 GiB free disk INSIDE the Linux filesystem (not /mnt/c).
# Usage: bootstrap-wsl.sh [--fast]   (--fast adds --optimized-fetch to repo sync)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BURNOS_MANIFEST="${BURNOS_MANIFEST:-$HOME/burnOS-src/.repo/manifests}"
SYNC_DIR="${SYNC_DIR:-$HOME/burnOS-src}"
BRANCH="${BRANCH:-16-qpr2}"
MANIFEST_URL="${MANIFEST_URL:-https://github.com/burn-project/burnOS.git}"
FAST="${FAST:-0}"

for arg in "$@"; do
  case "$arg" in
    --fast) FAST=1 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--fast]"
      echo "  --fast  Use --optimized-fetch for faster repo sync"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 1
      ;;
  esac
done

REPO_SYNC_FLAGS=(-j"$(nproc)" -c --no-tags --no-clone-bundle)
if [[ "$FAST" == 1 ]]; then
  REPO_SYNC_FLAGS+=(--optimized-fetch)
fi

echo "==> burnOS bootstrap"
echo "    sync dir: $SYNC_DIR"
echo "    branch:   $BRANCH"

if [[ $(df -BG "$HOME" | awk 'NR==2 {gsub(/G/,"",$4); print $4}') -lt 280 ]]; then
  echo "ERROR: Need at least 280 GiB free on the Linux filesystem (WSL ext4.vhdx)."
  echo "       Move WSL to a larger drive via .wslconfig before continuing."
  exit 1
fi

sudo apt-get update
sudo apt-get install -y \
  git-core gnupg flex bison build-essential zip curl zlib1g-dev \
  gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses-dev \
  x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev \
  libxml2-utils xsltproc unzip fontconfig python3 python3-pip \
  rsync libssl-dev bc cpio m4 jq

if ! command -v repo >/dev/null 2>&1; then
  sudo curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
  sudo chmod a+x /usr/local/bin/repo
fi

mkdir -p "$SYNC_DIR"
cd "$SYNC_DIR"

if [[ ! -d .repo ]]; then
  repo init -u "$MANIFEST_URL" -b "$BRANCH"
fi

repo sync "${REPO_SYNC_FLAGS[@]}"

echo ""
echo "==> Source sync complete."
echo "    Next: apply burnOS menu/UI overlays, then build for panther or lynx:"
echo "      bash \"$SCRIPT_DIR/apply-overlays.sh\""
echo "      bash \"$SCRIPT_DIR/build-rom.sh\"              # full build (or manual steps below)"
echo "      source build/envsetup.sh"
echo "      lunch aosp_panther-bp2a-userrelease   # Pixel 7"
echo "      lunch aosp_lynx-bp2a-userrelease      # Pixel 7a"
echo "      m -j\$(nproc)"
