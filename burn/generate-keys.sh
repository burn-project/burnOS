#!/usr/bin/env bash
# Generate burnOS release signing keys (GrapheneOS-compatible layout).
# Run once per device variant. Keys are stored outside git — back them up securely.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="${1:-panther}"
SYNC_DIR="${SYNC_DIR:-$HOME/burnOS-src}"
CN="${BURN_KEY_CN:-burn.tel}"
KEYS_DIR="${KEYS_DIR:-$SCRIPT_DIR/../keys/$DEVICE}"

if [[ ! -d "$SYNC_DIR/.repo" ]]; then
  echo "ERROR: sync tree not found: $SYNC_DIR"
  exit 1
fi

if [[ -e "$KEYS_DIR/releasekey.pk8" ]]; then
  echo "ERROR: keys already exist in $KEYS_DIR"
  echo "       Delete the directory first if you intend to regenerate (will require re-flash)."
  exit 1
fi

mkdir -p "$KEYS_DIR"
cd "$KEYS_DIR"

AVBTOOL_BIN="$SYNC_DIR/out/host/linux-x86/bin/avbtool"
AVBTOOL_PY="$SYNC_DIR/external/avb/avbtool.py"
run_avbtool() {
  if [[ -x "$AVBTOOL_BIN" ]]; then
    "$AVBTOOL_BIN" "$@"
  elif [[ -f "$AVBTOOL_PY" ]]; then
    python3 "$AVBTOOL_PY" "$@"
  else
    echo "ERROR: avbtool not found in sync tree"
    exit 1
  fi
}

make_release_key() {
  local name="$1"
  echo "    $name"
  openssl genrsa -out "$name.pem" 4096 2>/dev/null
  openssl pkcs8 -topk8 -inform PEM -outform DER -in "$name.pem" -out "$name.pk8" -nocrypt
  openssl req -new -x509 -key "$name.pem" -out "$name.x509.pem" -days 36500 -subj "/CN=$CN/"
  rm -f "$name.pem"
}

echo "==> burnOS release keys for $DEVICE"
echo "    subject CN=$CN"
echo "    output: $KEYS_DIR"

for name in releasekey platform shared media networkstack bluetooth sdk_sandbox gmscompat_lib nfc; do
  make_release_key "$name"
done

echo "    avb.pem + avb_pkmd.bin"
openssl genrsa -out avb.pem 4096 2>/dev/null
run_avbtool extract_public_key --key avb.pem --output avb_pkmd.bin

if [[ ! -f id_ed25519 ]]; then
  echo "    id_ed25519 (factory image signing, optional)"
  ssh-keygen -t ed25519 -f id_ed25519 -N "" -C "burnOS-$DEVICE-factory"
  chmod 600 id_ed25519
fi

mkdir -p "$SYNC_DIR/keys/$DEVICE"
rsync -a ./ "$SYNC_DIR/keys/$DEVICE/"

echo ""
echo "==> Done. Keys written to:"
echo "    $KEYS_DIR"
echo "    $SYNC_DIR/keys/$DEVICE"
echo ""
echo "Optional: encrypt at rest with:"
echo "    cd $SYNC_DIR && script/encrypt-keys keys/$DEVICE"
echo ""
echo "Next: bash burn/sign-release.sh $DEVICE"
