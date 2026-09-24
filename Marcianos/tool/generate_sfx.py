"""Generate original sci-fi SFX inspired by classic space-opera sounds."""

from __future__ import annotations

import math
import os
import struct
import wave

SR = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
ANDROID_RAW = os.path.join(
    os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res', 'raw'
)


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


def env_adsr(
    index: int,
    total: int, *,
    attack: float = 0.01,
    decay: float = 0.08,
    sustain: float = 0.55,
    release: float = 0.25,
) -> float:
    t = index / total
    if t < attack:
        return t / attack
    if t < attack + decay:
        return 1.0 - (1.0 - sustain) * ((t - attack) / decay)
    if t < 1.0 - release:
        return sustain
    return sustain * max(0.0, (1.0 - t) / release)


def make_laser(duration: float = 0.22) -> list[float]:
    total = int(SR * duration)
    out: list[float] = []
    for i in range(total):
        t = i / SR
        phase = 2 * math.pi * (1800 / 8.5) * (1 - math.exp(-8.5 * t))
        square = 1.0 if math.sin(phase) >= 0 else -1.0
        tone = 0.55 * math.sin(phase) + 0.28 * square + 0.12 * math.sin(2 * phase)
        noise = ((i * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF * 2 - 1
        burst = math.exp(-35 * t) * 0.25 * noise
        amp = env_adsr(i, total, attack=0.005, decay=0.05, sustain=0.35, release=0.45)
        out.append((tone * amp + burst) * 0.85)
    return out


def make_explosion(duration: float = 0.85) -> list[float]:
    total = int(SR * duration)
    out: list[float] = []
    state = 1
    for i in range(total):
        t = i / SR
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        noise = state / 0x7FFFFFFF * 2 - 1
        boom = math.sin(2 * math.pi * (55 + 40 * math.exp(-6 * t)) * t)
        rumble = math.sin(2 * math.pi * 28 * t) * math.exp(-2.2 * t)
        crack = noise * math.exp(-7 * t)
        body = 0.55 * crack + 0.7 * boom * math.exp(-3.5 * t) + 0.45 * rumble
        out.append(math.tanh(body * 1.4) * 0.95)
    return out


def make_saber(duration: float = 0.38) -> list[float]:
    total = int(SR * duration)
    out: list[float] = []
    state = 42
    for i in range(total):
        t = i / SR
        hum = (
            0.55 * math.sin(2 * math.pi * 92 * t)
            + 0.28 * math.sin(2 * math.pi * 184 * t)
            + 0.12 * math.sin(2 * math.pi * 276 * t)
        )
        sweep = math.sin(math.pi * (t / duration))
        frequency = 420 + 980 * sweep
        phase = 2 * math.pi * frequency * t
        whoosh = 0.45 * math.sin(phase) + 0.2 * math.sin(2 * phase)
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        noise = (state / 0xFFFFFFFF) * 2 - 1
        scrape = noise * (0.15 + 0.55 * sweep)
        amp = env_adsr(i, total, attack=0.02, decay=0.12, sustain=0.7, release=0.28)
        mixed = (hum * 0.35 + whoosh * 0.7 + scrape * 0.55) * amp
        out.append(math.tanh(mixed) * 0.9)
    return out


def make_chirp() -> list[float]:
    """Cartoon 'pi pó pi pó pi pó' alternating beeps."""
    # High / low / high / low / high / low
    notes = [1040.0, 620.0, 980.0, 560.0, 1120.0, 640.0]
    note_dur = 0.09
    gap = 0.045
    out: list[float] = []
    for index, freq in enumerate(notes):
        note_n = int(SR * note_dur)
        for i in range(note_n):
            t = i / SR
            # Soft square + sine for cartoon beep character.
            phase = 2 * math.pi * freq * t
            square = 1.0 if math.sin(phase) >= 0 else -0.7
            tone = 0.55 * math.sin(phase) + 0.35 * square
            # Tiny pitch scoop at start of each beep.
            scoop = 1.0 + 0.08 * math.exp(-40 * t)
            phase2 = 2 * math.pi * freq * scoop * t
            tone = 0.5 * math.sin(phase2) + 0.4 * (1.0 if math.sin(phase2) >= 0 else -0.65)
            amp = env_adsr(
                i,
                note_n,
                attack=0.01,
                decay=0.08,
                sustain=0.55,
                release=0.35,
            )
            # Slight volume bounce: pi louder than pó.
            volume = 0.72 if index % 2 == 0 else 0.58
            out.append(tone * amp * volume)
        gap_n = int(SR * gap)
        out.extend(0.0 for _ in range(gap_n))
    # Short tail silence so SoundPool doesn't click.
    out.extend(0.0 for _ in range(int(SR * 0.04)))
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(ANDROID_RAW, exist_ok=True)
    files = {
        'laser.wav': make_laser(),
        'explosion.wav': make_explosion(),
        'saber.wav': make_saber(),
        'chirp.wav': make_chirp(),
    }
    for name, samples in files.items():
        write_wav(os.path.join(OUT_DIR, name), samples)
        write_wav(os.path.join(ANDROID_RAW, name), samples)
        path = os.path.join(OUT_DIR, name)
        print(f'{name}: {os.path.getsize(path)} bytes')


if __name__ == '__main__':
    main()
