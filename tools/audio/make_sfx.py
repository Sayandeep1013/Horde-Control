"""Procedural SFX synth for Horde Control v1.0 (decision D180, docs/31 section 9).

Pure standard library (wave, struct, math, random). Every cue is deterministic:
random.Random(seed) per cue, seeds listed in CUES. Output: 44.1 kHz mono 16-bit
WAV in assets/audio/sfx/, peak-normalised to -3 dBFS with short fades.

Run from the repository root:  python tools/audio/make_sfx.py
Pass --analyse to print duration / peak / RMS / spectral centroid per file.
"""
import math
import os
import random
import struct
import sys
import wave

SR = 44100
PEAK = 10 ** (-3 / 20)  # -3 dBFS
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio", "sfx")
TAU = math.tau


# --- primitives ---------------------------------------------------------------

def n_samples(sec):
    return int(sec * SR)


def silence(sec):
    return [0.0] * n_samples(sec)


def noise(rng, sec):
    return [rng.uniform(-1, 1) for _ in range(n_samples(sec))]


def osc(freq_fn, sec, shape="sine", phase0=0.0):
    """freq_fn(t) -> Hz. Shapes: sine, saw, square, tri."""
    out = []
    ph = phase0
    for i in range(n_samples(sec)):
        t = i / SR
        ph += freq_fn(t) / SR
        p = ph % 1.0
        if shape == "sine":
            v = math.sin(TAU * p)
        elif shape == "saw":
            v = 2 * p - 1
        elif shape == "square":
            v = 1.0 if p < 0.5 else -1.0
        else:
            v = 4 * abs(p - 0.5) - 1
        out.append(v)
    return out


def const(f):
    return lambda t: f


def sweep(f0, f1, sec, curve=1.0):
    return lambda t: f0 + (f1 - f0) * min(1.0, (t / sec)) ** curve


def env_adr(sec, a, decay_tau, release=0.01):
    """Attack-linear then exponential decay envelope, with a release fade."""
    n = n_samples(sec)
    out = []
    for i in range(n):
        t = i / SR
        e = min(1.0, t / a) if a > 0 else 1.0
        e *= math.exp(-max(0.0, t - a) / decay_tau)
        rem = sec - t
        if rem < release:
            e *= rem / release
        out.append(e)
    return out


def env_shape(sec, points):
    """Piecewise-linear envelope; points = [(t, v), ...] ascending in t."""
    n = n_samples(sec)
    out = []
    k = 0
    for i in range(n):
        t = i / SR
        while k < len(points) - 2 and t > points[k + 1][0]:
            k += 1
        (t0, v0), (t1, v1) = points[k], points[k + 1]
        u = 0.0 if t1 == t0 else min(1.0, max(0.0, (t - t0) / (t1 - t0)))
        out.append(v0 + (v1 - v0) * u)
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def scale(a, g):
    return [x * g for x in a]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def place(track, at_sec, total_sec):
    out = silence(total_sec)
    off = n_samples(at_sec)
    for i, v in enumerate(track):
        if off + i < len(out):
            out[off + i] += v
    return out


def lowpass(x, cutoff):
    """One-pole low-pass; cutoff is Hz or a function of time."""
    fn = cutoff if callable(cutoff) else (lambda t: cutoff)
    y = 0.0
    out = []
    for i, v in enumerate(x):
        a = 1 - math.exp(-TAU * fn(i / SR) / SR)
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, fc):
    lp = lowpass(x, fc)
    return [a - b for a, b in zip(x, lp)]


def bandpass(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def lp2(x, fc):
    return lowpass(lowpass(x, fc), fc)


def distort(x, drive):
    return [math.tanh(v * drive) for v in x]


def finalise(x, fade_in=0.004, fade_out=0.02):
    peak = max(abs(v) for v in x) or 1.0
    g = PEAK / peak
    n = len(x)
    fi, fo = n_samples(fade_in), n_samples(fade_out)
    out = []
    for i, v in enumerate(x):
        v *= g
        if i < fi:
            v *= i / fi
        if i >= n - fo:
            v *= (n - 1 - i) / fo
        out.append(v)
    return out


def write_wav(name, x):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))
    return path


def note(freq, sec, tau=0.2, partials=((1, 1.0), (2, 0.35), (3, 0.12)), a=0.003):
    tracks = [scale(osc(const(freq * m), sec), g) for m, g in partials]
    return mul(mix(*tracks), env_adr(sec, a, tau))


def horn_tone(f, sec, rng, att=0.25, cutoff=1400):
    """Brassy horn: four detuned saws through a 2-pole low-pass that opens."""
    voices = [osc(const(f * (1 + d)), sec, "saw", phase0=rng.random()) for d in (-0.006, -0.002, 0.002, 0.006)]
    s = scale(mix(*voices), 0.25)
    s = lp2(s, lambda t: 280 + (cutoff - 280) * min(1.0, t / (att * 1.4)))
    return mul(s, env_shape(sec, [(0, 0), (att, 1), (max(att + 0.01, sec - 0.35), 0.85), (sec, 0)]))


# --- cues ---------------------------------------------------------------------

def bow_shot(rng):
    sec = 0.34
    twang = mul(osc(sweep(330, 190, 0.12, 0.5), sec, "tri"), env_adr(sec, 0.001, 0.07))
    twang2 = mul(osc(sweep(660, 400, 0.12, 0.5), sec, "sine"), env_adr(sec, 0.001, 0.04))
    air = bandpass(noise(rng, sec), 900, 5200)
    air = mul(air, env_shape(sec, [(0, 0), (0.02, 1), (0.12, 0.55), (sec, 0)]))
    click = mul(highpass(noise(rng, sec), 2500), env_adr(sec, 0.0005, 0.006))
    return mix(scale(twang, 0.8), scale(twang2, 0.35), scale(air, 0.55), scale(click, 0.4))


def tower_bolt(rng):
    sec = 0.5
    twang = mul(osc(sweep(150, 85, 0.2, 0.6), sec, "tri"), env_adr(sec, 0.001, 0.12))
    harm = mul(osc(sweep(300, 170, 0.2, 0.6), sec, "sine"), env_adr(sec, 0.001, 0.06))
    knock = mul(lp2(noise(rng, sec), 700), env_adr(sec, 0.0005, 0.03))
    air = mul(bandpass(noise(rng, sec), 400, 3000), env_shape(sec, [(0, 0), (0.04, 1), (0.25, 0.4), (sec, 0)]))
    return mix(scale(twang, 0.9), scale(harm, 0.3), scale(knock, 0.9), scale(air, 0.45))


def dash(rng):
    sec = 0.28
    w = bandpass(noise(rng, sec), 500, 4200)
    w = lowpass(w, lambda t: 700 + 4500 * math.sin(math.pi * min(1, t / sec)))
    return mul(w, env_shape(sec, [(0, 0), (0.06, 1), (0.14, 0.7), (sec, 0)]))


def explosion(rng):
    sec = 1.1
    nz = lowpass(noise(rng, sec), lambda t: 6000 * math.exp(-t * 5) + 150)
    nz = mul(nz, env_adr(sec, 0.002, 0.28))
    thump = mul(osc(sweep(120, 38, 0.35, 0.5), sec), env_adr(sec, 0.002, 0.2))
    crack = mul(highpass(noise(rng, sec), 1800), env_adr(sec, 0.0005, 0.02))
    return mix(scale(nz, 0.9), scale(thump, 1.2), scale(crack, 0.35))


def fuse(rng):
    sec = 0.5
    hiss = highpass(noise(rng, sec), 2500)
    crack = highpass([v if rng.random() < 0.04 else 0.0 for v in noise(rng, sec)], 1500)
    flick = [1.0 + 0.5 * math.sin(TAU * 31 * i / SR) for i in range(n_samples(sec))]
    e = env_shape(sec, [(0, 0), (0.03, 1), (0.42, 0.8), (sec, 0)])
    return mix(scale(mul(mul(hiss, e), flick), 0.5), scale(mul(crack, e), 2.2))


def frost(rng):
    sec = 0.7
    parts = []
    for i, f in enumerate((2093, 2637, 3136, 3951)):
        parts.append(scale(mul(osc(const(f * (1 + 0.003 * i)), sec), env_adr(sec, 0.002 + 0.02 * i, 0.15)), 0.5))
    shimmer = mul(highpass(noise(rng, sec), 5000), env_shape(sec, [(0, 0), (0.1, 1), (sec, 0)]))
    down = mul(osc(sweep(1800, 500, 0.35), sec, "sine"), env_adr(sec, 0.002, 0.12))
    return mix(*parts, scale(shimmer, 0.35), scale(down, 0.5))


def ignite(rng):
    sec = 0.55
    whoosh = bandpass(noise(rng, sec), 200, 3500)
    whoosh = mul(whoosh, env_shape(sec, [(0, 0), (0.04, 1), (0.2, 0.7), (sec, 0)]))
    low = mul(lp2(noise(rng, sec), 380), env_shape(sec, [(0, 0), (0.05, 1), (sec, 0)]))
    crackle = highpass([v if rng.random() < 0.012 else 0.0 for v in noise(rng, sec)], 1200)
    crackle = mul(crackle, env_shape(sec, [(0, 0.2), (0.15, 1), (sec, 0)]))
    return mix(scale(whoosh, 0.7), scale(low, 0.8), scale(crackle, 3.0))


def lightning(rng):
    sec = 0.55
    crack = mul(highpass(noise(rng, sec), 1500), env_adr(sec, 0.0005, 0.05))
    zap = mul(distort(osc(lambda t: 180 + 1800 * math.exp(-t * 18) + 25 * math.sin(TAU * 90 * t), sec, "saw"), 2.5),
              env_adr(sec, 0.001, 0.07))
    rumble = mul(lp2(noise(rng, sec), 300), env_shape(sec, [(0, 0), (0.02, 1), (sec, 0)]))
    return mix(crack, scale(zap, 0.5), scale(rumble, 0.9))


def axe_hit(rng):
    sec = 0.22
    thud = mul(osc(sweep(230, 90, 0.1), sec), env_adr(sec, 0.001, 0.05))
    metal = mix(*[scale(osc(const(f), sec), g) for f, g in ((1180, 0.4), (1790, 0.3), (2630, 0.2))])
    metal = mul(metal, env_adr(sec, 0.0005, 0.035))
    chip = mul(highpass(noise(rng, sec), 2000), env_adr(sec, 0.0005, 0.01))
    return mix(scale(thud, 0.9), scale(metal, 0.6), scale(chip, 0.4))


def caltrops(rng):
    sec = 0.4
    out = silence(sec)
    for at, f in ((0.0, 3300), (0.05, 2700), (0.11, 3600), (0.17, 2400)):
        tink = mul(osc(const(f), 0.12), env_adr(0.12, 0.0005, 0.018))
        tink2 = mul(osc(const(f * 2.4), 0.12), env_adr(0.12, 0.0005, 0.01))
        out = mix(out, place(mix(tink, scale(tink2, 0.4)), at, sec))
    scrape = mul(bandpass(noise(rng, sec), 3000, 8000), env_shape(sec, [(0, 0), (0.02, 0.4), (0.25, 0.1), (sec, 0)]))
    return mix(out, scale(scrape, 0.3))


def repair_tick(rng):
    sec = 0.18
    knock = mul(osc(sweep(520, 300, 0.05), sec, "tri"), env_adr(sec, 0.0005, 0.03))
    ring = mul(osc(const(1650), sec), env_adr(sec, 0.0005, 0.04))
    wood = mul(lowpass(noise(rng, sec), 2200), env_adr(sec, 0.0005, 0.01))
    return mix(scale(knock, 0.8), scale(ring, 0.35), scale(wood, 0.4))


def coin(rng):
    sec = 0.35
    a = mul(osc(const(1318.5), sec), env_adr(sec, 0.001, 0.16))
    b = place(mul(osc(const(1760.0), sec), env_adr(sec, 0.001, 0.2)), 0.07, sec)
    return mix(scale(a, 0.6), scale(b, 0.8))


def xp_tick(rng):
    sec = 0.1
    t1 = mul(osc(sweep(900, 1200, 0.06), sec), env_adr(sec, 0.001, 0.025))
    t2 = mul(osc(const(2400), sec), env_adr(sec, 0.001, 0.012))
    return mix(t1, scale(t2, 0.25))


def level_up(rng):
    sec = 1.0
    out = silence(sec)
    for i, f in enumerate((392.0, 493.9, 587.3, 784.0, 987.8)):  # G major, rising
        n = note(f, 0.6, tau=0.22, partials=((1, 1.0), (2, 0.4), (3, 0.15), (4, 0.06)))
        out = mix(out, place(n, i * 0.09, sec))
    final = mix(note(784, 0.55, 0.3), scale(note(1175, 0.55, 0.3), 0.6), scale(note(1568, 0.55, 0.3), 0.4))
    return mix(out, place(final, 0.45, sec))


def wave_horn(rng):
    sec = 1.9
    main = horn_tone(110.0, sec, rng, 0.28, 1500)
    fifth = scale(horn_tone(165.0, sec, rng, 0.34, 1200), 0.45)
    vib = [1.0 + 0.04 * math.sin(TAU * 5.2 * i / SR) * min(1, i / SR / 0.6) for i in range(n_samples(sec))]
    return mul(mix(main, fifth), vib)


def siege_warning(rng):
    sec = 1.6
    out = silence(sec)
    for at in (0.0, 0.62):
        h = horn_tone(98.0, 0.55, rng, 0.07, 1100)
        h2 = scale(horn_tone(103.8, 0.55, rng, 0.07, 1000), 0.8)  # minor-second clash for unease
        out = mix(out, place(mix(h, h2), at, sec))
    drum = mul(osc(sweep(95, 50, 0.2), 0.4), env_adr(0.4, 0.002, 0.08))
    for at in (1.24, 1.38):
        out = mix(out, place(scale(drum, 0.9), at, sec))
    return out


def elite_spawn(rng):
    sec = 1.0
    h = horn_tone(130.8, 0.9, rng, 0.05, 1800)
    clang = mix(*[scale(osc(const(f), sec), g) for f, g in ((520, 0.5), (781, 0.35), (1372, 0.25))])
    clang = mul(clang, env_adr(sec, 0.0005, 0.35))
    sting = mul(osc(sweep(200, 90, 0.5), sec, "saw"), env_adr(sec, 0.002, 0.2))
    return mix(place(h, 0.0, sec), scale(clang, 0.6), scale(lp2(sting, 700), 0.5))


def boss_roar(rng):
    sec = 2.3
    n = n_samples(sec)
    ph_c = ph_m = 0.0
    fm = []
    for i in range(n):
        t = i / SR
        u = math.sin(math.pi * min(1, t / sec))
        fc = 62 + 22 * u + 6 * math.sin(TAU * 7 * t)  # pitched-down growl, slow vibrato
        ph_c += fc / SR
        ph_m += fc * 0.75 / SR
        fm.append(math.sin(TAU * ph_c + (2.0 + 3.5 * u) * math.sin(TAU * ph_m)))
    fm = distort(fm, 2.2)
    breath = lowpass(noise(rng, sec), lambda t: 500 + 900 * math.sin(math.pi * min(1, t / sec)))
    body = lp2(mix(scale(fm, 0.8), scale(breath, 0.9)), 1100)
    return mul(body, env_shape(sec, [(0, 0), (0.25, 1), (1.2, 0.9), (sec, 0)]))


def boss_slam(rng):
    sec = 1.2
    boom = mul(osc(sweep(80, 30, 0.5, 0.5), sec), env_adr(sec, 0.002, 0.3))
    debris = mul(lowpass(noise(rng, sec), lambda t: 3000 * math.exp(-t * 6) + 120), env_adr(sec, 0.001, 0.22))
    crack = mul(highpass(noise(rng, sec), 1200), env_adr(sec, 0.0005, 0.03))
    return mix(scale(boom, 1.4), scale(debris, 0.9), scale(crack, 0.3))


def chest_open(rng):
    sec = 0.9
    creak = osc(lambda t: 140 + 220 * (t / 0.35) ** 1.5 + 12 * math.sin(TAU * 38 * t), 0.35, "saw")
    creak = mul(lp2(creak, 900), env_shape(0.35, [(0, 0), (0.05, 0.8), (0.3, 0.6), (0.35, 0)]))
    thump = mul(osc(sweep(150, 70, 0.1), 0.2), env_adr(0.2, 0.001, 0.04))
    glit = silence(sec)
    for i, f in enumerate((1568.0, 2093.0, 2637.0, 3136.0)):
        glit = mix(glit, place(note(f, 0.4, 0.12, ((1, 1.0), (2, 0.2))), 0.34 + i * 0.07, sec))
    return mix(place(creak, 0.0, sec), place(scale(thump, 0.8), 0.33, sec), scale(glit, 0.55))


def skill_ready(rng):
    sec = 0.45
    a = note(880.0, 0.3, 0.1, ((1, 1.0), (2, 0.3)))
    b = note(1318.5, 0.35, 0.14, ((1, 1.0), (2, 0.3)))
    return mix(place(a, 0.0, sec), place(b, 0.08, sec))


def victory(rng):
    sec = 2.4
    out = silence(sec)
    for at, f, d in ((0.0, 261.6, 0.35), (0.22, 329.6, 0.35), (0.44, 392.0, 0.35), (0.66, 523.3, 0.9)):
        out = mix(out, place(scale(horn_tone(f, d + 0.2, rng, 0.04, 2400), 0.9), at, sec))
    chord = silence(sec)
    for f in (261.6, 329.6, 392.0, 523.3):
        chord = mix(chord, place(horn_tone(f, 1.5, rng, 0.1, 1900), 0.9, sec))
    sparkle = silence(sec)
    for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        sparkle = mix(sparkle, place(note(f, 0.5, 0.15, ((1, 1.0), (2, 0.2))), 0.95 + i * 0.07, sec))
    return mix(out, scale(chord, 0.6), scale(sparkle, 0.35))


def defeat(rng):
    sec = 2.3
    out = silence(sec)
    for at, f, d in ((0.0, 293.7, 0.55), (0.5, 261.6, 0.55), (1.0, 220.0, 0.55), (1.5, 146.8, 0.7)):
        out = mix(out, place(horn_tone(f, d + 0.1, rng, 0.08, 800), at, sec))
    toll = mix(*[scale(osc(const(f), sec), g) for f, g in ((110, 0.8), (165.5, 0.4), (277, 0.2))])
    toll = mul(toll, env_adr(sec, 0.002, 0.7))
    return mix(out, scale(place(toll, 1.5, sec), 0.7))


def ui_hover(rng):
    sec = 0.06
    t = mul(osc(const(1500), sec), env_adr(sec, 0.001, 0.015))
    n = mul(highpass(noise(rng, sec), 3000), env_adr(sec, 0.0005, 0.008))
    return mix(scale(t, 0.5), scale(n, 0.2))


def ui_confirm(rng):
    sec = 0.22
    a = note(660.0, 0.15, 0.05, ((1, 1.0), (2, 0.3)))
    b = note(990.0, 0.2, 0.08, ((1, 1.0), (2, 0.25)))
    wood = mul(lowpass(noise(rng, sec), 1800), env_adr(sec, 0.0005, 0.008))
    return mix(place(a, 0, sec), place(b, 0.06, sec), scale(wood, 0.3))


CUES = {  # name: (function, seed, fade_out_seconds)
    "bow_shot": (bow_shot, 101, 0.03), "tower_bolt": (tower_bolt, 102, 0.04),
    "dash": (dash, 103, 0.04), "explosion": (explosion, 104, 0.06),
    "fuse": (fuse, 105, 0.04), "frost": (frost, 106, 0.05),
    "ignite": (ignite, 107, 0.05), "lightning": (lightning, 108, 0.05),
    "axe_hit": (axe_hit, 109, 0.02), "caltrops": (caltrops, 110, 0.04),
    "repair_tick": (repair_tick, 111, 0.02), "coin": (coin, 112, 0.04),
    "xp_tick": (xp_tick, 113, 0.015), "level_up": (level_up, 114, 0.08),
    "wave_horn": (wave_horn, 115, 0.12), "siege_warning": (siege_warning, 116, 0.12),
    "elite_spawn": (elite_spawn, 117, 0.1), "boss_roar": (boss_roar, 118, 0.2),
    "boss_slam": (boss_slam, 119, 0.1), "chest_open": (chest_open, 120, 0.08),
    "skill_ready": (skill_ready, 121, 0.05), "victory": (victory, 122, 0.25),
    "defeat": (defeat, 123, 0.3), "ui_hover": (ui_hover, 124, 0.01),
    "ui_confirm": (ui_confirm, 125, 0.03),
}


# --- analysis -----------------------------------------------------------------

def read_wav(path):
    with wave.open(path, "rb") as w:
        raw = w.readframes(w.getnframes())
    return [v / 32768.0 for (v,) in struct.iter_unpack("<h", raw)]


def spectral_centroid(x, frame=1024):
    """Mean magnitude-weighted centroid over up to 8 evenly spaced Hann frames
    (naive DFT, bins up to 10 kHz)."""
    if len(x) < frame:
        x = x + [0.0] * (frame - len(x))
    starts = [int(i * (len(x) - frame) / 7) for i in range(8)]
    num = den = 0.0
    kmax = int(10000 / (SR / frame))
    win = [0.5 - 0.5 * math.cos(TAU * i / frame) for i in range(frame)]
    for s in starts:
        seg = [x[s + i] * win[i] for i in range(frame)]
        if max(abs(v) for v in seg) < 0.01:
            continue  # skip near-silent frames
        for k in range(1, kmax):
            w = TAU * k / frame
            re = sum(seg[i] * math.cos(w * i) for i in range(frame))
            im = sum(seg[i] * math.sin(w * i) for i in range(frame))
            m = math.hypot(re, im)
            num += m * k * SR / frame
            den += m
    return num / den if den else 0.0


def analyse():
    print("| cue | dur s | peak dBFS | RMS dBFS | centroid Hz |")
    print("| --- | --- | --- | --- | --- |")
    for name in CUES:
        x = read_wav(os.path.join(OUT_DIR, name + ".wav"))
        pk = max(abs(v) for v in x)
        rms = math.sqrt(sum(v * v for v in x) / len(x))
        print("| %s | %.2f | %.1f | %.1f | %.0f |" % (
            name, len(x) / SR, 20 * math.log10(pk), 20 * math.log10(rms), spectral_centroid(x)))


def main():
    if "--analyse" in sys.argv:
        analyse()
        return
    for name, (fn, seed, fo) in CUES.items():
        x = finalise(fn(random.Random(seed)), fade_out=fo)
        p = write_wav(name, x)
        print("wrote %s (%.2f s)" % (os.path.normpath(p), len(x) / SR))


if __name__ == "__main__":
    main()
