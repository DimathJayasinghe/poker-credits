#!/usr/bin/env python3
"""Prepares the folder that `makeappx pack` turns into the Microsoft Store package (MSIX).

    python3 tool/msix_stage.py --check
    python3 tool/msix_stage.py --bundle <Flutter Release folder> --out <stage folder> \
        [--identity-name N --publisher "CN=..." --publisher-display-name P]
    (the three values default to the environment variables MSSTORE_IDENTITY_NAME, MSSTORE_PUBLISHER and
    MSSTORE_PUBLISHER_DISPLAY_NAME)

`--check` only validates packaging/windows/msix (manifest template, logos, capabilities) and exits 1
on a problem. Without `--check` the Flutter Windows bundle is copied to the stage folder together with
the filled-in manifest and the logos, and one JSON line is printed: {"version": ..., "placeholder": ...}.

The three identity values come from the app's "Product identity" page in Partner Center. When they
are missing the package gets obvious placeholder values and `placeholder` is true: such a package
proves that packing works and must never be uploaded to the Store (docs/MICROSOFT_STORE.md).
Only the Python standard library and Pillow (only for `--check`, to read the logo sizes) are used.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import quoteattr

ROOT = Path(__file__).resolve().parents[1]
MSIX = ROOT / "packaging" / "windows" / "msix"
TEMPLATE = MSIX / "AppxManifest.xml.in"
ASSETS = MSIX / "Assets"
PUBSPEC = ROOT / "app" / "pubspec.yaml"
CMAKE = ROOT / "app" / "windows" / "CMakeLists.txt"

PLACEHOLDER = {
    "IDENTITY_NAME": "PokerCredits.PlaceholderDoNotSubmit",
    "PUBLISHER": "CN=PlaceholderDoNotSubmit",
    "PUBLISHER_DISPLAY_NAME": "Placeholder (do not submit)",
}

# What the app really uses, and nothing more: Microsoft policy 10.6 asks every declared capability
# to relate to a function of the product. Camera and microphone are deliberately absent (the Windows
# app has no QR scanner and records nothing). Change this list only together with PRIVACY.md.
ALLOWED_CAPABILITIES = {"internetClient", "privateNetworkClientServer", "runFullTrust"}

NS = {
    "m": "http://schemas.microsoft.com/appx/manifest/foundation/windows10",
    "uap": "http://schemas.microsoft.com/appx/manifest/uap/windows10",
    "rescap": "http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities",
}

LOGO_SIZES = {
    "StoreLogo": (50, 50),
    "Square44x44Logo": (44, 44),
    "Square150x150Logo": (150, 150),
    "Wide310x150Logo": (310, 150),
}


def store_version() -> str:
    """`1.4.0+9` in pubspec.yaml becomes `1.4.0.0`: the Store insists on a last part of 0."""
    match = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)", PUBSPEC.read_text(), re.M)
    if not match:
        raise SystemExit(f"no version in {PUBSPEC}")
    return ".".join(match.groups()) + ".0"


def fill(values: dict[str, str]) -> str:
    text = TEMPLATE.read_text(encoding="utf-8")
    for key, value in {**values, "VERSION": store_version()}.items():
        # quoteattr escapes &, < and the quote marks; strip the quotes it adds around the value.
        text = text.replace("{{" + key + "}}", quoteattr(value, {'"': "&quot;"})[1:-1])
    leftover = re.findall(r"\{\{(\w+)\}\}", text)
    if leftover:
        raise SystemExit(f"unfilled manifest fields: {leftover}")
    return text


def check() -> list[str]:
    problems: list[str] = []
    try:
        text = fill(PLACEHOLDER)
        # The template is our own file and every inserted value is escaped, but the standard parser
        # would also expand entities, so a manifest that declares any is refused outright.
        if "<!DOCTYPE" in text or "<!ENTITY" in text:
            return ["the manifest declares a DOCTYPE or an entity"]
        root = ET.fromstring(text)
    except (ET.ParseError, SystemExit) as error:
        return [f"manifest does not parse: {error}"]

    version = root.find("m:Identity", NS).get("Version", "")
    if not re.fullmatch(r"[1-9]\d{0,4}\.\d{1,5}\.\d{1,5}\.0", version):
        problems.append(f"version {version!r}: the Store wants a.b.c.0 with a first part above 0")

    capabilities = {
        element.get("Name") for element in root.find("m:Capabilities", NS)
    }
    if capabilities != ALLOWED_CAPABILITIES:
        problems.append(f"capabilities {sorted(capabilities)} differ from {sorted(ALLOWED_CAPABILITIES)}")

    application = root.find("m:Applications/m:Application", NS)
    executable = application.get("Executable")
    binary = re.search(r'set\(BINARY_NAME "([^"]+)"\)', CMAKE.read_text())
    if not binary or executable != binary.group(1) + ".exe":
        problems.append(f"Executable {executable!r} is not the Flutter binary {binary and binary.group(1)}.exe")

    declared = {
        "StoreLogo": root.find("m:Properties/m:Logo", NS).text,
        "Square150x150Logo": application.find("uap:VisualElements", NS).get("Square150x150Logo"),
        "Square44x44Logo": application.find("uap:VisualElements", NS).get("Square44x44Logo"),
        "Wide310x150Logo": application.find("uap:VisualElements/uap:DefaultTile", NS).get("Wide310x150Logo"),
    }
    try:
        from PIL import Image
    except ImportError:
        Image = None
    for name, relative in declared.items():
        file = MSIX / relative.replace("\\", "/")
        if not file.is_file():
            problems.append(f"{relative} is named in the manifest but is missing")
        elif Image is not None and Image.open(file).size != LOGO_SIZES[name]:
            problems.append(f"{relative} is {Image.open(file).size}, expected {LOGO_SIZES[name]}")
        scaled = file.with_name(file.stem + ".scale-200" + file.suffix)
        if not scaled.is_file():
            problems.append(f"{scaled.name} (200 %) is missing")
    return problems


def stage(bundle: Path, out: Path, values: dict[str, str]) -> None:
    if not (bundle / "poker_credits.exe").is_file():
        raise SystemExit(f"{bundle} is not a Flutter Windows bundle (no poker_credits.exe)")
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(bundle, out)
    shutil.copytree(ASSETS, out / "Assets")
    (out / "AppxManifest.xml").write_text(fill(values), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--out", type=Path)
    # The workflow passes the values through these variables: an empty argument is easy to lose in a shell.
    parser.add_argument("--identity-name", default=os.environ.get("MSSTORE_IDENTITY_NAME", ""))
    parser.add_argument("--publisher", default=os.environ.get("MSSTORE_PUBLISHER", ""))
    parser.add_argument("--publisher-display-name", default=os.environ.get("MSSTORE_PUBLISHER_DISPLAY_NAME", ""))
    args = parser.parse_args()

    problems = check()
    for problem in problems:
        print(f"msix: {problem}", file=sys.stderr)
    if problems or args.check:
        if not problems:
            print("msix: ok")
        return 1 if problems else 0

    if not (args.bundle and args.out):
        parser.error("--bundle and --out are required unless --check is used")
    given = {
        "IDENTITY_NAME": args.identity_name.strip(),
        "PUBLISHER": args.publisher.strip(),
        "PUBLISHER_DISPLAY_NAME": args.publisher_display_name.strip(),
    }
    if any(given.values()) and not all(given.values()):
        raise SystemExit("give all three identity values or none: " + ", ".join(k for k, v in given.items() if not v) + " is empty")
    placeholder = not all(given.values())
    stage(args.bundle, args.out, PLACEHOLDER if placeholder else given)
    print(json.dumps({"version": store_version(), "placeholder": placeholder}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
