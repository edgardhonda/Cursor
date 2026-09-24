"""Original cave/memory SFX for Tunel — procedural, no sampled libraries."""

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


def mix(*layers: list[float]) -> list[float]:
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out


def ui_click() -> list[float]:
    n = int(SR * 0.09)
    out: list[float] = []
    state = 11
    lp = OnePole(2200.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        tick = math.sin(2 * math.pi * 1840 * t) * math.exp(-55 * t)
        wood = lp.lp(nse) * math.exp(-40 * t)
        out.append(math.tanh((tick * 0.7 + wood * 0.35) * env(t, 0.09, 0.001, 0.05)))
    return out


def ui_ready() -> list[float]:
    n = int(SR * 0.55)
    out: list[float] = []
    state = 41
    hp = OnePole(280.0)
    lp = OnePole(900.0)
    for i in range(n):
        t = i / SR
        u = t / 0.55
        nse, state = noise(state)
        air = hp.hp(lp.lp(nse))
        sweep = math.sin(2 * math.pi * (220 + 640 * u) * t) * math.exp(-3.2 * u)
        low = math.sin(2 * math.pi * (90 + 40 * u) * t) * math.exp(-2.4 * u)
        e = env(t, 0.55, 0.02, 0.28)
        out.append(math.tanh((air * 0.55 + sweep * 0.45 + low * 0.5) * e))
    return out


def step() -> list[float]:
    n = int(SR * 0.14)
    out: list[float] = []
    state = 73
    lp = OnePole(240.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        heel = math.sin(2 * math.pi * 78 * t) * math.exp(-26 * t)
        grit = lp.lp(nse) * math.exp(-18 * t)
        out.append(math.tanh((heel * 0.72 + grit * 0.5) * env(t, 0.14, 0.002, 0.07)))
    return out


def tunnel() -> list[float]:
    n = int(SR * 0.62)
    out: list[float] = []
    state = 101
    lp = OnePole(700.0)
    hp = OnePole(180.0)
    for i in range(n):
        t = i / SR
        u = t / 0.62
        nse, state = noise(state)
        wind = hp.hp(lp.lp(nse))
        tone = math.sin(2 * math.pi * (160 - 50 * u) * t)
        echo = math.sin(2 * math.pi * (320 - 80 * u) * t) * math.exp(-2.8 * u)
        e = env(t, 0.62, 0.03, 0.32) * math.exp(-1.6 * u)
        out.append(math.tanh((wind * 0.7 + tone * 0.28 + echo * 0.22) * e))
    return out


def room() -> list[float]:
    n = int(SR * 0.22)
    out: list[float] = []
    state = 19
    lp = OnePole(320.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        thump = math.sin(2 * math.pi * 62 * t) * math.exp(-14 * t)
        dust = lp.lp(nse) * math.exp(-10 * t)
        out.append(math.tanh((thump * 0.7 + dust * 0.4) * env(t, 0.22, 0.004, 0.12)))
    return out


def treasure() -> list[float]:
    n = int(SR * 1.15)
    notes = (523.25, 659.25, 783.99, 1046.5)
    out: list[float] = []
    for i in range(n):
        t = i / SR
        s = 0.0
        for k, f in enumerate(notes):
            delay = k * 0.07
            if t < delay:
                continue
            tt = t - delay
            s += math.sin(2 * math.pi * f * tt) * math.exp(-3.1 * tt) * (0.55 - k * 0.08)
            s += math.sin(2 * math.pi * f * 2.0 * tt) * math.exp(-6.0 * tt) * 0.08
        shimmer = math.sin(2 * math.pi * 1568 * t) * math.exp(-8 * t) * 0.12
        out.append(math.tanh((s + shimmer) * env(t, 1.15, 0.01, 0.45) * 1.15))
    return out


def monster() -> list[float]:
    n = int(SR * 0.85)
    out: list[float] = []
    state = 211
    lp = OnePole(220.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        f = 70 - 18 * t + 8 * math.sin(2 * math.pi * 6 * t)
        growl = math.sin(2 * math.pi * f * t)
        grit = lp.lp(nse)
        wobble = 0.7 + 0.3 * math.sin(2 * math.pi * 9 * t)
        e = env(t, 0.85, 0.04, 0.28)
        out.append(math.tanh((growl * 0.7 + grit * 0.55) * wobble * e))
    return out


def spider() -> list[float]:
    n = int(SR * 0.7)
    out: list[float] = []
    state = 307
    hp = OnePole(1200.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        click_gate = 1.0 if (t * 28.0) % 1.0 < 0.12 else 0.0
        click = math.sin(2 * math.pi * 3100 * t) * click_gate * math.exp(-10 * t)
        scrape = hp.hp(nse) * (0.35 + 0.65 * math.sin(2 * math.pi * 14 * t))
        hiss = nse * math.exp(-2.2 * t) * 0.25
        e = env(t, 0.7, 0.01, 0.22)
        out.append(math.tanh((click * 0.55 + scrape * 0.5 + hiss) * e))
    return out


def skull() -> list[float]:
    n = int(SR * 0.72)
    out: list[float] = []
    state = 409
    hp = OnePole(800.0)
    lp = OnePole(1400.0)
    for i in range(n):
        t = i / SR
        nse, state = noise(state)
        burst = 1.0 if ((t * 11.0) % 1.0) < 0.18 else 0.15
        bone = hp.hp(lp.lp(nse)) * burst
        hollow = math.sin(2 * math.pi * (190 - 40 * t) * t) * math.exp(-5 * t)
        e = env(t, 0.72, 0.008, 0.26)
        out.append(math.tanh((bone * 0.75 + hollow * 0.4) * e))
    return out


def main() -> None:
    os.makedirs(RAW, exist_ok=True)
    files = {
        "ui_click.wav": ui_click(),
        "ui_ready.wav": ui_ready(),
        "step.wav": step(),
        "tunnel.wav": tunnel(),
        "room.wav": room(),
        "treasure.wav": treasure(),
        "monster.wav": monster(),
        "spider.wav": spider(),
        "skull.wav": skull(),
    }
    for name, samples in files.items():
        path = os.path.join(RAW, name)
        write_wav(path, samples)
        print(f"{name}: {os.path.getsize(path)} bytes")


if __name__ == "__main__":
    main()
