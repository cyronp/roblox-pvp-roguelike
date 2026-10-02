"""Synthesize original gameplay cues as mono 48 kHz PCM WAVs (standard library only)."""

import math
from pathlib import Path
import random
import struct
import wave


RATE = 48_000
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
TAU = math.tau


def tone(samples, start, duration, frequency, gain):
    """A softly struck bell with a quick attack and decaying upper partials."""
    offset = round(start * RATE)
    for i in range(min(round(duration * RATE), len(samples) - offset)):
        t = i / RATE
        envelope = min(t / 0.004, 1) * math.exp(-5 * t / duration)
        envelope *= min((duration - t) / 0.035, 1)
        phase = TAU * frequency * t
        partials = math.sin(phase)
        partials += 0.22 * math.sin(2 * phase) * math.exp(-12 * t)
        partials += 0.07 * math.sin(3 * phase) * math.exp(-20 * t)
        samples[offset + i] += gain * envelope * partials


def level_up():
    samples = [0.0] * round(1.05 * RATE)
    for start, frequency, gain in [
        (0, 523.25, 0.55), (0.09, 659.25, 0.52),
        (0.18, 783.99, 0.50), (0.28, 1046.50, 0.57),
    ]:
        tone(samples, start, 0.72, frequency, gain)
    tone(samples, 0.30, 0.70, 659.25, 0.17)
    tone(samples, 0.30, 0.70, 783.99, 0.17)
    return samples


def dash():
    duration = 0.30
    samples = []
    rng = random.Random(2718)
    low = 0.0
    rumble = 0.0
    phase = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        progress = t / duration
        noise = rng.uniform(-1, 1)
        cutoff = 700 + 5000 * (1 - progress) ** 2
        low += (1 - math.exp(-TAU * cutoff / RATE)) * (noise - low)
        rumble += (1 - math.exp(-TAU * 220 / RATE)) * (low - rumble)
        envelope = (1 - math.exp(-t / 0.008)) * (1 - progress) ** 2
        phase += TAU * (360 * (1 - progress) ** 2 + 80) / RATE
        body = 0.16 * math.sin(phase) * math.exp(-t / 0.07)
        samples.append(envelope * (1.5 * (low - rumble) + body))
    return samples


def upgrade_choose():
    samples = [0.0] * round(0.48 * RATE)
    tone(samples, 0, 0.22, 783.99, 0.52)
    tone(samples, 0.065, 0.38, 1174.66, 0.47)
    rng = random.Random(314)
    for i in range(round(0.035 * RATE)):
        t = i / RATE
        envelope = min(t / 0.002, 1) * math.exp(-t / 0.006)
        samples[i] += 0.12 * envelope * rng.uniform(-1, 1)
    return samples


def write(name, samples):
    # Remove DC and leave 3 dB of headroom; fade file edges to prevent clicks.
    mean = sum(samples) / len(samples)
    samples = [value - mean for value in samples]
    peak = max(abs(value) for value in samples)
    fade = round(0.003 * RATE)
    pcm = [round(32767 * 0.707 * value / peak
                 * min(i / fade, (len(samples) - 1 - i) / fade, 1))
           for i, value in enumerate(samples)]
    assert max(abs(value) for value in pcm) < 32767
    assert pcm[0] == pcm[-1] == 0
    path = OUTPUT / name
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))
    print(f"{name}: {len(pcm) / RATE:.2f}s, {path.stat().st_size:,} bytes")


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for filename, synthesize in [
        ("level-up.wav", level_up),
        ("dash.wav", dash),
        ("upgrade-choose.wav", upgrade_choose),
    ]:
        write(filename, synthesize())
