#!/usr/bin/env python3
"""Generate launcher icon densities from burn/branding/images/burn-logo-icon.png."""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit("PIL required: pip install pillow") from exc

SCRIPT_DIR = Path(__file__).resolve().parent
SOURCE = SCRIPT_DIR.parent / "branding/images/burn-logo-icon.png"
OUT = SCRIPT_DIR.parent / "branding/icons"

LEGACY_MIPMAP = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

ADAPTIVE_FG = {
    "drawable-mdpi": 108,
    "drawable-hdpi": 162,
    "drawable-xhdpi": 216,
    "drawable-xxhdpi": 324,
    "drawable-xxxhdpi": 432,
}


def resize_square(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.Resampling.LANCZOS)


def write_png(path: Path, im: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, format="PNG", optimize=True)


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"missing source icon: {SOURCE}")

    im = Image.open(SOURCE).convert("RGBA")
    print(f"source: {SOURCE} ({im.width}x{im.height})")

    for folder, size in LEGACY_MIPMAP.items():
        write_png(OUT / folder / "ic_launcher_settings.png", resize_square(im, size))
        write_png(OUT / folder / "ic_launcher.png", resize_square(im, size))
        write_png(OUT / folder / "ic_launcher_round.png", resize_square(im, size))

    for folder, size in ADAPTIVE_FG.items():
        write_png(OUT / folder / "ic_launcher_foreground.png", resize_square(im, size))

    # Launcher3 only ships up to xxhdpi for home foreground.
    for folder, size in ADAPTIVE_FG.items():
        if folder == "drawable-xxxhdpi":
            continue
        mipmap = folder.replace("drawable-", "mipmap-")
        write_png(OUT / mipmap / "ic_launcher_home_foreground.png", resize_square(im, size))

    print(f"generated icons under {OUT}")


if __name__ == "__main__":
    main()
