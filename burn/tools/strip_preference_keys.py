#!/usr/bin/env python3
"""Remove Preference blocks that declare a matching android:key (including nested children)."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

KEY_PATTERN = re.compile(r'android:key="([^"]+)"')
PREFERENCE_OPEN = re.compile(
    r"<\s*("
    r"Preference"
    r"|com\.android\.[^\s>]+Preference"
    r"|com\.android\.settings\.widget\.[^\s>]+"
    r")\b"
)


def find_element_bounds(xml_text: str, open_index: int) -> tuple[int, int]:
    tag_end = xml_text.find(">", open_index)
    if tag_end == -1:
        raise ValueError("Malformed XML: unclosed tag")

    open_tag = xml_text[open_index : tag_end + 1]
    if open_tag.rstrip().endswith("/>"):
        return open_index, tag_end + 1

    tag_name_match = re.match(r"<\s*([A-Za-z0-9_.]+)", open_tag)
    if not tag_name_match:
        raise ValueError("Malformed XML: cannot parse tag name")

    tag_name = tag_name_match.group(1)
    close_tag = f"</{tag_name}>"
    depth = 1
    pos = tag_end + 1
    length = len(xml_text)

    while depth > 0 and pos < length:
        next_open = xml_text.find("<", pos)
        next_close = xml_text.find(close_tag, pos)
        if next_close == -1:
            raise ValueError(f"Unclosed tag {tag_name}")

        if next_open != -1 and next_open < next_close:
            nested = xml_text[next_open : xml_text.find(">", next_open) + 1]
            if nested.startswith("<!--") or nested.startswith("<?"):
                pos = next_open + 1
                continue
            if nested.rstrip().endswith("/>"):
                pos = next_open + len(nested)
                continue
            if nested.startswith("</"):
                depth -= 1
            elif re.match(r"<\s*[A-Za-z0-9_.]+", nested):
                depth += 1
            pos = next_open + 1
        else:
            depth -= 1
            pos = next_close + len(close_tag)

    return open_index, pos


def find_preference_start(xml_text: str, key_index: int) -> int | None:
    pos = key_index
    while pos > 0:
        open_index = xml_text.rfind("<", 0, pos)
        if open_index == -1:
            return None
        tag_end = xml_text.find(">", open_index)
        if tag_end == -1 or tag_end > key_index:
            pos = open_index - 1
            continue
        open_tag = xml_text[open_index : tag_end + 1]
        if open_tag.startswith("</") or open_tag.startswith("<!--"):
            pos = open_index - 1
            continue
        if "PreferenceCategory" in open_tag:
            pos = open_index - 1
            continue
        if PREFERENCE_OPEN.match(open_tag):
            return open_index
        pos = open_index - 1
    return None


def strip_keys(xml_text: str, keys: set[str]) -> tuple[str, list[str]]:
    removed: list[str] = []
    for key in keys:
        while True:
            needle = f'android:key="{key}"'
            key_index = xml_text.find(needle)
            if key_index == -1:
                break
            start = find_preference_start(xml_text, key_index)
            if start is None:
                break
            _, end = find_element_bounds(xml_text, start)
            xml_text = xml_text[:start] + xml_text[end:]
            removed.append(key)
    return xml_text, removed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xml_file", type=Path)
    parser.add_argument("keys", nargs="+", help="android:key values to remove")
    args = parser.parse_args()

    original = args.xml_file.read_text(encoding="utf-8")
    updated, removed = strip_keys(original, set(args.keys))

    if not removed:
        print(f"    no matching keys in {args.xml_file} (already stripped?)")
        return 0

    args.xml_file.write_text(updated, encoding="utf-8")
    print(f"Removed from {args.xml_file}: {', '.join(dict.fromkeys(removed))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
