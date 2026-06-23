#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="/mnt/c/Users/Mr. Rico/Downloads/burnOS-panther"
SRC="/root/burnOS-src/out/target/product/panther"
ZIP="$SRC/obj/PACKAGING/target_files_intermediates/panther-target_files.zip"

mkdir -p "$DEST"

echo "==> Copying flash images to $DEST"
cp -v "$SRC"/*.img "$DEST"/

for f in android-info.txt fastboot-info.txt build_fingerprint-panther.txt build_thumbprint-panther.txt; do
  if [[ -f "$SRC/$f" ]]; then
    cp -v "$SRC/$f" "$DEST"/
  fi
done

echo "==> Copying target-files zip ($(du -h "$ZIP" | awk '{print $1}'))"
cp -v "$ZIP" "$DEST"/

echo "==> Preparing flash bundle (flash-all.bat + image zip)"
bash "$SCRIPT_DIR/generate-flash-bundle.sh" "$DEST"

echo "==> Done"
ls -lh "$DEST"
