#!/usr/bin/env python3
"""Rebuild every launcher icon from branding/logo*.svg (needs Chrome and Pillow).

    python3 branding/build_icons.py

Sources: logo.svg (full tile), logo-foreground.svg (transparent, inside the Android adaptive
safe zone), logo-maskable.svg (tile with extra margin, for web maskable icons).
"""
import subprocess, tempfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
HERE = Path(__file__).resolve().parent
APP = ROOT / "app"
RES = APP / "android/app/src/main/res"


def render(svg: str, size: int, transparent: bool = False) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "out.png"
        args = [str(HERE / "render.sh"), str(HERE / svg), str(out), str(size)]
        if transparent:
            args.append("transparent")
        subprocess.run(args, check=True)
        return Image.open(out).convert("RGBA")


def save(img: Image.Image, path: Path, size: int, flat: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    if flat:  # iOS rejects an alpha channel
        out = out.convert("RGB")
    out.save(path)


master = render("logo.svg", 1024)
fore = render("logo-foreground.svg", 1024, transparent=True)
mask = render("logo-maskable.svg", 1024)

# Android: legacy launcher icons plus an adaptive icon (paper background, chip foreground).
for density, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save(master, RES / f"mipmap-{density}/ic_launcher.png", px)
for density, px in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
    save(fore, RES / f"mipmap-{density}/ic_launcher_foreground.png", px)

# iOS: sizes come from Contents.json.
import json
ios = APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for image in json.loads((ios / "Contents.json").read_text())["images"]:
    if "filename" not in image:
        continue
    size = float(image["size"].split("x")[0]) * int(image["scale"].rstrip("x"))
    save(master, ios / image["filename"], round(size), flat=True)

# macOS.
mac = APP / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
for f in mac.glob("app_icon_*.png"):
    save(master, f, int(f.stem.split("_")[-1]))

# Windows .ico.
ico = APP / "windows/runner/resources/app_icon.ico"
master.save(ico, sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])

# Web.
web = APP / "web"
save(master, web / "icons/Icon-192.png", 192)
save(master, web / "icons/Icon-512.png", 512)
save(mask, web / "icons/Icon-maskable-192.png", 192)
save(mask, web / "icons/Icon-maskable-512.png", 512)
save(master, web / "favicon.png", 32)

# Linux: the window icon, and the icon the desktop entry points at.
save(master, APP / "linux/icons/dev.pokercredits.poker_credits.png", 512)

# README / docs.
save(master, HERE / "logo.png", 512)
print("icons written")
