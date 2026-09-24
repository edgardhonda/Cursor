"""Generate original SFX for Cavando."""

from __future__ import annotations

import math
import os
import struct
import wave

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT_DIR = os.path.join(ROOT, "assets", "sounds")
ANDROID_RAW = os.path.join(ROOT, "android", "app", "src", "main", "res", "raw")


def write_wav(path: str, samples: list[float], sr: int = SR) -> None:
    frames = bytearray()
    for sample in samples:
        value = max(-1.0, min(1.0, sample))
        frames += struct.pack("<h", int(value * 32767))
    with wave.open(path, "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sr)
        wav.writeframes(frames)


def note(freq: float, t: float) -> float:
    return (
        math.sin(2 * math.pi * freq * t) * 0.72
        + math.sin(2 * math.pi * freq * 2 * t) * 0.18
        + math.sin(2 * math.pi * freq * 3 * t) * 0.06
    )


def env(t: float, dur: float, a: float = 0.02, r: float = 0.22) -> float:
    if t < 0 or t > dur:
        return 0.0
    attack = min(1.0, t / a) if a > 0 else 1.0
    release = min(1.0, (dur - t) / r) if r > 0 else 1.0
    return attack * release


def noise(state: int) -> tuple[float, int]:
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF
    return state / 0x7FFFFFFF * 2 - 1, state


def make_success(duration: float = 2.15) -> list[float]:
    n = int(SR * duration)
    out = [0.0] * n
    melody = [
        (523.25, 0.00, 0.22),
        (659.25, 0.18, 0.22),
        (783.99, 0.36, 0.24),
        (1046.50, 0.54, 0.42),
        (1318.51, 0.88, 0.28),
        (1046.50, 1.12, 0.85),
    ]
    bass = [
        (130.81, 0.00, 0.70),
        (196.00, 0.54, 0.70),
        (261.63, 1.12, 0.90),
    ]
    for freq, start, dur in melody + bass:
        volume = 0.28 if freq < 300 else 0.42
        for i in range(n):
            t = i / SR - start
            e = env(t, dur)
            if e <= 0:
                continue
            out[i] += note(freq, max(0.0, t)) * e * volume
    return [math.tanh(s * 1.15) * 0.9 for s in out]


def make_dig(duration: float = 0.16) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 41
    for i in range(n):
        t = i / SR
        grit, state = noise(state)
        rumble = math.sin(2 * math.pi * (90 + 40 * t) * t)
        scrape = math.sin(2 * math.pi * (240 - 80 * t) * t)
        sample = rumble * 0.35 + scrape * 0.22 + grit * 0.55 * math.exp(-10 * t)
        out.append(math.tanh(sample * env(t, duration, 0.008, 0.08)) * 0.72)
    return out


def make_eat(duration: float = 0.32) -> list[float]:
    n = int(SR * duration)
    out = [0.0] * n
    bites = [(0.00, 220.0), (0.12, 180.0)]
    state = 13
    for start, freq in bites:
        for i in range(n):
            t = i / SR - start
            if t < 0 or t > 0.14:
                continue
            pop, state = noise(state)
            chomp = math.sin(2 * math.pi * (freq - 70 * t) * max(t, 0))
            out[i] += (chomp * 0.7 + pop * 0.18) * env(t, 0.14, 0.006, 0.07)
    return [math.tanh(s) * 0.8 for s in out]


def make_bump(duration: float = 0.24) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 77
    for i in range(n):
        t = i / SR
        thud = math.sin(2 * math.pi * (140 - 55 * t) * t)
        clang = math.sin(2 * math.pi * 520 * t) * math.exp(-14 * t)
        hit, state = noise(state)
        sample = thud * 0.7 + clang * 0.22 + hit * 0.28 * math.exp(-12 * t)
        out.append(math.tanh(sample * env(t, duration, 0.004, 0.12)) * 0.86)
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(ANDROID_RAW, exist_ok=True)
    files = {
        "dig.wav": make_dig(),
        "eat.wav": make_eat(),
        "bump.wav": make_bump(),
    }
    # success.wav is a custom recording and must not be regenerated.
    for name, samples in files.items():
        for folder in (OUT_DIR, ANDROID_RAW):
            path = os.path.join(folder, name)
            write_wav(path, samples)
        print(f"{name}: {os.path.getsize(os.path.join(OUT_DIR, name))} bytes")


if __name__ == "__main__":
    main()
