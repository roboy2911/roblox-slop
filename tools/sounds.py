"""Makes every sound effect from scratch (no samples): numpy synthesis -> WAV.

    python tools/sounds.py blender/out

Writes Sfx<Name>.wav files. tools/build_assets.py uploads them as Audio and
puts their IDs in src/shared/Config/Assets.luau (Sounds = {...}).
"""

import math
import os
import sys
import wave

import numpy as np

RATE = 44100
rng = np.random.default_rng(7)

# ------------------------------------------------------------------ building blocks


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def note(name):
    """'A4' -> Hz."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + (octave - 4) * 12) / 12)


def osc(freq, seconds, shape="sine"):
    """An oscillator. `freq` is a number or an array (for sweeps)."""
    n = int(RATE * seconds)
    f = np.full(n, freq, dtype=float) if np.isscalar(freq) else np.asarray(freq, dtype=float)[:n]
    phase = np.cumsum(f) / RATE
    if shape == "sine":
        return np.sin(2 * np.pi * phase)
    if shape == "square":
        return np.sign(np.sin(2 * np.pi * phase)) * 0.6
    if shape == "saw":
        return (2 * (phase % 1.0) - 1) * 0.7
    if shape == "tri":
        return (2 * np.abs(2 * (phase % 1.0) - 1) - 1)
    raise ValueError(shape)


def sweep(start, end, seconds, curve=1.0):
    k = np.linspace(0, 1, int(RATE * seconds)) ** curve
    return start * (end / start) ** k


def env(seconds, attack=0.005, decay=None, sustain=1.0, release=0.05):
    """Attack / hold / release envelope. With `decay`, falls exponentially instead."""
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    e = np.ones(n)
    a = max(1, int(RATE * attack))
    e[:a] = np.linspace(0, 1, a)
    if decay is not None:
        e[a:] = np.exp(-(t[a:] - attack) / decay)
    else:
        e *= sustain
        e[:a] = np.linspace(0, 1, a)
    r = min(n, max(1, int(RATE * release)))
    e[-r:] *= np.linspace(1, 0, r)
    return e


def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))


def lowpass(x, cutoff):
    """One-pole low-pass. `cutoff` can be an array (for sweeps)."""
    cut = np.full(len(x), cutoff, dtype=float) if np.isscalar(cutoff) else np.asarray(cutoff, dtype=float)
    a = 1 - np.exp(-2 * np.pi * cut / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, center, q=4.0):
    """Two-pole resonant band-pass (fixed center)."""
    w = 2 * math.pi * center / RATE
    alpha = math.sin(w) / (2 * q)
    b0, b2 = alpha, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w), 1 - alpha
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        out = (b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x[i]
        y2, y1 = y1, out
        y[i] = out
    return y


def reverb(x, amount=0.3, room=0.06):
    """A few feedback delays: cheap but adds space."""
    out = np.concatenate([x, np.zeros(int(RATE * 0.8))])
    for delay, gain in ((room, 0.5), (room * 1.37, 0.4), (room * 1.83, 0.33), (room * 2.41, 0.25)):
        d = int(RATE * delay)
        tail = np.zeros_like(out)
        for k in range(1, 6):
            shift = d * k
            if shift >= len(out):
                break
            tail[shift:] += out[: len(out) - shift] * gain ** k
        out = out + tail * amount / 2
    return out


def mix(*sounds):
    """Adds sounds of different lengths together."""
    n = max(len(x) for x in sounds)
    out = np.zeros(n)
    for x in sounds:
        out[: len(x)] += x
    return out


def place(track, sound, at):
    """Adds `sound` into `track` starting at `at` seconds (grows the track if needed)."""
    start = int(RATE * at)
    end = start + len(sound)
    if end > len(track):
        track = np.concatenate([track, np.zeros(end - len(track))])
    track[start:end] += sound
    return track


def bell(freq, seconds=0.6, decay=0.18):
    """Bright metallic ding (coins, chimes)."""
    s = (osc(freq, seconds) + 0.5 * osc(freq * 2.76, seconds) + 0.25 * osc(freq * 5.4, seconds) + 0.15 * osc(freq * 8.9, seconds))
    return s * env(seconds, 0.002, decay)


def pluck(freq, seconds=0.25, shape="square", decay=0.08):
    return lowpass(osc(freq, seconds, shape), 4000) * env(seconds, 0.003, decay)


def finish(x, peak=0.89, fade=0.02):
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1
    x = x / m * peak
    f = int(RATE * fade)
    x[-f:] *= np.linspace(1, 0, f)
    # Trim trailing silence.
    loud = np.where(np.abs(x) > 0.002)[0]
    if len(loud):
        x = x[: loud[-1] + int(RATE * 0.02)]
    return x


def write(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


# ------------------------------------------------------------------ the sounds


def collect():
    """Coins jingling into your pocket: a quick rising pair of dings and a shimmer."""
    t = np.zeros(1)
    for i, (n, at) in enumerate((("B5", 0.0), ("E6", 0.07), ("G#6", 0.13))):
        t = place(t, bell(note(n), 0.5, 0.12) * (0.9 - i * 0.15), at)
    for k in range(10):
        t = place(t, bell(rng.uniform(3000, 6000), 0.12, 0.03) * 0.15, 0.1 + k * 0.025)
    return reverb(t, 0.25, 0.04)


def hatch():
    """Three eggshell cracks, then a cute pop and a little chirp."""
    t = np.zeros(1)
    for i, at in enumerate((0.0, 0.18, 0.32)):
        crack = highpass(noise(0.05), 1500) * env(0.05, 0.001, 0.008)
        t = place(t, crack * (0.6 + i * 0.2), at)
    pop = osc(sweep(250, 900, 0.09, 0.6), 0.09) * env(0.09, 0.002, 0.04)
    t = place(t, pop, 0.45)
    chirp = osc(sweep(1200, 2400, 0.12), 0.12, "tri") * env(0.12, 0.005, 0.06) * 0.5
    t = place(t, chirp, 0.55)
    t = place(t, chirp * 0.7, 0.7)
    return reverb(t, 0.2, 0.03)


def new_dragon():
    """A short victory fanfare: major arpeggio, then a shimmering chord."""
    t = np.zeros(1)
    for i, n in enumerate(("C5", "E5", "G5", "C6")):
        t = place(t, mix(pluck(note(n), 0.25, "square", 0.12) * 0.6, bell(note(n), 0.3, 0.1) * 0.3), i * 0.09)
    for n in ("C5", "E5", "G5", "C6", "E6"):
        tone = (osc(note(n), 1.2, "saw") * 0.3 + osc(note(n) * 1.004, 1.2, "saw") * 0.3)
        t = place(t, lowpass(tone, 3000) * env(1.2, 0.02, 0.5) * 0.35, 0.36)
    for k in range(18):
        t = place(t, bell(rng.uniform(2500, 7000), 0.15, 0.04) * 0.12, 0.36 + k * 0.04)
    return reverb(t, 0.35, 0.05)


def grab():
    """Bubbly pop when you pick up an egg."""
    s = osc(sweep(300, 1100, 0.11, 0.5), 0.11) * env(0.11, 0.002, 0.05)
    s += osc(sweep(600, 2200, 0.11, 0.5), 0.11, "tri") * env(0.11, 0.002, 0.03) * 0.3
    return reverb(s, 0.15, 0.02)


def place_egg():
    """A soft thunk and a happy blip when an egg goes on a perch."""
    thunk = lowpass(noise(0.12), 400) * env(0.12, 0.002, 0.03) * 1.5
    thunk += osc(sweep(180, 90, 0.12), 0.12) * env(0.12, 0.002, 0.05)
    t = place(np.zeros(1), thunk, 0)
    t = place(t, pluck(note("E6"), 0.15, "tri", 0.05) * 0.5, 0.08)
    t = place(t, pluck(note("A6"), 0.18, "tri", 0.06) * 0.5, 0.15)
    return reverb(t, 0.15, 0.03)


def bonk():
    """Cartoon BONK: a hollow wooden knock with a pitch drop and a boing."""
    knock = osc(sweep(520, 140, 0.25, 0.5), 0.25) * env(0.25, 0.001, 0.07)
    knock = mix(knock, bandpass(noise(0.08), 900, 3) * env(0.08, 0.001, 0.015) * 2)
    boing = osc(sweep(300, 600, 0.4) * (1 + 0.08 * np.sin(2 * np.pi * 18 * t_axis(0.4))), 0.4, "tri") * env(0.4, 0.01, 0.15) * 0.35
    t = place(np.zeros(1), knock, 0)
    t = place(t, boing, 0.05)
    return reverb(t, 0.15, 0.03)


def swing():
    """A quick whoosh for swinging the club."""
    n = noise(0.22)
    cut = np.concatenate([np.linspace(300, 3500, int(RATE * 0.1)), np.linspace(3500, 400, int(RATE * 0.22) - int(RATE * 0.1))])
    return lowpass(n, cut) * env(0.22, 0.03, 0.08)


def roar():
    """The Elder Dragon's roar: growling low saws through a sweeping formant, plus breathy noise."""
    secs = 2.6
    t = t_axis(secs)
    wobble = 1 + 0.06 * np.sin(2 * np.pi * 6 * t) + 0.03 * rng.standard_normal(len(t)).cumsum() / 400
    base = np.interp(t, [0, 0.4, 1.8, secs], [70, 95, 80, 55]) * wobble
    growl = osc(base, secs, "saw") + osc(base * 1.5, secs, "saw") * 0.5 + osc(base * 0.5, secs, "square") * 0.6
    growl = np.tanh(growl * 2.5)  # distortion
    voice = bandpass(growl, 420, 2) * 2 + bandpass(growl, 900, 3) * 1.2 + lowpass(growl, 250)
    breath = bandpass(noise(secs), 1200, 1.5) * 0.6
    shape = np.interp(t, [0, 0.25, 1.6, secs], [0, 1, 0.8, 0]) ** 1.2
    return reverb((voice + breath) * shape, 0.45, 0.09)


def fire_loop():
    """A crackling fire loop (seamless) for the fire wall."""
    secs = 3.0
    rumble = lowpass(noise(secs), 180) * 3
    roar_ = bandpass(noise(secs), 700, 0.8) * 0.8
    crackle = np.zeros(int(RATE * secs))
    for _ in range(140):
        at = rng.uniform(0, secs - 0.03)
        pop = highpass(noise(0.02), 2500) * env(0.02, 0.0005, 0.004) * rng.uniform(0.3, 1.0)
        start = int(RATE * at)
        crackle[start:start + len(pop)] += pop
    x = rumble + roar_ + crackle * 1.2
    # Crossfade the ends so it loops without a click.
    f = int(RATE * 0.25)
    x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    x = x[:-f]
    return x / np.max(np.abs(x)) * 0.89


def warning():
    """War horn before a wave: two deep, rising brassy blasts."""
    t = np.zeros(1)
    for at, length in ((0.0, 0.7), (0.85, 1.1)):
        f = sweep(note("A2"), note("D3"), length, 0.3) * (1 + 0.01 * np.sin(2 * np.pi * 5 * t_axis(length)))
        horn = osc(f, length, "saw") + osc(f * 2, length, "saw") * 0.4 + osc(f * 1.003, length, "saw")
        horn = lowpass(np.tanh(horn * 1.5), 1600) * env(length, 0.06, None, 1.0, 0.2)
        t = place(t, horn, at)
    return reverb(t, 0.4, 0.08)


def click():
    """UI tick."""
    return osc(sweep(1800, 900, 0.04), 0.04, "tri") * env(0.04, 0.001, 0.012)


def error():
    """Soft 'nope' buzz: two falling notes."""
    t = place(np.zeros(1), pluck(note("E4"), 0.14, "square", 0.08), 0)
    t = place(t, pluck(note("C4"), 0.22, "square", 0.12), 0.11)
    return lowpass(t, 2500)


def announce():
    """Server-wide news chime: a bright two-note bell."""
    t = place(np.zeros(1), bell(note("G5"), 0.8, 0.25), 0)
    t = place(t, bell(note("D6"), 1.0, 0.35), 0.16)
    return reverb(t, 0.35, 0.06)


def upgrade():
    """Quick rising power-up arpeggio."""
    t = np.zeros(1)
    for i, n in enumerate(("C5", "E5", "G5", "C6", "E6", "G6")):
        t = place(t, mix(pluck(note(n), 0.14, "square", 0.05) * 0.55, bell(note(n), 0.14, 0.04) * 0.2), i * 0.045)
    return reverb(t, 0.2, 0.03)


def rebirth():
    """Big magical whoosh up into a glowing chord."""
    secs = 2.4
    t = t_axis(secs)
    rise = lowpass(noise(secs), np.interp(t, [0, 1.0, secs], [200, 6000, 1500])) * np.interp(t, [0, 0.9, 1.1, secs], [0, 1, 0.3, 0])
    swoop = osc(sweep(150, 1200, 1.0, 2), 1.0, "saw") * env(1.0, 0.3, None, 1, 0.1) * 0.25
    out = place(rise * 0.8, lowpass(swoop, 2500), 0)
    for n in ("C4", "G4", "C5", "E5", "G5", "C6"):
        pad = osc(note(n), 1.5, "saw") * 0.5 + osc(note(n) * 1.006, 1.5, "saw") * 0.5
        out = place(out, lowpass(pad, 2200) * env(1.5, 0.05, 0.6) * 0.3, 0.95)
        out = place(out, bell(note(n) * 2, 1.0, 0.3) * 0.2, 0.95)
    return reverb(out, 0.4, 0.07)


def alarm():
    """Someone is stealing your dragon! Urgent alternating beeps."""
    t = np.zeros(1)
    for i in range(6):
        n = "A5" if i % 2 == 0 else "E5"
        t = place(t, pluck(note(n), 0.13, "square", 0.1) * 0.8, i * 0.13)
    return t


def sneak():
    """Thief got the dragon: sneaky descending plucks."""
    t = np.zeros(1)
    for i, n in enumerate(("E5", "D#5", "D5", "C#5")):
        t = place(t, pluck(note(n), 0.12, "tri", 0.05) * 0.7, i * 0.1)
    return reverb(t, 0.2, 0.04)


def lock():
    """Heavy metal latch clunk with a magical seal."""
    clunk = bandpass(noise(0.15), 300, 2) * env(0.15, 0.001, 0.04) * 3
    clunk += osc(sweep(220, 110, 0.15), 0.15, "square") * env(0.15, 0.001, 0.05) * 0.5
    t = place(np.zeros(1), clunk, 0)
    t = place(t, bell(note("C6"), 0.7, 0.25) * 0.5, 0.1)
    t = place(t, bell(note("G6"), 0.7, 0.25) * 0.35, 0.16)
    return reverb(t, 0.3, 0.05)


def sell():
    """Ka-ching: a register bell and a coin spill."""
    t = place(np.zeros(1), bell(note("E6"), 0.6, 0.2), 0)
    t = place(t, bell(note("A6"), 0.8, 0.3) * 0.8, 0.08)
    for k in range(14):
        t = place(t, bell(rng.uniform(2500, 5500), 0.1, 0.025) * 0.18, 0.15 + k * 0.03)
    return reverb(t, 0.2, 0.04)


def star():
    """Celestial egg fell: twinkling descending chimes."""
    t = np.zeros(1)
    for i, n in enumerate(("E7", "B6", "G#6", "E6", "B5")):
        t = place(t, bell(note(n), 1.0, 0.3) * (0.8 - i * 0.08), i * 0.11)
    return reverb(t, 0.5, 0.09)


def burned():
    """Got caught by the fire: a sizzle and a sad falling tone."""
    sizzle = highpass(noise(0.6), 2000) * env(0.6, 0.005, 0.2) * 0.6
    fall = osc(sweep(600, 120, 0.7, 0.7), 0.7, "tri") * env(0.7, 0.01, 0.3)
    t = place(np.zeros(1), sizzle, 0)
    t = place(t, fall, 0.05)
    return reverb(t, 0.25, 0.05)


SOUNDS = {
    "Collect": collect, "Hatch": hatch, "NewDragon": new_dragon, "Grab": grab, "Place": place_egg,
    "Bonk": bonk, "Swing": swing, "Roar": roar, "Fire": fire_loop, "Warning": warning, "Click": click,
    "Error": error, "Announce": announce, "Upgrade": upgrade, "Rebirth": rebirth, "Alarm": alarm,
    "Sneak": sneak, "Lock": lock, "Sell": sell, "Star": star, "Burned": burned,
}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "blender/out"
    os.makedirs(out, exist_ok=True)
    wanted = sys.argv[2:]
    for name, make in SOUNDS.items():
        if wanted and name not in wanted:
            continue
        x = make()
        x = x if name == "Fire" else finish(x)
        path = os.path.join(out, f"Sfx{name}.wav")
        write(path, x)
        print(f"Sfx{name}: {len(x) / RATE:.2f}s -> {path}")
