"""Generate SFX for Mapa: footsteps, bump, victory."""

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


def make_step(duration: float = 0.16) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 11
    for i in range(n):
        t = i / SR
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        noise = state / 0x7FFFFFFF * 2 - 1
        thump = math.sin(2 * math.pi * 90 * t) * math.exp(-18 * t)
        out.append(math.tanh(thump * 0.9 + noise * math.exp(-25 * t) * 0.35) * 0.8)
    return out


def make_bump(duration: float = 0.35) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 5
    for i in range(n):
        t = i / SR
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        noise = (state / 0xFFFFFFFF) * 2 - 1
        hit = math.sin(2 * math.pi * (220 - 120 * t) * t)
        out.append(math.tanh(hit * math.exp(-8 * t) + noise * math.exp(-10 * t) * 0.7) * 0.95)
    return out


def make_victory() -> list[float]:
    notes = [392.0, 523.25, 659.25, 784.0, 1046.5]
    out: list[float] = []
    for freq in notes:
        note_n = int(SR * 0.14)
        for i in range(note_n):
            t = i / SR
            tone = (
                0.55 * math.sin(2 * math.pi * freq * t)
                + 0.25 * math.sin(2 * math.pi * freq * 2 * t)
            )
            out.append(tone * env(i, note_n, 0.01, 0.12, 0.55, 0.35) * 0.7)
        out.extend(0.0 for _ in range(int(SR * 0.03)))
    return out


def make_tick(duration: float = 0.05) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        click = math.sin(2 * math.pi * 1400 * t) * math.exp(-90 * t)
        out.append(math.tanh(click * 1.4) * 0.55)
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(ANDROID_RAW, exist_ok=True)
    files = {
        'step.wav': make_step(),
        'bump.wav': make_bump(),
        'victory.wav': make_victory(),
        'tick.wav': make_tick(),
    }
    for name, samples in files.items():
        write_wav(os.path.join(OUT_DIR, name), samples)
        write_wav(os.path.join(ANDROID_RAW, name), samples)
        print(f'{name}: {os.path.getsize(os.path.join(OUT_DIR, name))} bytes')


if __name__ == '__main__':
    main()
