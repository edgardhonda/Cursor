"""Original goo/cavity SFX for Dentista — procedural, no sampled libraries."""

from __future__ import annotations

import math
import os
import struct
import wave

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..")
RAW = os.path.join(ROOT, "app", "src", "main", "res", "raw")


def write_wav(path: str, samples: list[float]) -> None:
    peak = max((abs(s) for s in samples), default=1.0)
    gain = 0.90 / peak if peak > 1e-6 else 1.0
    frames = bytearray()
    for sample in samples:
        value = max(-1.0, min(1.0, sample * gain))
        frames += struct.pack("<h", int(value * 32767))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(frames)


def noise(state: int) -> tuple[float, int]:
    state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
    return (state / 0xFFFFFFFF) * 2.0 - 1.0, state


def env(t: float, dur: float, a: float, r: float) -> float:
    if t < 0.0 or t > dur:
        return 0.0
    attack = min(1.0, t / a) if a > 0 else 1.0
    release = min(1.0, (dur - t) / r) if r > 0 else 1.0
    return attack * release


class OnePole:
    def __init__(self, cutoff: float) -> None:
        x = math.exp(-2.0 * math.pi * cutoff / SR)
        self.a = 1.0 - x
        self.y = 0.0

    def lp(self, x: float) -> float:
        self.y += self.a * (x - self.y)
        return self.y

    def hp(self, x: float) -> float:
        return x - self.lp(x)


def ui_click() -> list[float]:
    n = int(SR * 0.09)
    out: list[float] = []
    state = 13
    lp = OnePole(1900.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        tick = math.sin(2 * math.pi * 1560 * t) * math.exp(-50 * t)
        wood = lp.lp(nse) * math.exp(-34 * t)
        out.append(math.tanh((tick * 0.7 + wood * 0.32) * env(t, 0.09, 0.001, 0.05)))
    return out


def slurp() -> list[float]:
    n = int(SR * 0.32)
    out: list[float] = []
    state = 44
    lp = OnePole(500.0)
    for i in range(n):
        t = i / SR
        u = t / 0.32
        nse, state = noise(state)
        wet = lp.lp(nse)
        slide = math.sin(2 * math.pi * (120 + 260 * u) * t) * math.exp(-3.5 * u)
        e = env(t, 0.32, 0.02, 0.14)
        out.append(math.tanh((wet * 0.55 + slide * 0.6) * e))
    return out


def splat() -> list[float]:
    n = int(SR * 0.22)
    out: list[float] = []
    state = 71
    lp = OnePole(280.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        thud = math.sin(2 * math.pi * 70 * t) * math.exp(-18 * t)
        body = lp.lp(nse) * math.exp(-12 * t)
        out.append(math.tanh((thud * 0.7 + body * 0.55) * env(t, 0.22, 0.002, 0.10)))
    return out


def chew() -> list[float]:
    n = int(SR * 0.16)
    out: list[float] = []
    state = 91
    lp = OnePole(360.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        crunch = math.sin(2 * math.pi * 210 * t) * math.exp(-22 * t)
        grit = lp.lp(nse) * math.exp(-14 * t)
        out.append(math.tanh((crunch * 0.55 + grit * 0.5) * env(t, 0.16, 0.002, 0.07)))
    return out


def brush() -> list[float]:
    n = int(SR * 0.12)
    out: list[float] = []
    state = 21
    hp = OnePole(900.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        hiss = hp.hp(nse) * math.exp(-16 * t)
        sweep = math.sin(2 * math.pi * (900 + 400 * t / 0.12) * t) * math.exp(-14 * t)
        out.append(math.tanh((hiss * 0.5 + sweep * 0.4) * env(t, 0.12, 0.004, 0.05)))
    return out


def clean() -> list[float]:
    n = int(SR * 0.48)
    out: list[float] = []
    notes = ((0.00, 659.0), (0.08, 784.0), (0.16, 988.0))
    for i in range(n):
        t = i / SR
        s = 0.0
        for start, freq in notes:
            if t < start:
                continue
            tt = t - start
            s += math.sin(2 * math.pi * freq * tt) * math.exp(-6.0 * tt)
        e = env(t, 0.48, 0.006, 0.18)
        out.append(math.tanh(s * 0.42 * e))
    return out


def crack() -> list[float]:
    n = int(SR * 0.35)
    out: list[float] = []
    state = 111
    hp = OnePole(700.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        snap = math.sin(2 * math.pi * 140 * t) * math.exp(-14 * t)
        break_ = hp.hp(nse) * math.exp(-10 * t)
        out.append(math.tanh((snap * 0.7 + break_ * 0.5) * env(t, 0.35, 0.001, 0.16)))
    return out


def lose() -> list[float]:
    n = int(SR * 0.9)
    out: list[float] = []
    notes = ((0.00, 392.0), (0.18, 311.0), (0.38, 247.0))
    for i in range(n):
        t = i / SR
        s = 0.0
        for start, freq in notes:
            if t < start:
                continue
            tt = t - start
            s += math.sin(2 * math.pi * freq * tt) * math.exp(-3.2 * tt)
        e = env(t, 0.9, 0.02, 0.35)
        out.append(math.tanh(s * 0.45 * e))
    return out


def main() -> None:
    os.makedirs(RAW, exist_ok=True)
    write_wav(os.path.join(RAW, "ui_click.wav"), ui_click())
    write_wav(os.path.join(RAW, "slurp.wav"), slurp())
    write_wav(os.path.join(RAW, "splat.wav"), splat())
    write_wav(os.path.join(RAW, "chew.wav"), chew())
    write_wav(os.path.join(RAW, "brush.wav"), brush())
    write_wav(os.path.join(RAW, "clean.wav"), clean())
    write_wav(os.path.join(RAW, "crack.wav"), crack())
    write_wav(os.path.join(RAW, "lose.wav"), lose())
    print("wrote", RAW)


if __name__ == "__main__":
    main()
