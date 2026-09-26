"""ONE 2.0 film kiti — müzik ve ses tasarımı.

Kullanım: python3 kit/synth.py <partisyon.json> <events.json> <çıktı.wav>

Partisyon: {"chords": [[başlangıç_vuruşu, bitiş_vuruşu, [midi...]], ...],
            "melody": [[vuruş, midi], ...]}
Tempo sabit 72 BPM (STYLE.md). Piyano benzeri ton + yumuşak pad + oda.
Ses efekti üç aile: key (tuş, basış), paper (kâğıt, kart geçişi), seal (mühür,
tamamlanma). Olaylar sahnenin `EVENTS` listesinden gelir.
"""
import json
import sys
import wave

import numpy as np

SR = 48000
BEAT = 60 / 72
rng = np.random.default_rng(7)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def piano(m, dur, vel):
    f = midi_hz(m)
    n = int(dur * SR)
    t = np.arange(n) / SR
    tau = 2.8 * (220 / f) ** 0.45
    out = np.zeros(n)
    for k in range(1, 9):
        fk = f * k * (1 + 0.0004 * k * k)
        if fk > SR / 2.2:
            break
        out += (1 / k ** 1.6) * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * np.exp(-t / (tau / k ** 0.7))
    att = np.minimum(1, t / 0.004)
    rel = np.clip((dur - t) / 0.25, 0, 1)
    return vel * out * att * rel


def pad(notes, length):
    n = int((length + 1.2) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for m in notes:
        while m < 50:
            m += 12
        f = midi_hz(m)
        for det in (-0.0012, 0.0012):
            out += np.sin(2 * np.pi * f * (1 + det) * t) + 0.18 * np.sin(2 * np.pi * 2 * f * (1 + det) * t)
    env = np.clip(t / 0.9, 0, 1) * np.clip((length + 1.0 - t) / 1.0, 0, 1)
    return 0.012 * out * env


def band(sig, lo, hi):
    spec = np.fft.rfft(sig)
    fr = np.fft.rfftfreq(len(sig), 1 / SR)
    spec *= ((fr > lo) & (fr < hi)).astype(float)
    return np.fft.irfft(spec, len(sig))


def main(score_path, events_path, out_path):
    score = json.load(open(score_path))
    ev = json.load(open(events_path))
    dur = ev['duration']
    n_total = int(dur * SR)
    music = np.zeros((2, n_total))
    sfx = np.zeros((2, n_total))

    def add(buf, sig, t0, pan=0.0):
        i = int(t0 * SR)
        if i >= n_total or i < 0:
            return
        sig = sig[: n_total - i]
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        buf[0, i:i + len(sig)] += sig * l * 1.414
        buf[1, i:i + len(sig)] += sig * r * 1.414

    for b0, b1, notes in score['chords']:
        t0, t1 = b0 * BEAT, b1 * BEAT
        for j, m in enumerate(notes):
            vel = 0.10 if m < 45 else 0.075
            add(music, piano(m, (t1 - t0) + 1.6, vel), t0 + j * 0.028, pan=(j / max(1, len(notes) - 1) - 0.5) * 0.5)
        add(music, pad(notes, t1 - t0), t0)
    for b, m in score.get('melody', []):
        add(music, piano(m, 3.0, 0.05), b * BEAT, pan=0.15)

    for e in ev['events']:
        if e['type'] in ('key', 'press'):
            n = int(0.012 * SR)
            s = band(rng.standard_normal(n), 1800, 7000) * np.exp(-np.arange(n) / SR / 0.0025)
            gain = 0.035 if e['type'] == 'key' else 0.06
            add(sfx, s * gain * rng.uniform(0.7, 1.1), e['t'], pan=rng.uniform(-0.2, 0.2))
        elif e['type'] == 'paper':
            n = int(0.55 * SR)
            tt = np.arange(n) / n
            s = band(rng.standard_normal(n), 1200, 6500) * np.sin(np.pi * tt) ** 2
            add(sfx, s * 0.018, e['t'], pan=0.1)
        elif e['type'] == 'seal':
            n = int(0.6 * SR)
            t = np.arange(n) / SR
            f = 60 + 60 * np.exp(-t / 0.06)
            body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
            click = band(rng.standard_normal(n), 200, 2500) * np.exp(-t / 0.008)
            add(sfx, 0.20 * body + 0.04 * click, e['t'])

    ir_n = int(2.4 * SR)
    ti = np.arange(ir_n) / SR

    def reverb(x, seed):
        r = np.random.default_rng(seed)
        ir = band(r.standard_normal(ir_n), 80, 6000) * np.exp(-ti / 0.55)
        ir[0] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        size = 1 << int(np.ceil(np.log2(len(x) + ir_n)))
        return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]

    mix = np.zeros((2, n_total))
    for ch in range(2):
        mix[ch] = music[ch] + 0.32 * reverb(music[ch], 11 + ch) + sfx[ch] + 0.12 * reverb(sfx[ch], 21 + ch)

    fade = np.ones(n_total)
    fl = int(1.2 * SR)
    fade[-fl:] = np.linspace(1, 0, fl) ** 1.5
    fi = int(0.02 * SR)
    fade[:fi] = np.linspace(0, 1, fi)
    mix *= fade
    mix /= np.max(np.abs(mix)) / 0.89

    pcm = (mix.T * 32767).astype('<i2')
    with wave.open(out_path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(out_path, round(dur, 2), 's,', len(ev['events']), 'olay')


if __name__ == '__main__':
    main(*sys.argv[1:4])
