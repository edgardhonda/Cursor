"""Generate original cartoon SFX for Sapos."""

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


def make_tongue(duration: float = 0.22) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        f = 420 + 980 * math.exp(-10 * t)
        tone = math.sin(2 * math.pi * f * t)
        wet = math.sin(2 * math.pi * (180 + 40 * t) * t) * math.exp(-6 * t)
        out.append(math.tanh((tone * 0.55 + wet * 0.5) * env(i, n, 0.01, 0.12, 0.4, 0.4)) * 0.85)
    return out


def make_gulp(duration: float = 0.2) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        f = 140 * math.exp(-4 * t)
        pop = math.sin(2 * math.pi * f * t)
        click = math.sin(2 * math.pi * 520 * t) * math.exp(-18 * t)
        out.append(math.tanh(pop * 0.8 + click * 0.4) * env(i, n, 0.02, 0.2, 0.45, 0.4) * 0.9)
    return out


def make_boom(duration: float = 0.55) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 3
    for i in range(n):
        t = i / SR
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        noise = state / 0x7FFFFFFF * 2 - 1
        boom = math.sin(2 * math.pi * (70 + 30 * math.exp(-5 * t)) * t)
        out.append(math.tanh(noise * math.exp(-6 * t) * 0.6 + boom * math.exp(-3 * t)) * 0.95)
    return out


def make_ribbit() -> list[float]:
    notes = [220.0, 160.0, 240.0]
    out: list[float] = []
    for freq in notes:
        note_n = int(SR * 0.09)
        for i in range(note_n):
            t = i / SR
            wobble = freq * (1 + 0.08 * math.sin(2 * math.pi * 18 * t))
            tone = math.sin(2 * math.pi * wobble * t)
            sq = 1.0 if tone >= 0 else -0.5
            out.append((0.55 * tone + 0.3 * sq) * env(i, note_n, 0.02, 0.15, 0.5, 0.35) * 0.7)
        out.extend(0.0 for _ in range(int(SR * 0.04)))
    return out


def make_buzz(duration: float = 0.28) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        f = 380 + 40 * math.sin(2 * math.pi * 55 * t)
        buzz = math.sin(2 * math.pi * f * t)
        sq = 1.0 if buzz >= 0 else -1.0
        out.append((0.35 * buzz + 0.4 * sq) * env(i, n, 0.02, 0.2, 0.5, 0.4) * 0.45)
    return out


def make_cheer() -> list[float]:
    notes = [523.0, 659.0, 784.0]
    out: list[float] = []
    for freq in notes:
        note_n = int(SR * 0.08)
        for i in range(note_n):
            t = i / SR
            tone = math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(2 * math.pi * freq * 2 * t)
            out.append(tone * env(i, note_n, 0.01, 0.12, 0.5, 0.4) * 0.55)
        out.extend(0.0 for _ in range(int(SR * 0.02)))
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(ANDROID_RAW, exist_ok=True)
    files = {
        'tongue.wav': make_tongue(),
        'gulp.wav': make_gulp(),
        'boom.wav': make_boom(),
        'ribbit.wav': make_ribbit(),
        'buzz.wav': make_buzz(),
        'cheer.wav': make_cheer(),
    }
    for name, samples in files.items():
        write_wav(os.path.join(OUT_DIR, name), samples)
        write_wav(os.path.join(ANDROID_RAW, name), samples)
        print(f'{name}: {os.path.getsize(os.path.join(OUT_DIR, name))} bytes')


if __name__ == '__main__':
    main()
