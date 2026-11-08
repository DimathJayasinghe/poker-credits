#!/usr/bin/env python3
"""Draws the Microsoft Store logos from branding/logo.svg (needs Chrome and Pillow, like branding/build_icons.py).

    python3 packaging/windows/build_msix_assets.py

Writes packaging/windows/msix/Assets (the tiles the package manifest names, plus @2x versions) and
packaging/windows/store (the logos Partner Center asks for on the listing). The artwork is vector, so
every size is drawn fresh, never scaled up from a small one.
"""
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SVG = ROOT / "branding" / "logo.svg"
RENDER = ROOT / "branding" / "render.sh"
ASSETS = ROOT / "packaging" / "windows" / "msix" / "Assets"
STORE = ROOT / "packaging" / "windows" / "store"
PAPER = (0xEF, 0xE5, 0xCF)  # the logo's own background, docs/UI_DESIGN.md


def render(size: int) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "out.png"
        subprocess.run([str(RENDER), str(SVG), str(out), str(size)], check=True)
        return Image.open(out).convert("RGBA")


def square(size: int, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    render(size).save(path)


def wide(width: int, height: int, path: Path) -> None:
    """The logo centred on the paper colour, as wide tiles are drawn."""
    mark = render(round(height * 0.84))
    tile = Image.new("RGBA", (width, height), PAPER + (255,))
    tile.paste(mark, ((width - mark.width) // 2, (height - mark.height) // 2), mark)
    path.parent.mkdir(parents=True, exist_ok=True)
    tile.save(path)


# Tiles named in AppxManifest.xml.in. The unqualified file is the 100 % size, `.scale-200` the 200 % one.
for scale, suffix in ((1, ""), (2, ".scale-200")):
    square(50 * scale, ASSETS / f"StoreLogo{suffix}.png")
    square(44 * scale, ASSETS / f"Square44x44Logo{suffix}.png")
    square(150 * scale, ASSETS / f"Square150x150Logo{suffix}.png")
    wide(310 * scale, 150 * scale, ASSETS / f"Wide310x150Logo{suffix}.png")
# The taskbar and Start list pick the target size that fits; the plain and unplated forms keep it sharp.
for target in (16, 24, 32, 48, 256):
    square(target, ASSETS / f"Square44x44Logo.targetsize-{target}.png")

# Partner Center, Store listing: the 1:1 tile icon (300) and the 1:1 box art (1080).
square(300, STORE / "store-logo-300x300.png")
square(1080, STORE / "box-art-1080x1080.png")
print("assets written")
