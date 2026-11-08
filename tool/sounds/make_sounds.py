#!/usr/bin/env python3
"""Generates every sound effect of Poker Credits from nothing (no samples, no downloads).

    python3 tool/sounds/make_sounds.py            # writes app/assets/sounds/*.wav and audition.html
    python3 tool/sounds/analyze.py                # measures them (levels, brightness) and draws spectrograms

All sounds are original work made by this script, so they carry no third-party licence: see
`app/assets/sounds/README.md`. The script is deterministic (fixed seeds): running it again gives the
same files, so a change to a sound is a reviewable change to this file.

The palette ("felt table, warm wood, soft mallet"):
- Tonal cues are a soft felt mallet struck on a tine, tuned to D major pentatonic (D E F# A B), so any
  two of them sound consistent when they overlap. Fundamentals sit between 150 and 1200 Hz.
- Chips are small clay discs: a short ring of four inharmonic modes plus a low body knock, never
  brighter than 6 kHz. A call is a few chips set down, a raise more of them, an all-in a long cascade.
- Cards are filtered paper noise (a slide, a flick, a snap). A check is two knuckle taps on felt.
- Everything goes through one small, damped room so the sounds belong to the same place.
- Nothing is brighter than about 7 kHz, nothing has a hard attack (at least 3 ms), every sound ends
  with a short fade so nothing clicks.
"""
from __future__ import annotations

import html
import pathlib
import wave
import zlib

import numpy as np

SR = 44100
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "app" / "assets" / "sounds"
AUDITION = pathlib.Path(__file__).resolve().parent / "audition.html"

# D major pentatonic, in Hz (equal temperament, A4 = 440).
NOTE = {
    "D2": 73.42, "A2": 110.00, "D3": 146.83, "A3": 220.00,
    "D4": 293.66, "E4": 329.63, "F#4": 369.99, "A4": 440.00, "B4": 493.88,
    "D5": 587.33, "E5": 659.25, "F#5": 739.99, "A5": 880.00, "B5": 987.77,
    "D6": 1174.66,
}


def ms(x: float) -> int:
    return int(round(x * SR / 1000.0))


def tvec(n: int) -> np.ndarray:
    return np.arange(n) / SR


def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(name.encode()))


# --------------------------------------------------------------------------- filters


def fft_filter(x: np.ndarray, lp: float | None = None, hp: float | None = None, order: int = 2) -> np.ndarray:
    """Zero-phase Butterworth-shaped low/high-pass in the frequency domain."""
    n = len(x)
    size = 1 << int(np.ceil(np.log2(max(2, 2 * n))))
    spec = np.fft.rfft(x, size)
    f = np.fft.rfftfreq(size, 1.0 / SR)
    gain = np.ones_like(f)
    if lp:
        gain *= 1.0 / np.sqrt(1.0 + (f / lp) ** (2 * order))
    if hp:
        with np.errstate(divide="ignore"):
            gain *= 1.0 / np.sqrt(1.0 + (hp / np.maximum(f, 1e-9)) ** (2 * order))
    return np.fft.irfft(spec * gain, size)[:n]


def place(buf: np.ndarray, sound: np.ndarray, at_ms: float, gain: float = 1.0) -> None:
    start = ms(at_ms)
    end = min(len(buf), start + len(sound))
    if start < len(buf) and end > start:
        buf[start:end] += gain * sound[: end - start]


def blank(dur_ms: float) -> np.ndarray:
    return np.zeros(ms(dur_ms))


# --------------------------------------------------------------------------- voices


def soft_end(x: np.ndarray, frac: float = 0.35, max_ms: float = 400) -> np.ndarray:
    """Fades the last part of a voice to zero so a note never ends in a cut (a click)."""
    n = min(int(len(x) * frac), ms(max_ms))
    if n > 1:
        x[-n:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(n) / (n - 1))
    return x


def raised_attack(n: int, attack_ms: float) -> np.ndarray:
    a = np.minimum(1.0, np.arange(n) / max(1, ms(attack_ms)))
    return 0.5 - 0.5 * np.cos(np.pi * a)


def mallet(freq: float, dur_ms: float = 1000, tau_ms: float = 260, bright: float = 1.0, seed: str = "m") -> np.ndarray:
    """A soft felt mallet on a tine: a few harmonics that die faster as they go up, two slightly
    detuned copies for warmth and a short felt thump at the start."""
    rng = rng_for(seed)
    n = ms(dur_ms)
    tt = tvec(n)
    out = np.zeros(n)
    partials = [(1.0, 1.0, 1.0), (2.0, 0.26 * bright, 0.55), (3.0, 0.08 * bright, 0.35), (4.2, 0.045 * bright, 0.18)]
    for cents, gain in ((0.0, 1.0), (4.0, 0.55)):
        f = freq * 2.0 ** (cents / 1200.0)
        phase = rng.uniform(0, 2 * np.pi)
        for ratio, amp, rel in partials:
            out += gain * amp * np.sin(2 * np.pi * f * ratio * tt + phase * ratio) * np.exp(-tt / (tau_ms * rel / 1000.0))
    out *= raised_attack(n, 5.0)
    thump = fft_filter(rng.normal(size=n), lp=650) * np.exp(-tt / 0.006)
    out += 0.10 * thump / (np.max(np.abs(thump)) + 1e-9)
    return soft_end(out / (np.max(np.abs(out)) + 1e-9))


def pad(freqs: list[float], dur_ms: float, attack_ms: float, tau_ms: float, seed: str = "p") -> np.ndarray:
    """A soft sustained bed: sines with a slow swell and a long fade."""
    rng = rng_for(seed)
    n = ms(dur_ms)
    tt = tvec(n)
    out = np.zeros(n)
    for f in freqs:
        for cents in (-5.0, 5.0):
            out += np.sin(2 * np.pi * f * 2.0 ** (cents / 1200.0) * tt + rng.uniform(0, 2 * np.pi))
    out *= raised_attack(n, attack_ms) * np.exp(-np.maximum(0, tt - attack_ms / 1000.0) / (tau_ms / 1000.0))
    return soft_end(fft_filter(out, lp=2500) / (np.max(np.abs(out)) + 1e-9))


def chip(rng: np.random.Generator, strength: float = 1.0, pitch: float = 1.0) -> np.ndarray:
    """One clay chip touching another: a ring of four modes and a low knock."""
    n = ms(80)
    tt = tvec(n)
    base = 1250.0 * pitch * (1.0 + rng.uniform(-0.05, 0.05))
    modes = [(1.0, 1.0, 22.0), (1.62, 0.7, 14.0), (2.35, 0.5, 9.0), (3.4, 0.28, 6.0)]
    ring = np.zeros(n)
    for ratio, amp, tau in modes:
        ring += amp * np.sin(2 * np.pi * base * ratio * tt + rng.uniform(0, 2 * np.pi)) * np.exp(-tt / (tau / 1000.0))
    click = fft_filter(rng.normal(size=n), lp=4200, order=3) * np.exp(-tt / 0.0012) * 0.45
    body = np.sin(2 * np.pi * 520.0 * pitch * tt) * np.exp(-tt / 0.014) * 0.55
    x = (ring + click + body) * raised_attack(n, 0.8)
    x = fft_filter(x, lp=5200, order=3)
    return strength * x / (np.max(np.abs(x)) + 1e-9)


def felt_thud(freq: float = 130.0, dur_ms: float = 90, tau_ms: float = 28) -> np.ndarray:
    n = ms(dur_ms)
    tt = tvec(n)
    x = np.sin(2 * np.pi * freq * tt) * np.exp(-tt / (tau_ms / 1000.0)) * raised_attack(n, 3.0)
    return x


def stack(rng: np.random.Generator, hits: int, spread_ms: float, strength: float = 1.0, thud: float = 0.5, pitch: float = 1.0) -> np.ndarray:
    """Chips set down together: `hits` touches spread over `spread_ms`, then the stack settles."""
    out = blank(spread_ms + 140)
    for i in range(hits):
        at = 0.0 if i == 0 else rng.uniform(0.15, 1.0) * spread_ms
        place(out, chip(rng, strength * rng.uniform(0.55, 1.0) * (1.0 - 0.25 * i / max(1, hits)), pitch * rng.uniform(0.92, 1.1)), at)
    place(out, felt_thud(), spread_ms * 0.35, thud * strength)
    return out


def knock(rng: np.random.Generator, strength: float = 1.0) -> np.ndarray:
    """A knuckle on felt over wood."""
    n = ms(120)
    tt = tvec(n)
    body = np.sin(2 * np.pi * 175.0 * tt) * np.exp(-tt / 0.040) + 0.4 * np.sin(2 * np.pi * 362.0 * tt) * np.exp(-tt / 0.022)
    skin = fft_filter(rng.normal(size=n), lp=1400) * np.exp(-tt / 0.003) * 0.5
    x = fft_filter((body + skin) * raised_attack(n, 2.0), lp=2600)
    return strength * x / (np.max(np.abs(x)) + 1e-9)


def card_slide(rng: np.random.Generator, dur_ms: float = 170, tilt: float = 1.0) -> np.ndarray:
    """A card sliding over felt: paper noise whose colour moves from dull to brighter."""
    n = ms(dur_ms)
    noise = rng.normal(size=n)
    low = fft_filter(noise, lp=1700, hp=420, order=3)
    high = fft_filter(noise, lp=3300, hp=1300, order=3)
    s = np.linspace(0.0, 1.0, n) ** 1.4
    mix = low * (1.0 - 0.8 * s * tilt) + high * 0.8 * s * tilt
    pos = np.linspace(0.0, 1.0, n)
    env = np.sin(np.pi * np.minimum(1.0, pos / 0.9) ** 0.7) ** 1.5
    grain = 1.0 + 0.35 * fft_filter(rng.normal(size=n), lp=60) / 0.02
    x = mix * env * np.clip(grain, 0.4, 1.6) * raised_attack(n, 8.0)
    return x / (np.max(np.abs(x)) + 1e-9)


def card_snap(rng: np.random.Generator, depth: float = 1.0) -> np.ndarray:
    """A card flicked or turned over: a papery snap and a soft tap."""
    n = ms(100)
    tt = tvec(n)
    burst = fft_filter(rng.normal(size=n), lp=3300, hp=600, order=3) * np.exp(-tt / 0.005)
    tap = np.sin(2 * np.pi * 340.0 * depth * tt) * np.exp(-tt / 0.018) * 0.55
    tail = fft_filter(rng.normal(size=n), lp=2200, hp=450, order=3) * np.exp(-tt / 0.03) * 0.12
    x = (burst + tap + tail) * raised_attack(n, 2.5)
    return x / (np.max(np.abs(x)) + 1e-9)


def riffle(rng: np.random.Generator, dur_ms: float = 720) -> np.ndarray:
    """A deck riffled: many tiny paper grains under a rising and falling swell."""
    out = blank(dur_ms + 60)
    count = 34
    for i in range(count):
        at = (i / count) ** 0.9 * dur_ms * rng.uniform(0.95, 1.05)
        n = ms(rng.uniform(6, 12))
        g = fft_filter(rng.normal(size=n), lp=2900, hp=800, order=3) * np.hanning(n)
        pos = at / dur_ms
        place(out, g, at, np.sin(np.pi * min(1.0, pos)) ** 0.8 * rng.uniform(0.5, 1.0))
    place(out, felt_thud(150, 80, 22), 40, 0.25)
    place(out, felt_thud(140, 80, 22), dur_ms - 40, 0.3)
    return out / (np.max(np.abs(out)) + 1e-9)


# --------------------------------------------------------------------------- the room


def _room_ir() -> np.ndarray:
    rng = np.random.default_rng(20261108)
    n = ms(560)
    tt = tvec(n)
    noise = rng.normal(size=n)
    low = fft_filter(noise, lp=1800)
    high = fft_filter(noise, hp=1800, lp=5200)
    ir = low * np.exp(-tt * 6.91 / 0.55) + 0.55 * high * np.exp(-tt * 6.91 / 0.24)
    for at, g in ((7, 0.55), (13, 0.38), (23, 0.30), (31, 0.22)):
        ir[ms(at)] += g * np.abs(ir).max()
    ir = np.concatenate([np.zeros(ms(8)), ir])[:n]
    return ir / np.sqrt(np.sum(ir ** 2))


ROOM = _room_ir()


def in_room(x: np.ndarray, wet: float) -> np.ndarray:
    """One small damped room for everything, so all the sounds seem to be in the same place."""
    size = 1 << int(np.ceil(np.log2(len(x) + len(ROOM))))
    tail = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ROOM, size), size)[: len(x) + len(ROOM)]
    out = np.zeros(len(tail))
    out[: len(x)] += x
    out += wet * tail * (np.sqrt(np.sum(x ** 2)) / (np.sqrt(np.sum(tail ** 2)) + 1e-9))
    return out


# --------------------------------------------------------------------------- finishing


def momentary_rms_db(x: np.ndarray, window_ms: float = 200) -> float:
    w = ms(window_ms)
    if len(x) <= w:
        return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
    sq = np.convolve(x ** 2, np.ones(w) / w, mode="valid")
    return 10 * np.log10(np.max(sq) + 1e-12)


def finish(x: np.ndarray, loud_db: float, wet: float, name: str = "?") -> np.ndarray:
    """Room, tidy up, set the level by its loudest 200 ms and keep the peaks under -4 dBFS."""
    dry_tail = np.max(np.abs(x[-ms(20):])) / (np.max(np.abs(x)) + 1e-12)
    if dry_tail > 10 ** (-40 / 20):
        raise ValueError(f"{name}: the dry sound is cut off while it still rings (tail at {20 * np.log10(dry_tail):.0f} dB): that is a click")
    x = in_room(x, wet)
    x = fft_filter(x, hp=55.0, lp=6200.0, order=4)
    x -= np.mean(x)
    peak = np.max(np.abs(x)) + 1e-12
    keep = np.where(np.abs(x) > peak * 10 ** (-60 / 20))[0]
    x = x[: keep[-1] + 1] if len(keep) else x
    fade = min(ms(18), len(x) // 2)
    x[-fade:] *= np.linspace(1.0, 0.0, fade) ** 2
    x[: ms(1)] *= np.linspace(0.0, 1.0, ms(1))
    x *= 10 ** ((loud_db - momentary_rms_db(x)) / 20)
    ceiling = 10 ** (-4 / 20)
    if np.max(np.abs(x)) > ceiling:
        x = ceiling * np.tanh(x / ceiling * 0.9) / np.tanh(0.9)
        x *= min(1.0, ceiling / (np.max(np.abs(x)) + 1e-12))
    return x


SR_OUT = SR // 2  # nothing is above 6.2 kHz (the master low-pass), so 22.05 kHz keeps all of it at half the size


def write_wav(name: str, x: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    x = x[::2]
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR_OUT)
        w.writeframes(pcm.tobytes())


# --------------------------------------------------------------------------- the cues


def _tone_cue(notes: list[tuple[str, float, float, float, float]], extra: np.ndarray | None = None, dur: float = 1400, seed: str = "t") -> np.ndarray:
    """notes = (name, at_ms, tau_ms, gain, bright)"""
    out = blank(dur)
    for i, (name, at, tau, gain, bright) in enumerate(notes):
        place(out, mallet(NOTE[name], dur_ms=dur - at, tau_ms=tau, bright=bright, seed=f"{seed}{i}"), at, gain)
    if extra is not None:
        place(out, extra, 0)
    return out


def cue_turn() -> np.ndarray:
    # Your turn: three rising notes (A D F#), a low D underneath. Clear, round, unhurried.
    out = _tone_cue(
        [("A4", 0, 230, 0.9, 0.8), ("D5", 125, 250, 0.95, 0.8), ("F#5", 250, 420, 1.0, 0.75)],
        dur=1500,
        seed="turn",
    )
    place(out, mallet(NOTE["D3"], dur_ms=900, tau_ms=300, bright=0.3, seed="turn-sub"), 0, 0.35)
    return out


def cue_check(rng) -> np.ndarray:
    out = blank(260)
    place(out, knock(rng, 1.0), 0)
    place(out, knock(rng, 0.78), 118)
    return out


def cue_call(rng, variant: int) -> np.ndarray:
    return stack(rng, hits=2 + variant % 2, spread_ms=34 + 8 * variant, strength=1.0, thud=0.45, pitch=1.0 + 0.04 * (variant - 2))


def cue_raise(rng, variant: int) -> np.ndarray:
    out = blank(380)
    place(out, stack(rng, hits=6, spread_ms=95 + 20 * variant, strength=1.0, thud=0.55, pitch=0.96 + 0.06 * variant), 0)
    place(out, stack(rng, hits=3, spread_ms=40, strength=0.8, thud=0.3, pitch=1.04), 150 + 20 * variant)
    return out


def cue_all_in(rng) -> np.ndarray:
    out = blank(1800)
    at = 0.0
    for i in range(15):
        place(out, chip(rng, 0.5 + 0.5 * min(1.0, i / 8), rng.uniform(0.9, 1.12)), at, 1.0)
        at += rng.uniform(22, 52) - 1.2 * i
    for t_at in (120, 330):
        place(out, felt_thud(120, 120, 34), t_at, 0.7)
    place(out, pad([NOTE["D2"] * 2, NOTE["A2"] * 2], 1400, 380, 520, seed="allin-pad"), 0, 0.5)
    place(out, mallet(NOTE["D4"], dur_ms=1100, tau_ms=420, bright=0.6, seed="allin-note"), 640, 0.45)
    return out


def cue_fold(rng) -> np.ndarray:
    out = blank(260)
    place(out, card_slide(rng, 190, tilt=0.7), 0, 0.9)
    place(out, felt_thud(210, 50, 14), 178, 0.12)
    return out


def cue_deal(rng) -> np.ndarray:
    out = blank(260)
    place(out, card_slide(rng, 70, tilt=1.0), 0, 0.7)
    place(out, card_snap(rng, 1.0), 40, 0.6)
    place(out, card_slide(rng, 70, tilt=1.0), 95, 0.6)
    place(out, card_snap(rng, 1.1), 135, 0.55)
    return out


def cue_shuffle(rng) -> np.ndarray:
    return riffle(rng, 720)


def cue_flop(rng) -> np.ndarray:
    out = blank(420)
    for i, at in enumerate((0, 100, 200)):
        place(out, card_snap(rng, 0.95 + 0.07 * i), at, 0.85)
    place(out, felt_thud(160, 120, 30), 0, 0.12)
    return out


def cue_street(rng) -> np.ndarray:
    out = blank(300)
    place(out, card_slide(rng, 50, tilt=0.8), 0, 0.4)
    place(out, card_snap(rng, 0.85), 40, 0.9)
    place(out, felt_thud(150, 120, 32), 40, 0.16)
    return out


def cue_reveal(rng) -> np.ndarray:
    out = blank(520)
    place(out, card_snap(rng, 0.9), 0, 0.7)
    place(out, card_snap(rng, 1.0), 85, 0.7)
    place(out, mallet(NOTE["D3"], dur_ms=450, tau_ms=180, bright=0.3, seed="reveal"), 40, 0.16)
    return out


def cue_win(rng) -> np.ndarray:
    # Won the pot: D F# A D rising and settling, a warm bed, a few chips gathering underneath.
    out = _tone_cue(
        [("D5", 0, 380, 0.9, 0.9), ("F#5", 105, 420, 0.9, 0.9), ("A5", 210, 520, 0.95, 0.85), ("D6", 330, 760, 0.85, 0.7)],
        dur=2200,
        seed="win",
    )
    place(out, pad([NOTE["D4"], NOTE["A4"]], 1900, 160, 650, seed="win-pad"), 80, 0.35)
    for i, at in enumerate((420, 500, 590, 690)):
        place(out, chip(rng, 0.4, 1.0 + 0.04 * i), at)
    return out


def cue_pot_won(rng) -> np.ndarray:
    # Somebody else won: the chips are drawn in, one soft note.
    out = blank(800)
    place(out, stack(rng, hits=5, spread_ms=170, strength=0.8, thud=0.4, pitch=0.97), 0)
    place(out, mallet(NOTE["A4"], dur_ms=640, tau_ms=260, bright=0.6, seed="pot"), 120, 0.55)
    return out


def cue_out() -> np.ndarray:
    # Out of the game: three falling notes, soft, no drama.
    return _tone_cue(
        [("A4", 0, 330, 0.85, 0.5), ("F#4", 180, 360, 0.85, 0.5), ("D4", 370, 620, 0.9, 0.45)],
        dur=1700,
        seed="out",
    )


def cue_game_won(rng) -> np.ndarray:
    out = _tone_cue(
        [
            ("D4", 0, 420, 0.8, 0.8), ("A4", 140, 420, 0.8, 0.8), ("D5", 280, 480, 0.85, 0.8),
            ("F#5", 420, 540, 0.85, 0.8), ("A5", 560, 700, 0.9, 0.75), ("D6", 720, 1100, 0.9, 0.65),
        ],
        dur=3400,
        seed="gwon",
    )
    place(out, pad([NOTE["D3"], NOTE["A3"], NOTE["D4"]], 3000, 320, 1100, seed="gwon-pad"), 0, 0.45)
    for i in range(10):
        place(out, chip(rng, 0.32, rng.uniform(0.95, 1.08)), 900 + 70 * i + rng.uniform(0, 25))
    return out


def cue_level_up() -> np.ndarray:
    return _tone_cue([("E5", 0, 360, 0.85, 1.25), ("A5", 135, 560, 0.9, 1.15)], dur=1300, seed="lvl")


def cue_join() -> np.ndarray:
    return _tone_cue([("A4", 0, 230, 0.85, 0.7), ("D5", 95, 300, 0.85, 0.7)], dur=800, seed="join")


def cue_leave() -> np.ndarray:
    return _tone_cue([("D5", 0, 220, 0.7, 0.55), ("A4", 95, 330, 0.75, 0.5)], dur=850, seed="leave")


# name -> (builder, momentary loudness in dBFS, room amount, short description for the audition page)
def build() -> dict[str, tuple[np.ndarray, str]]:
    r = rng_for
    spec: dict[str, tuple[object, float, float, str]] = {
        "turn": (cue_turn, -17.0, 0.22, "Your turn: A, D, F# rising over a low D."),
        "check": (lambda: cue_check(r("check")), -21.0, 0.10, "Check: two knuckle taps on felt."),
        "call_1": (lambda: cue_call(r("call1"), 1), -21.0, 0.12, "Call or bet: a few chips set down (variant 1)."),
        "call_2": (lambda: cue_call(r("call2"), 2), -21.0, 0.12, "Call or bet (variant 2)."),
        "call_3": (lambda: cue_call(r("call3"), 3), -21.0, 0.12, "Call or bet (variant 3)."),
        "raise_1": (lambda: cue_raise(r("raise1"), 1), -19.5, 0.13, "Raise: a bigger stack of chips (variant 1)."),
        "raise_2": (lambda: cue_raise(r("raise2"), 2), -19.5, 0.13, "Raise (variant 2)."),
        "all_in": (lambda: cue_all_in(r("allin")), -18.0, 0.18, "All in: a long cascade of chips on a low swell."),
        "fold": (lambda: cue_fold(r("fold")), -24.0, 0.08, "Fold: a card slid away."),
        "deal": (lambda: cue_deal(r("deal")), -23.0, 0.09, "Your two cards arrive."),
        "shuffle": (lambda: cue_shuffle(r("shuffle")), -23.0, 0.10, "New hand: the deck is riffled."),
        "flop": (lambda: cue_flop(r("flop")), -22.0, 0.10, "Flop: three cards turned over."),
        "street": (lambda: cue_street(r("street")), -22.0, 0.10, "Turn or river: one card turned over."),
        "reveal": (lambda: cue_reveal(r("reveal")), -22.0, 0.12, "Showdown: hands turned over."),
        "win": (lambda: cue_win(r("win")), -18.0, 0.28, "You won the pot: D, F#, A, D rising, chips gathered."),
        "pot_won": (lambda: cue_pot_won(r("potwon")), -22.0, 0.14, "Somebody won: chips drawn in, one soft note."),
        "out": (cue_out, -20.0, 0.25, "You are out: three falling notes."),
        "game_won": (lambda: cue_game_won(r("gamewon")), -18.0, 0.30, "You won the game: a long rising arpeggio and chips."),
        "level_up": (cue_level_up, -20.0, 0.22, "Blinds go up: two soft bell notes."),
        "join": (cue_join, -21.0, 0.18, "Someone sat down: A then D."),
        "leave": (cue_leave, -22.0, 0.18, "Someone left: D then A."),
    }
    result = {}
    for name, (builder, loud, wet, text) in spec.items():
        result[name] = (finish(builder(), loud, wet, name), text)
    return result


def write_audition(items: dict[str, tuple[np.ndarray, str]]) -> None:
    rows = []
    for name, (x, text) in items.items():
        rows.append(
            f'<tr><td><button onclick="document.getElementById(\'a-{name}\').currentTime=0;document.getElementById(\'a-{name}\').play()">play</button>'
            f'<audio id="a-{name}" src="../../app/assets/sounds/{name}.wav" preload="auto"></audio></td>'
            f"<td><code>{name}</code></td><td>{len(x) / SR:.2f} s</td><td>{html.escape(text)}</td></tr>"
        )
    AUDITION.write_text(
        "<!doctype html><meta charset=utf-8><title>Poker Credits sounds</title>"
        "<style>body{font:16px/1.4 system-ui,sans-serif;background:#f1e9d6;color:#17130f;margin:2rem auto;max-width:48rem;padding:0 1rem}"
        "table{border-collapse:collapse;width:100%}td{border-bottom:1px solid #17130f33;padding:.45rem .6rem}"
        "button{font:inherit;background:#17130f;color:#f1e9d6;border:0;padding:.3rem .9rem;cursor:pointer}</style>"
        "<h1>Poker Credits sounds</h1><p>Original sounds made by <code>tool/sounds/make_sounds.py</code>. "
        "Turn the volume to a normal level and listen to them one after another, then together.</p>"
        f"<table>{''.join(rows)}</table>",
        encoding="utf-8",
    )


def main() -> None:
    items = build()
    for name, (x, _text) in items.items():
        write_wav(name, x)
    write_audition(items)
    total = sum(len(x[::2]) for x, _ in items.values()) * 2
    print(f"wrote {len(items)} sounds, {total / 1024:.0f} KiB of audio, to {OUT}")


if __name__ == "__main__":
    main()
