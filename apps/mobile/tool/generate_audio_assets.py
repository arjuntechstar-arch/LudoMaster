"""Generate original, lightweight retro game audio assets for LudoMaster."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22_050


def write_wav(name: str, samples: list[float]) -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    peak = max((abs(value) for value in samples), default=1.0) or 1.0
    scale = min(0.88 / peak, 1.0)
    with wave.open(str(ROOT / name), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, value * scale)) * 32767))
                for value in samples
            )
        )


def tone(frequency: float, seconds: float, *, shape: str = "sine", volume: float = 0.2) -> list[float]:
    count = int(RATE * seconds)
    output = []
    for i in range(count):
        t = i / RATE
        envelope = min(1.0, t / 0.012, (seconds - t) / 0.035)
        phase = 2 * math.pi * frequency * t
        raw = math.sin(phase)
        if shape == "square":
            raw = 1.0 if raw >= 0 else -1.0
        output.append(raw * volume * max(0.0, envelope))
    return output


def make_music() -> None:
    seconds = 8.0
    count = int(RATE * seconds)
    notes = [523.25, 659.25, 783.99, 659.25, 587.33, 698.46, 880.0, 698.46,
             523.25, 659.25, 783.99, 1046.5, 880.0, 783.99, 698.46, 587.33]
    roots = [130.81, 174.61, 146.83, 196.0]
    output = [0.0] * count

    for i in range(count):
        t = i / RATE
        beat = int(t / 0.5)
        local = t % 0.5
        note = notes[beat % len(notes)]
        attack = min(1.0, local / 0.018)
        release = min(1.0, max(0.0, (0.5 - local) / 0.055))
        env = attack * release
        melody_phase = 2 * math.pi * note * t
        melody = (math.sin(melody_phase) + 0.24 * math.sin(2 * melody_phase)) * 0.13 * env

        root = roots[(beat // 4) % len(roots)]
        bass_phase = 2 * math.pi * root * t
        bass = math.sin(bass_phase) * 0.11 * min(1.0, local / 0.02) * release

        arpeggio = (root * 2, root * 2.5, root * 3, root * 4)[beat % 4]
        arp_phase = 2 * math.pi * arpeggio * t
        arp = (1.0 if math.sin(arp_phase) >= 0 else -1.0) * 0.035 * env
        output[i] = melody + bass + arp

    write_wav("game_music.wav", output)


def make_dice() -> None:
    duration = 0.38
    rng = random.Random(42)
    output = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        envelope = max(0.0, 1.0 - t / duration)
        frequency = 760 - 500 * (t / duration)
        rattle = rng.uniform(-1, 1) if int(t * 75) % 2 == 0 else 0.0
        output.append((math.sin(2 * math.pi * frequency * t) * 0.55 + rattle * 0.22) * envelope * 0.6)
    write_wav("dice_roll.wav", output)


def make_capture() -> None:
    duration = 0.42
    rng = random.Random(7)
    output = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        envelope = math.exp(-t * 8.0)
        impact = math.sin(2 * math.pi * (115 - 40 * t) * t)
        noise = rng.uniform(-1, 1) * 0.25
        output.append((impact * 0.75 + noise) * envelope * 0.8)
    write_wav("capture.wav", output)


def make_victory() -> None:
    melody = [659.25, 783.99, 987.77, 1318.51]
    output: list[float] = []
    for frequency in melody:
        output.extend(tone(frequency, 0.19, shape="square", volume=0.16))
    output.extend(tone(1318.51, 0.5, shape="sine", volume=0.15))
    output.extend([0.0] * int(RATE * 0.08))
    write_wav("victory.wav", output)


def main() -> None:
    make_music()
    write_wav("token_move.wav", tone(880.0, 0.13, shape="square", volume=0.13))
    make_dice()
    make_capture()
    make_victory()


if __name__ == "__main__":
    main()
