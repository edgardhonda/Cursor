"""Generate original arcade SFX for Defender Castelo."""

from __future__ import annotations

import math
import os
import struct
import wave

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT_DIR = os.path.join(ROOT, 'assets', 'sounds')
ANDROID_RAW = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'raw')


def write_wav(path: str, samples: list[float], sr: int = SR) -> None:
    frames = bytearray()
    for sample in samples:
        value = max(-1.0, min(1.0, sample))
        frames += struct.pack('<h', int(value * 32767))
    with wave.open(path, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sr)
        wav.writeframes(frames)


def env(i: int, n: int, a=0.01, d=0.1, s=0.5, r=0.3) -> float:
    t = i / n
    if t < a:
        return t / a
    if t < a + d:
        return 1.0 - (1.0 - s) * ((t - a) / d)
    if t < 1.0 - r:
        return s
    return s * max(0.0, (1.0 - t) / r)


def make_spawn(duration: float = 0.14) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        tone = math.sin(2 * math.pi * (420 - 120 * t) * t)
        pop = math.sin(2 * math.pi * 90 * t) * math.exp(-22 * t)
        out.append(math.tanh((tone * math.exp(-10 * t) + pop * 0.7) * env(i, n, 0.005, 0.08, 0.4, 0.45)) * 0.75)
    return out


def make_shoot(duration: float = 0.22) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 3
    for i in range(n):
        t = i / SR
        sweep = 1 - t / duration
        f = 320 + 900 * sweep
        tone = 0.45 * math.sin(2 * math.pi * f * t)
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        noise = (state / 0xFFFFFFFF) * 2 - 1
        out.append(math.tanh((tone + noise * 0.25 * sweep) * env(i, n, 0.01, 0.12, 0.45, 0.35)) * 0.8)
    return out


def make_hit(duration: float = 0.28) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 17
    for i in range(n):
        t = i / SR
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        noise = state / 0x7FFFFFFF * 2 - 1
        thump = math.sin(2 * math.pi * 110 * t) * math.exp(-14 * t)
        crack = noise * math.exp(-18 * t)
        out.append(math.tanh(thump * 0.9 + crack * 0.65) * env(i, n, 0.005, 0.1, 0.35, 0.45) * 0.85)
    return out


def make_blast(duration: float = 0.9) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 99
    for i in range(n):
        t = i / SR
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        noise = (state / 0xFFFFFFFF) * 2 - 1
        rumble = math.sin(2 * math.pi * (55 - 20 * t) * t)
        boom = math.sin(2 * math.pi * 140 * t) * math.exp(-4 * t)
        out.append(
            math.tanh((rumble * 0.55 + boom * 0.45 + noise * 0.35 * math.exp(-3 * t)) * env(i, n, 0.01, 0.2, 0.5, 0.45))
            * 0.9
        )
    return out


def make_swipe(duration: float = 0.08) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 5
    for i in range(n):
        t = i / SR
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        noise = state / 0x7FFFFFFF * 2 - 1
        out.append(noise * math.exp(-35 * t) * env(i, n, 0.002, 0.05, 0.3, 0.4) * 0.35)
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(ANDROID_RAW, exist_ok=True)
    files = {
        'spawn.wav': make_spawn(),
        'shoot.wav': make_shoot(),
        'hit.wav': make_hit(),
        'blast.wav': make_blast(),
        'swipe.wav': make_swipe(),
    }
    for name, samples in files.items():
        write_wav(os.path.join(OUT_DIR, name), samples)
        write_wav(os.path.join(ANDROID_RAW, name), samples)
        print(f'{name}: {os.path.getsize(os.path.join(OUT_DIR, name))} bytes')


if __name__ == '__main__':
    main()
