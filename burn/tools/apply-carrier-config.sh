#!/usr/bin/env bash
# Merge burnOS carrier overlays into CarrierConfig vendor.xml assets.
set -euo pipefail

SYNC_DIR="${1:?sync dir}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

merge_vendor() {
  local assets_dir="$1"
  local burn_list="$2"
  local vendor_xml="$assets_dir/vendor.xml"
  mkdir -p "$assets_dir"

  python3 - "$vendor_xml" "$burn_list" <<'PY'
import sys
import xml.etree.ElementTree as ET

vendor_path, burn_path = sys.argv[1:3]
burn_tree = ET.parse(burn_path)
burn_cfgs = burn_tree.findall('.//carrier_config')
if not burn_cfgs:
    raise SystemExit(f'{burn_path}: missing carrier_config')

try:
    tree = ET.parse(vendor_path)
    root = tree.getroot()
except (FileNotFoundError, ET.ParseError):
    root = ET.Element('carrier_config_list')
    tree = ET.ElementTree(root)

merged = 0
for burn_cfg in burn_cfgs:
    burn_keys = {child.get('name') for child in burn_cfg}
    if any(
        {child.get('name') for child in existing} == burn_keys
        for existing in root.findall('carrier_config')
    ):
        print(f'    already merged {burn_path}: {sorted(burn_keys)}')
        continue
    root.append(burn_cfg)
    merged += 1

if merged == 0:
    sys.exit(0)

if hasattr(ET, 'indent'):
    ET.indent(tree, space='    ')
tree.write(vendor_path, encoding='utf-8', xml_declaration=True)
print(f'    merged {merged} block(s) from {burn_path} into {vendor_path}')
PY
}

for pkg in CarrierConfig CarrierConfig2; do
  assets="$SYNC_DIR/packages/apps/$pkg/assets"
  if [[ -d "$SYNC_DIR/packages/apps/$pkg" ]]; then
    echo "==> $pkg carrier overlays"
    for overlay in "$SCRIPT_DIR/../overlays/carrier-config"/*.xml; do
      [[ -f "$overlay" ]] || continue
      echo "    $(basename "$overlay")"
      merge_vendor "$assets" "$overlay"
    done
  fi
done
