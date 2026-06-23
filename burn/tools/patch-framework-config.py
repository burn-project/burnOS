#!/usr/bin/env python3
"""burnOS — patch frameworks/base config.xml (avoid duplicate values resources)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

CONFIG = Path("frameworks/base/core/res/res/values/config.xml")

PATCHES: tuple[tuple[str, str], ...] = (
    (
        r'(<integer name="config_defaultNightMode">)\d+(</integer>)',
        r"\g<1>2\g<2>",
    ),
    (
        r'(<integer name="config_showOperatorNameDefault">)\d+(</integer>)',
        r"\g<1>1\g<2>",
    ),
    (
        r'(<item name="default_lock_wallpaper" type="drawable">)[^<]+(</item>)',
        r"\g<1>@drawable/default_wallpaper\g<2>",
    ),
)


def patch_config(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    updated = text
    changed = False
    for pattern, repl in PATCHES:
        new_text, count = re.subn(pattern, repl, updated, count=1)
        if count == 0:
            raise SystemExit(f"pattern not found in {path}: {pattern}")
        if new_text != updated:
            changed = True
        updated = new_text
    if changed:
        path.write_text(updated, encoding="utf-8")
        print(f"    patched framework config: {path}")
    else:
        print(f"    framework config already patched: {path}")
    return changed


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <sync-dir>")
    sync = Path(sys.argv[1])
    path = sync / CONFIG
    if not path.is_file():
        raise SystemExit(f"missing {path}")
    patch_config(path)


if __name__ == "__main__":
    main()
