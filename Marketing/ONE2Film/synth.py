"""ONE 2.0 tanıtım filmi — müzik ve ses tasarımı.

Müzik: 72 BPM (60–80: sinematik, köklü), Re majör, tek enstrüman öne (piyano
benzeri) + arkada yumuşak pad. Akorlar sahne kesmeleriyle aynı vuruşta değişir;
mühür anında gerilim (A7sus4) Re'ye çözülür.

Ses tasarımı: en fazla üç aile — (1) tuş, (2) kâğıt, (3) mühür.
"""
import json
import numpy as np

SR = 48000
BEAT = 60 / 72
DUR = 36 * BEAT
n_total = int(DUR * SR)
rng = np.random.default_rng(7)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def piano(m, dur, vel=0.5):
    f = midi_hz(m)
    n = int(dur * SR)
    t = np.arange(n) / SR
    tau = 2.8 * (220 / f) ** 0.45
    out = np.zeros(n)
    for k in range(1, 9):
        fk = f * k * (1 + 0.0004 * k * k)
        if fk > SR / 2.2:
            break
        amp = 1 / k ** 1.6
        out += amp * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * np.exp(-t / (tau / k ** 0.7))
    att = np.minimum(1, t / 0.004)
    rel = np.minimum(1, (dur - t) / 0.25)
    return vel * out * att * np.clip(rel, 0, 1)


def pad(notes, start, end):
    n = int((end - start + 1.2) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for m in notes:
        while m < 50:
            m += 12
        f = midi_hz(m)
        for det in (-0.0012, 0.0012):
            out += np.sin(2 * np.pi * f * (1 + det) * t) + 0.18 * np.sin(2 * np.pi * 2 * f * (1 + det) * t)
    length = end - start
    env = np.clip(t / 0.9, 0, 1) * np.clip((length + 1.0 - t) / 1.0, 0, 1)
    return 0.012 * out * env


def add(buf, sig, t0, pan=0.0):
    i = int(t0 * SR)
    if i >= n_total:
        return
    sig = sig[: n_total - i]
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    buf[0, i:i + len(sig)] += sig * l * 1.414
    buf[1, i:i + len(sig)] += sig * r * 1.414


def band(sig, lo, hi):
    spec = np.fft.rfft(sig)
    fr = np.fft.rfftfreq(len(sig), 1 / SR)
    spec *= ((fr > lo) & (fr < hi)).astype(float)
    return np.fft.irfft(spec, len(sig))


music = np.zeros((2, n_total))
sfx = np.zeros((2, n_total))

# Akorlar: (başlangıç vuruşu, bitiş vuruşu, notalar)
CHORDS = [
    (0, 4, [38, 45, 54, 61, 64]),     # Dmaj9
    (4, 8, [35, 42, 50, 57, 64]),     # Bm11
    (8, 12, [31, 38, 47, 54, 57]),    # Gmaj9
    (12, 16, [33, 40, 47, 52, 57]),   # Asus2
    (16, 20, [42, 49, 52, 57]),       # F#m7
    (20, 26, [43, 50, 54, 57, 59]),   # Gmaj9 (yolculuk: 6 vuruş, yavaş)
    (26, 28, [40, 47, 50, 54, 55]),   # Em9
    (28, 29, [45, 50, 52, 55]),       # A7sus4 — mühürden önce gerilim
    (29, 33, [38, 45, 54, 61, 64]),   # Dmaj9 — mühür: çözülme
    (33, 36, [50, 57, 64, 66, 69]),   # Dmaj9 üst ses — kapanış
]
for b0, b1, notes in CHORDS:
    t0, t1 = b0 * BEAT, b1 * BEAT
    for j, m in enumerate(notes):
        vel = 0.10 if m < 45 else 0.075
        add(music, piano(m, (t1 - t0) + 1.6, vel), t0 + j * 0.028, pan=(j / max(1, len(notes) - 1) - 0.5) * 0.5)
    add(music, pad(notes, t0, t1), t0)

# Seyrek melodi (vuruş, nota). Mühürden sonra sessiz: film orada durur.
MELODY = [(2, 69), (3.5, 66), (6, 71), (7, 69), (10, 74), (11, 71), (14, 76), (15.5, 71),
          (18, 73), (19, 69), (22, 71), (23.5, 69), (24.5, 66), (27, 71), (29, 78),
          (33.5, 74), (34.5, 78)]
for b, m in MELODY:
    add(music, piano(m, 3.0, 0.05), b * BEAT, pan=0.15)

# ---- Ses tasarımı ----
events = json.load(open('events.json'))
for e in events:
    if e['type'] in ('key', 'press'):
        # 1 · Tuş: çok kısa, kuru, alçak
        n = int(0.012 * SR)
        s = band(rng.standard_normal(n), 1800, 7000) * np.exp(-np.arange(n) / SR / 0.0025)
        gain = 0.035 if e['type'] == 'key' else 0.06
        add(sfx, s * gain * rng.uniform(0.7, 1.1), e['t'], pan=rng.uniform(-0.2, 0.2))
    elif e['type'] == 'paper':
        # 2 · Kâğıt: ortak öğe geçişinde hafif hışırtı
        n = int(0.55 * SR)
        tt = np.arange(n) / n
        s = band(rng.standard_normal(n), 1200, 6500) * np.sin(np.pi * tt) ** 2
        add(sfx, s * 0.018, e['t'], pan=0.1)
    elif e['type'] == 'seal':
        # 3 · Mühür: tek, yumuşak, kuru vuruş
        n = int(0.6 * SR)
        t = np.arange(n) / SR
        f = 60 + 60 * np.exp(-t / 0.06)
        body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
        click = band(rng.standard_normal(n), 200, 2500) * np.exp(-t / 0.008)
        add(sfx, 0.20 * body + 0.04 * click, e['t'])

# ---- Oda (reverb) ----
ir_n = int(2.4 * SR)
ti = np.arange(ir_n) / SR


def reverb(x, seed):
    r = np.random.default_rng(seed)
    ir = band(r.standard_normal(ir_n), 80, 6000) * np.exp(-ti / 0.55)
    ir[0] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + ir_n)))
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    return y


mix = np.zeros((2, n_total))
for ch in range(2):
    mix[ch] = music[ch] + 0.32 * reverb(music[ch], 11 + ch) + sfx[ch] + 0.12 * reverb(sfx[ch], 21 + ch)

# Kapanış: son 1.2 saniyede sön
fade = np.ones(n_total)
fl = int(1.2 * SR)
fade[-fl:] = np.linspace(1, 0, fl) ** 1.5
fade[: int(0.02 * SR)] = np.linspace(0, 1, int(0.02 * SR))
mix *= fade
mix /= np.max(np.abs(mix)) / 0.89  # -1 dBFS

pcm = (mix.T * 32767).astype('<i2')
import wave
with wave.open('audio.wav', 'wb') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print('audio.wav', DUR, 's, events:', len(events))
