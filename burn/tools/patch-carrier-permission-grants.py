#!/usr/bin/env python3
"""burnOS — stop auto-granting runtime permissions to carrier-privileged apps."""
from __future__ import annotations

import re
import sys
from pathlib import Path

MARKER = "burnOS: skip carrier default permission grants"
METHOD = "grantDefaultPermissionsToEnabledCarrierApps"


def patch_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if MARKER in text:
        print(f"    already patched: {path}")
        return False

    pattern = re.compile(
        rf"(public\s+void\s+{METHOD}\s*\([^)]*\)\s*\{{)",
        re.MULTILINE,
    )
    match = pattern.search(text)
    if not match:
        raise SystemExit(f"method {METHOD} not found in {path}")

    insert = (
        f"{match.group(1)}\n"
        f"        // {MARKER}\n"
        f"        return;\n"
    )
    updated = text[: match.start()] + insert + text[match.end() :]
    path.write_text(updated, encoding="utf-8")
    print(f"    patched carrier permission grants: {path}")
    return True


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <sync-dir>")

    sync_dir = Path(sys.argv[1])
    candidates = [
        sync_dir
        / "frameworks/base/services/core/java/com/android/server/pm/permission/DefaultPermissionGrantPolicy.java",
        sync_dir
        / "frameworks/base/services/core/java/com/android/server/pm/DefaultPermissionGrantPolicy.java",
    ]
    for path in candidates:
        if path.is_file():
            patch_file(path)
            return

    print("    skip: DefaultPermissionGrantPolicy.java not synced yet")


if __name__ == "__main__":
    main()
