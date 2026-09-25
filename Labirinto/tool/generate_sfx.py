"""Original forest maze SFX for Labirinto — procedural, no sampled libraries."""

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
    n = int(SR * 0.10)
    out: list[float] = []
    state = 19
    lp = OnePole(1800.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        tick = math.sin(2 * math.pi * 1480 * t) * math.exp(-48 * t)
        wood = lp.lp(nse) * math.exp(-32 * t)
        out.append(math.tanh((tick * 0.65 + wood * 0.4) * env(t, 0.10, 0.001, 0.05)))
    return out


def start() -> list[float]:
    n = int(SR * 0.42)
    out: list[float] = []
    for i in range(n):
        t = i / SR
        u = t / 0.42
        a = math.sin(2 * math.pi * 392 * t) * math.exp(-4.2 * u)
        b = math.sin(2 * math.pi * 523 * t) * math.exp(-3.4 * u)
        c = math.sin(2 * math.pi * 659 * t) * math.exp(-2.8 * u)
        e = env(t, 0.42, 0.012, 0.22)
        out.append(math.tanh((a * 0.45 + b * 0.4 + c * 0.35) * e))
    return out


def step() -> list[float]:
    n = int(SR * 0.13)
    out: list[float] = []
    state = 61
    lp = OnePole(320.0)
    hp = OnePole(420.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        heel = math.sin(2 * math.pi * 92 * t) * math.exp(-22 * t)
        dirt = lp.lp(nse) * math.exp(-16 * t)
        leaf = hp.hp(nse) * math.exp(-28 * t) * 0.22
        out.append(math.tanh((heel * 0.7 + dirt * 0.48 + leaf) * env(t, 0.13, 0.002, 0.06)))
    return out


def puzzle() -> list[float]:
    n = int(SR * 0.38)
    out: list[float] = []
    state = 87
    hp = OnePole(500.0)
    for i in range(n):
        t = i / SR
        u = t / 0.38
        nse, state = noise(state)
        rustle = hp.hp(nse) * math.exp(-6.5 * u)
        q = math.sin(2 * math.pi * (540 + 180 * u) * t) * math.exp(-5.0 * u)
        e = env(t, 0.38, 0.01, 0.18)
        out.append(math.tanh((rustle * 0.42 + q * 0.55) * e))
    return out


def wrong() -> list[float]:
    n = int(SR * 0.38)
    out: list[float] = []
    for i in range(n):
        t = i / SR
        u = t / 0.38
        a = math.sin(2 * math.pi * 220 * t) * math.exp(-5.5 * u)
        b = math.sin(2 * math.pi * 233 * t) * math.exp(-4.8 * u)
        e = env(t, 0.38, 0.008, 0.18)
        out.append(math.tanh((a * 0.55 + b * 0.5) * e))
    return out


def correct() -> list[float]:
    n = int(SR * 0.55)
    out: list[float] = []
    notes = ((0.00, 523.0), (0.09, 659.0), (0.18, 784.0))
    for i in range(n):
        t = i / SR
        s = 0.0
        for start, freq in notes:
            if t < start:
                continue
            tt = t - start
            s += math.sin(2 * math.pi * freq * tt) * math.exp(-5.2 * tt)
        e = env(t, 0.55, 0.008, 0.22)
        out.append(math.tanh(s * 0.42 * e))
    return out


def win() -> list[float]:
    n = int(SR * 1.15)
    out: list[float] = []
    notes = ((0.00, 392.0), (0.16, 523.0), (0.32, 659.0), (0.48, 784.0), (0.64, 1046.0))
    for i in range(n):
        t = i / SR
        s = 0.0
        for start, freq in notes:
            if t < start:
                continue
            tt = t - start
            s += math.sin(2 * math.pi * freq * tt) * math.exp(-3.4 * tt)
            s += 0.22 * math.sin(2 * math.pi * freq * 2 * tt) * math.exp(-5.0 * tt)
        e = env(t, 1.15, 0.012, 0.40)
        out.append(math.tanh(s * 0.38 * e))
    return out


def main() -> None:
    os.makedirs(RAW, exist_ok=True)
    write_wav(os.path.join(RAW, "ui_click.wav"), ui_click())
    write_wav(os.path.join(RAW, "start.wav"), start())
    write_wav(os.path.join(RAW, "step.wav"), step())
    write_wav(os.path.join(RAW, "puzzle.wav"), puzzle())
    write_wav(os.path.join(RAW, "wrong.wav"), wrong())
    write_wav(os.path.join(RAW, "correct.wav"), correct())
    write_wav(os.path.join(RAW, "win.wav"), win())
    print("wrote", RAW)


if __name__ == "__main__":
    main()
