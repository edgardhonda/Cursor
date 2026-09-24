"""Generate original per-unit SFX for Batalha."""

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


def env(t: float, dur: float, a: float = 0.01, r: float = 0.08) -> float:
    if t < 0 or t > dur:
        return 0.0
    attack = min(1.0, t / a) if a > 0 else 1.0
    release = min(1.0, (dur - t) / r) if r > 0 else 1.0
    return attack * release


def noise(state: int) -> tuple[float, int]:
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF
    return state / 0x7FFFFFFF * 2 - 1, state


def note(freq: float, t: float) -> float:
    return (
        math.sin(2 * math.pi * freq * t) * 0.72
        + math.sin(2 * math.pi * freq * 2 * t) * 0.18
        + math.sin(2 * math.pi * freq * 3 * t) * 0.06
    )


def make_vitoria(duration: float = 1.55) -> list[float]:
    n = int(SR * duration)
    out = [0.0] * n
    melody = [
        (523.25, 0.00, 0.18),
        (659.25, 0.14, 0.18),
        (783.99, 0.28, 0.20),
        (1046.50, 0.44, 0.36),
        (1318.51, 0.72, 0.24),
        (1046.50, 0.92, 0.55),
    ]
    bass = [
        (130.81, 0.00, 0.50),
        (196.00, 0.44, 0.50),
        (261.63, 0.92, 0.55),
    ]
    for freq, start, dur in melody + bass:
        volume = 0.28 if freq < 300 else 0.44
        for i in range(n):
            t = i / SR - start
            e = env(t, dur, 0.02, 0.18)
            if e <= 0:
                continue
            out[i] += note(freq, max(0.0, t)) * e * volume
    return [math.tanh(s * 1.12) * 0.92 for s in out]


def make_cachorro(duration: float = 0.22) -> list[float]:
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        e = env(t, duration, 0.01, 0.12)
        freq = 520 - 180 * t
        y = math.sin(2 * math.pi * freq * t) * 0.55
        y += math.sin(2 * math.pi * freq * 1.7 * t) * 0.18
        out.append(math.tanh(y * e) * 0.85)
    return out


def make_soldado(duration: float = 0.16) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 9
    for i in range(n):
        t = i / SR
        e = env(t, duration, 0.004, 0.1)
        nse, state = noise(state)
        y = math.sin(2 * math.pi * (190 - 80 * t) * t) * 0.5
        y += nse * 0.22 * (1 - t / duration)
        out.append(math.tanh(y * e) * 0.9)
    return out


def make_cavaleiro(duration: float = 0.2) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 21
    for i in range(n):
        t = i / SR
        e = env(t, duration, 0.006, 0.12)
        nse, state = noise(state)
        y = math.sin(2 * math.pi * (140 - 40 * t) * t) * 0.4
        y += math.sin(2 * math.pi * 880 * t) * 0.12 * max(0.0, 1 - t * 8)
        y += nse * 0.18
        out.append(math.tanh(y * e) * 0.9)
    return out


def make_gigante(duration: float = 0.28) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 77
    for i in range(n):
        t = i / SR
        e = env(t, duration, 0.008, 0.16)
        nse, state = noise(state)
        y = math.sin(2 * math.pi * (70 - 18 * t) * t) * 0.7
        y += nse * 0.35 * math.exp(-t * 8)
        out.append(math.tanh(y * e) * 0.95)
    return out


def make_arqueiro(duration: float = 0.18) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 33
    for i in range(n):
        t = i / SR
        e = env(t, duration, 0.003, 0.1)
        nse, state = noise(state)
        twang = math.sin(2 * math.pi * (920 + 120 * math.sin(t * 40)) * t)
        y = twang * 0.42 + nse * 0.12 * math.exp(-t * 20)
        out.append(math.tanh(y * e) * 0.85)
    return out


def make_canhao(duration: float = 0.34) -> list[float]:
    n = int(SR * duration)
    out = []
    state = 101
    for i in range(n):
        t = i / SR
        e = env(t, duration, 0.004, 0.2)
        nse, state = noise(state)
        boom = math.sin(2 * math.pi * (55 - 20 * t) * t) * 0.8
        y = boom + nse * 0.55 * math.exp(-t * 6)
        out.append(math.tanh(y * e) * 0.98)
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(ANDROID_RAW, exist_ok=True)
    sounds = {
        "cachorro": make_cachorro(),
        "soldado": make_soldado(),
        "cavaleiro": make_cavaleiro(),
        "gigante": make_gigante(),
        "arqueiro": make_arqueiro(),
        "canhao": make_canhao(),
        "vitoria": make_vitoria(),
    }
    for name, samples in sounds.items():
        write_wav(os.path.join(OUT_DIR, f"{name}.wav"), samples)
        write_wav(os.path.join(ANDROID_RAW, f"{name}.wav"), samples)
        print(f"wrote {name}.wav ({len(samples)} samples)")


if __name__ == "__main__":
    main()
