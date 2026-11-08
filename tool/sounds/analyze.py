#!/usr/bin/env python3
"""Measures every sound in app/assets/sounds and checks it against the house rules.

    python3 tool/sounds/analyze.py              # table + checks, exit code 1 when a rule is broken
    python3 tool/sounds/analyze.py --images     # also writes a spectrogram sheet to $TMPDIR (or ./sounds-spectrograms.png)

The rules (see the header of make_sounds.py): calm and not harsh means no sound has real energy
above 8 kHz, none is loud, none starts with a hard click, none has a DC offset, and the cues are
about equally loud so that no one of them jumps out.
"""
from __future__ import annotations

import os
import pathlib
import sys
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOUNDS = ROOT / "app" / "assets" / "sounds"

MAX_PEAK_DB = -3.0
LOUDNESS_RANGE_DB = (-26.0, -15.0)  # loudest 200 ms, relative to full scale
MAX_SHARE_ABOVE_8K = 0.02
MAX_SHARE_ABOVE_6K = 0.10
MAX_CENTROID_HZ = 3200.0
MAX_DC = 0.002
MAX_SECONDS = 4.0
MIN_SECONDS = 0.15


def load(path: pathlib.Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as w:
        assert w.getsampwidth() == 2 and w.getnchannels() == 1, f"{path.name}: expected 16-bit mono"
        sr = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    return data, sr


def momentary_db(x: np.ndarray, sr: int, window_ms: float = 200) -> float:
    w = int(sr * window_ms / 1000)
    if len(x) <= w:
        return 10 * np.log10(np.mean(x ** 2) + 1e-12)
    return 10 * np.log10(np.max(np.convolve(x ** 2, np.ones(w) / w, mode="valid")) + 1e-12)


def spectrum(x: np.ndarray, sr: int) -> tuple[np.ndarray, np.ndarray]:
    size = 1 << int(np.ceil(np.log2(max(len(x), 2048))))
    mag = np.abs(np.fft.rfft(x * np.hanning(len(x)), size)) ** 2
    return np.fft.rfftfreq(size, 1.0 / sr), mag


def measure(x: np.ndarray, sr: int) -> dict[str, float]:
    freqs, power = spectrum(x, sr)
    total = power.sum() + 1e-18
    peak = np.max(np.abs(x))
    # How fast the first sound rises, judged inside its first 60 ms (a later note may be louder).
    head = np.abs(x[: int(0.06 * sr)])
    local = head.max() + 1e-12
    start = int(np.argmax(head >= 0.10 * local))
    first = int(np.argmax(head >= 0.90 * local))
    return {
        "seconds": len(x) / sr,
        "peak_db": 20 * np.log10(peak + 1e-12),
        "loud_db": momentary_db(x, sr),
        "centroid": float((freqs * power).sum() / total),
        "above_6k": float(power[freqs > 6000].sum() / total),
        "above_8k": float(power[freqs > 8000].sum() / total),
        "onset_ms": (first - start) * 1000.0 / sr,
        "dc": float(abs(np.mean(x))),
        "first_sample": float(abs(x[0])),
    }


def check(name: str, m: dict[str, float]) -> list[str]:
    problems = []
    if m["peak_db"] > MAX_PEAK_DB:
        problems.append(f"peak {m['peak_db']:.1f} dB is above {MAX_PEAK_DB}")
    lo, hi = LOUDNESS_RANGE_DB
    if not lo <= m["loud_db"] <= hi:
        problems.append(f"loudness {m['loud_db']:.1f} dB is outside {lo}..{hi}")
    if m["above_8k"] > MAX_SHARE_ABOVE_8K:
        problems.append(f"{m['above_8k'] * 100:.1f}% of the energy is above 8 kHz")
    if m["above_6k"] > MAX_SHARE_ABOVE_6K:
        problems.append(f"{m['above_6k'] * 100:.1f}% of the energy is above 6 kHz")
    if m["centroid"] > MAX_CENTROID_HZ:
        problems.append(f"centroid {m['centroid']:.0f} Hz is too bright")
    if m["dc"] > MAX_DC:
        problems.append(f"DC offset {m['dc']:.4f}")
    if m["first_sample"] > 0.01:
        problems.append("does not start from silence (click)")
    if not MIN_SECONDS <= m["seconds"] <= MAX_SECONDS:
        problems.append(f"length {m['seconds']:.2f} s is outside {MIN_SECONDS}..{MAX_SECONDS}")
    return problems


def spectrogram_image(x: np.ndarray, sr: int, width: int = 360, height: int = 120, fmax: float = 10000.0) -> np.ndarray:
    nfft = 1024
    hop = max(1, (len(x) - nfft) // width)
    frames = []
    win = np.hanning(nfft)
    for i in range(width):
        s = i * hop
        seg = x[s : s + nfft]
        if len(seg) < nfft:
            seg = np.pad(seg, (0, nfft - len(seg)))
        frames.append(np.abs(np.fft.rfft(seg * win)))
    spec = np.array(frames).T  # freq x time
    freqs = np.fft.rfftfreq(nfft, 1.0 / sr)
    spec = spec[freqs <= fmax]
    db = 20 * np.log10(spec + 1e-9)
    db = np.clip((db - (db.max() - 70)) / 70, 0, 1)
    rows = np.linspace(0, db.shape[0] - 1, height).astype(int)
    img = db[rows][::-1]
    # dark brown -> cream, a calm ramp that matches the app colours
    lo = np.array([23, 19, 15], dtype=float)
    hi = np.array([241, 233, 214], dtype=float)
    return (lo[None, None, :] * (1 - img[..., None]) + hi[None, None, :] * img[..., None]).astype(np.uint8)


def write_sheet(items: list[tuple[str, np.ndarray, int]], out: pathlib.Path) -> None:
    from PIL import Image, ImageDraw

    cols = 3
    cell_w, cell_h, label_h = 360, 120, 18
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * (cell_h + label_h)), (241, 233, 214))
    draw = ImageDraw.Draw(sheet)
    for i, (name, x, sr) in enumerate(items):
        cx, cy = (i % cols) * cell_w, (i // cols) * (cell_h + label_h)
        draw.text((cx + 4, cy + 3), f"{name}  {len(x) / sr:.2f}s  (0-10 kHz)", fill=(23, 19, 15))
        sheet.paste(Image.fromarray(spectrogram_image(x, sr)), (cx, cy + label_h))
    sheet.save(out)


def main() -> int:
    files = sorted(SOUNDS.glob("*.wav"))
    if not files:
        print(f"no sounds in {SOUNDS}; run make_sounds.py first")
        return 1
    print(f"{'sound':<10} {'sec':>5} {'peak':>6} {'loud':>6} {'centr':>6} {'>6k%':>5} {'>8k%':>5} {'onset':>6}")
    failures = 0
    items = []
    loud_values = []
    for path in files:
        x, sr = load(path)
        items.append((path.stem, x, sr))
        m = measure(x, sr)
        loud_values.append(m["loud_db"])
        print(
            f"{path.stem:<10} {m['seconds']:>5.2f} {m['peak_db']:>6.1f} {m['loud_db']:>6.1f} {m['centroid']:>6.0f} "
            f"{m['above_6k'] * 100:>5.1f} {m['above_8k'] * 100:>5.2f} {m['onset_ms']:>6.1f}"
        )
        for problem in check(path.stem, m):
            failures += 1
            print(f"    !! {problem}")
    spread = max(loud_values) - min(loud_values)
    print(f"\nloudness spread {spread:.1f} dB over {len(files)} sounds; {failures} problem(s)")
    if "--images" in sys.argv:
        out = pathlib.Path(os.environ.get("TMPDIR", ".")) / "sounds-spectrograms.png"
        write_sheet(items, out)
        print(f"spectrograms: {out}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
