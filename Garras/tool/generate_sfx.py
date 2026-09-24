"""Generate original cartoon/arcade SFX for Garras."""

from __future__ import annotations

import math
import os
import struct
import wave

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT_DIR = os.path.join(ROOT, 'assets', 'sounds')
ANDROID_RAW = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'raw')

# Uma nota por cor de garra (escala maior, oitava confortável).
TAP_NOTES = [
    261.63,  # vermelho  C4
    293.66,  # azul      D4
    329.63,  # verde     E4
    349.23,  # amarelo   F4
    392.00,  # laranja   G4
    440.00,  # roxo      A4
    493.88,  # ciano     B4
    523.25,  # rosa      C5
]


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


def make_tap(freq: float, duration: float = 0.14) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        phase = 2 * math.pi * freq * t
        tone = 0.62 * math.sin(phase) + 0.18 * math.sin(phase * 2.01)
        ping = math.sin(phase * 0.5) * math.exp(-18 * t)
        out.append(math.tanh((tone + ping * 0.25) * env(i, n, 0.005, 0.08, 0.45, 0.45)) * 0.82)
    return out


def make_whoosh(duration: float = 0.26) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 7
    for i in range(n):
        t = i / SR
        sweep = math.sin(math.pi * t / duration) ** 2
        f = 180 + 480 * sweep
        tone = 0.32 * math.sin(2 * math.pi * f * t)
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        noise = (state / 0xFFFFFFFF) * 2 - 1
        out.append(
            math.tanh((tone + noise * 0.28 * sweep) * env(i, n, 0.03, 0.12, 0.5, 0.35)) * 0.55
        )
    return out


def make_snap(duration: float = 0.12) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 99
    for i in range(n):
        t = i / SR
        click = math.sin(2 * math.pi * (760 - 420 * t) * t)
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        noise = state / 0x7FFFFFFF * 2 - 1
        burst = noise * math.exp(-32 * t)
        out.append(math.tanh((click * math.exp(-16 * t) + burst * 0.65) * 1.1) * 0.75)
    return out


def make_fall(duration: float = 0.38) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        f = 640 * math.exp(-4.5 * t)
        tone = math.sin(2 * math.pi * f * t)
        thump = math.sin(2 * math.pi * 62 * t) * math.exp(-10 * (t - 0.24) ** 2) if t > 0.16 else 0
        out.append(math.tanh(tone * env(i, n, 0.01, 0.18, 0.35, 0.42) + thump * 0.85) * 0.8)
    return out


def make_miss(duration: float = 0.24) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        f = 196 - 96 * t
        tone = 0.55 * math.sin(2 * math.pi * f * t) + 0.2 * math.sin(2 * math.pi * f * 1.47 * t)
        wobble = math.sin(2 * math.pi * 7 * t) * 0.15
        out.append((tone + wobble) * env(i, n, 0.01, 0.1, 0.4, 0.48) * 0.65)
    return out


def make_chirp() -> list[float]:
    notes = [659.25, 783.99, 987.77]
    out: list[float] = []
    for freq in notes:
        note_n = int(SR * 0.08)
        for i in range(note_n):
            t = i / SR
            phase = 2 * math.pi * freq * t
            tone = 0.58 * math.sin(phase) + 0.22 * math.sin(phase * 2)
            out.append(tone * env(i, note_n, 0.01, 0.08, 0.55, 0.35) * 0.62)
        out.extend(0.0 for _ in range(int(SR * 0.025)))
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(ANDROID_RAW, exist_ok=True)

    files: dict[str, list[float]] = {
        'whoosh.wav': make_whoosh(),
        'snap.wav': make_snap(),
        'fall.wav': make_fall(),
        'miss.wav': make_miss(),
        'chirp.wav': make_chirp(),
    }
    for i, freq in enumerate(TAP_NOTES):
        files[f'tap_{i}.wav'] = make_tap(freq)

    for name, samples in files.items():
        write_wav(os.path.join(OUT_DIR, name), samples)
        write_wav(os.path.join(ANDROID_RAW, name), samples)
        print(f'{name}: {os.path.getsize(os.path.join(OUT_DIR, name))} bytes')


if __name__ == '__main__':
    main()
