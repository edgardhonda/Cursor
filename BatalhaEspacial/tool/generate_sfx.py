"""Generate original arcade SFX for Batalha Espacial."""

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


def make_start(duration: float = 0.35) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        sweep = math.sin(2 * math.pi * (180 + 420 * t) * t)
        out.append(sweep * math.exp(-5 * t) * env(i, n, 0.01, 0.12, 0.45, 0.4) * 0.7)
    return out


def make_alert(duration: float = 0.45) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        beep = math.sin(2 * math.pi * 880 * t) * (0.5 + 0.5 * math.sin(2 * math.pi * 12 * t))
        out.append(beep * math.exp(-4 * t) * env(i, n, 0.005, 0.08, 0.55, 0.35) * 0.65)
    return out


def make_laser(duration: float = 0.24) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 9
    for i in range(n):
        t = i / SR
        sweep = math.sin(2 * math.pi * (900 + 500 * t) * t)
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        noise = state / 0x7FFFFFFF * 2 - 1
        out.append(
            math.tanh((sweep * math.exp(-12 * t) + noise * 0.2 * math.exp(-18 * t)) * env(i, n, 0.003, 0.06, 0.4, 0.35))
            * 0.78
        )
    return out


def make_destroy(duration: float = 0.28) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 31
    for i in range(n):
        t = i / SR
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        noise = (state / 0xFFFFFFFF) * 2 - 1
        pop = math.sin(2 * math.pi * (260 - 120 * t) * t) * math.exp(-14 * t)
        out.append(math.tanh(pop * 0.85 + noise * 0.45 * math.exp(-18 * t)) * env(i, n, 0.005, 0.08, 0.35, 0.45) * 0.82)
    return out


def make_wrong(duration: float = 0.2) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        tone = math.sin(2 * math.pi * (220 - 80 * t) * t)
        out.append(tone * math.exp(-10 * t) * env(i, n, 0.005, 0.08, 0.35, 0.4) * 0.75)
    return out


def make_blast(duration: float = 0.75) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 77
    for i in range(n):
        t = i / SR
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        noise = state / 0x7FFFFFFF * 2 - 1
        rumble = math.sin(2 * math.pi * (70 - 25 * t) * t)
        boom = math.sin(2 * math.pi * 150 * t) * math.exp(-5 * t)
        out.append(
            math.tanh((rumble * 0.6 + boom * 0.5 + noise * 0.35 * math.exp(-4 * t)) * env(i, n, 0.01, 0.18, 0.45, 0.45))
            * 0.88
        )
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(ANDROID_RAW, exist_ok=True)
    files = {
        'start.wav': make_start(),
        'alert.wav': make_alert(),
        'laser.wav': make_laser(),
        'destroy.wav': make_destroy(),
        'wrong.wav': make_wrong(),
        'blast.wav': make_blast(),
    }
    for name, samples in files.items():
        write_wav(os.path.join(OUT_DIR, name), samples)
        write_wav(os.path.join(ANDROID_RAW, name), samples)
        print(f'{name}: {os.path.getsize(os.path.join(OUT_DIR, name))} bytes')


if __name__ == '__main__':
    main()
