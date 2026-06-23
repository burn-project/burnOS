#!/usr/bin/env python3
"""burnOS — stop auto-granting runtime permissions to carrier-privileged apps."""
from __future__ import annotations

import re
import sys
from pathlib import Path

MARKER = "burnOS: skip carrier default permission grants"
METHOD = "grantDefaultPermissionsToEnabledCarrierApps"


def _find_method_span(text: str, method: str) -> tuple[int, int] | None:
    pattern = re.compile(rf"public\s+void\s+{re.escape(method)}\s*\(")
    match = pattern.search(text)
    if not match:
        return None

    brace_start = text.find("{", match.end())
    if brace_start < 0:
        return None

    depth = 0
    for idx in range(brace_start, len(text)):
        ch = text[idx]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return match.start(), idx + 1
    return None


def patch_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    span = _find_method_span(text, METHOD)
    if span is None:
        raise SystemExit(f"method {METHOD} not found in {path}")

    start, end = span
    method_text = text[start:end]
    if MARKER in method_text and "return;" not in method_text.split(MARKER, 1)[1]:
        print(f"    already patched: {path}")
        return False

    replacement = (
        f"public void {METHOD}(String[] packageNames, int userId) {{\n"
        f"        // {MARKER}\n"
        f"    }}"
    )
    updated = text[:start] + replacement + text[end:]
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
