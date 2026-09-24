"""Generate original arcade SFX for Destruir!"""

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


def make_drag(duration: float = 0.07) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 11
    for i in range(n):
        t = i / SR
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        noise = state / 0x7FFFFFFF * 2 - 1
        tone = math.sin(2 * math.pi * (420 + 80 * t) * t) * 0.18
        out.append((noise * 0.45 + tone) * math.exp(-22 * t) * env(i, n, 0.002, 0.05, 0.35, 0.4) * 0.42)
    return out


def make_destroy(duration: float = 0.22) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 77
    for i in range(n):
        t = i / SR
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        noise = (state / 0xFFFFFFFF) * 2 - 1
        pop = math.sin(2 * math.pi * (220 - 90 * t) * t) * math.exp(-12 * t)
        crack = noise * math.exp(-20 * t)
        out.append(math.tanh(pop * 0.85 + crack * 0.55) * env(i, n, 0.005, 0.08, 0.35, 0.45) * 0.82)
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(ANDROID_RAW, exist_ok=True)
    files = {
        'drag.wav': make_drag(),
        'destroy.wav': make_destroy(),
    }
    for name, samples in files.items():
        write_wav(os.path.join(OUT_DIR, name), samples)
        write_wav(os.path.join(ANDROID_RAW, name), samples)
        print(f'{name}: {os.path.getsize(os.path.join(OUT_DIR, name))} bytes')


if __name__ == '__main__':
    main()
