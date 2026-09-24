"""Original combat SFX for Luta — procedural, no sampled libraries."""

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
    gain = 0.92 / peak if peak > 1e-6 else 1.0
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


def whoosh(
    duration: float,
    f0: float,
    f1: float,
    seed: int,
    body: float = 0.35,
) -> list[float]:
    n = int(SR * duration)
    lp = OnePole(f0)
    hp = OnePole(max(180.0, f0 * 0.35))
    out: list[float] = []
    state = seed
    for i in range(n):
        t = i / SR
        u = t / duration
        cutoff = f0 + (f1 - f0) * (u ** 0.65)
        lp = OnePole(cutoff) if i == 0 else lp
        if i % 64 == 0:
            lp = OnePole(cutoff)
        grit, state = noise(state)
        air = hp.hp(lp.lp(grit))
        sweep = math.sin(2 * math.pi * (f0 + (f1 - f0) * u) * t) * 0.12
        e = env(t, duration, 0.008, duration * 0.55) * math.exp(-3.2 * u)
        out.append(math.tanh((air * 1.4 + sweep) * e * (0.55 + body)))
    return out


def impact(
    duration: float,
    thud: float,
    crack: float,
    slap: float,
    seed: int,
) -> list[float]:
    n = int(SR * duration)
    hp = OnePole(900.0)
    lp = OnePole(420.0)
    out: list[float] = []
    state = seed
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        sub = math.sin(2 * math.pi * thud * t) * math.exp(-18.0 * t)
        mid = math.sin(2 * math.pi * (thud * 2.6 - 40 * t) * t) * math.exp(-22.0 * t)
        click = math.sin(2 * math.pi * crack * t) * math.exp(-70.0 * t)
        flesh = lp.lp(nse) * math.exp(-28.0 * t)
        leather = hp.hp(nse) * math.exp(-55.0 * t)
        transient = (sub * 0.72 + mid * 0.38 + click * 0.22 + flesh * slap + leather * 0.28)
        out.append(math.tanh(transient * env(t, duration, 0.0015, duration * 0.7) * 1.35))
    return out


def land(duration: float = 0.16) -> list[float]:
    n = int(SR * duration)
    lp = OnePole(280.0)
    out: list[float] = []
    state = 91
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        dust = lp.lp(nse) * math.exp(-22 * t)
        heel = math.sin(2 * math.pi * 90 * t) * math.exp(-28 * t)
        out.append(math.tanh((heel * 0.7 + dust * 0.55) * env(t, duration, 0.003, 0.08)))
    return out


def hurt(duration: float = 0.28) -> list[float]:
    n = int(SR * duration)
    lp = OnePole(340.0)
    out: list[float] = []
    state = 203
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        body = math.sin(2 * math.pi * (110 - 35 * t) * t) * math.exp(-14 * t)
        grunt = lp.lp(nse) * math.exp(-9 * t) * (0.55 + 0.45 * math.sin(2 * math.pi * 18 * t))
        out.append(math.tanh((body * 0.75 + grunt * 0.5) * env(t, duration, 0.004, 0.14)))
    return out


def ko(duration: float = 0.55) -> list[float]:
    n = int(SR * duration)
    lp = OnePole(160.0)
    out: list[float] = []
    state = 11
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        boom = math.sin(2 * math.pi * (52 - 12 * t) * t) * math.exp(-6.5 * t)
        body = math.sin(2 * math.pi * 96 * t) * math.exp(-10 * t)
        rumble = lp.lp(nse) * math.exp(-5.5 * t)
        slap = nse * math.exp(-40 * t) * 0.4
        out.append(math.tanh((boom * 0.85 + body * 0.4 + rumble * 0.45 + slap) * env(t, duration, 0.003, 0.22)))
    return out


def mix(*layers: list[float]) -> list[float]:
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out


def main() -> None:
    os.makedirs(RAW, exist_ok=True)
    files = {
        "swing_jab.wav": whoosh(0.13, 2200, 700, 3, 0.22),
        "swing_kick.wav": whoosh(0.17, 1400, 380, 17, 0.4),
        "swing_dash.wav": mix(whoosh(0.24, 1800, 320, 29, 0.5), whoosh(0.20, 900, 220, 31, 0.25)),
        "swing_jump.wav": whoosh(0.18, 600, 1900, 41, 0.28),
        "swing_dive.wav": whoosh(0.16, 1600, 280, 53, 0.45),
        "hit_light.wav": impact(0.18, 68, 2100, 0.42, 7),
        "hit_mid.wav": impact(0.22, 54, 1650, 0.55, 19),
        "hit_heavy.wav": impact(0.28, 42, 1200, 0.7, 37),
        "hurt.wav": hurt(),
        "ko.wav": ko(),
        "land.wav": land(),
    }
    for name, samples in files.items():
        path = os.path.join(RAW, name)
        write_wav(path, samples)
        print(f"{name}: {os.path.getsize(path)} bytes")


if __name__ == "__main__":
    main()
