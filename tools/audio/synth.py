"""Boîte à outils de synthèse pour l'audio de Xɛvioso (sons originaux, calculés).

Tout est en float64, mono, à SR Hz ; les fonctions renvoient des tableaux numpy.
Instruments inspirés des orchestres du sud du Bénin :
  * gankogui / gankpanvi : cloche double en fer forgé (deux tons, partiels inharmoniques) ;
  * axatsɛ : calebasse-hochet (bruit filtré, grains) ;
  * tambours à peau (kaganu, kidi, sogo, atsimevu, sato) : membrane accordée, frappe ouverte,
    étouffée ou claquée, glissement de hauteur (« tambour parlant ») ;
  * tambour d'eau (tchinkoumé) : calebasse retournée sur l'eau, son grave et mouillé ;
  * jarre (zinli) : jarre de terre frappée sur l'ouverture, son creux ;
  * agidigbo : grand lamellophone en caisse, lames métalliques, léger frisement ;
  * voix (chœur « a »/« o ») par filtres de formants.
"""
import math, os, subprocess, tempfile
import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def silence(dur):
    return np.zeros(int(dur * SR))


# ---------------------------------------------------------------------------
# Enveloppes, bruits, filtres
# ---------------------------------------------------------------------------
def env_exp(n, decay, attack=0.002):
    """Attaque linéaire courte puis décroissance exponentielle (decay : temps à -60 dB, s)."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    return a * np.exp(-6.9 * t / max(decay, 1e-4))


def env_adsr(n, a, d, s, r):
    t = np.arange(n) / SR
    dur = n / SR
    e = np.where(t < a, t / max(a, 1e-5),
                 np.where(t < a + d, 1 - (1 - s) * (t - a) / max(d, 1e-5), s))
    rel = np.clip((dur - t) / max(r, 1e-5), 0, 1)
    return e * rel


def noise(n, kind="white", rng=None):
    rng = rng or RNG
    w = rng.standard_normal(n)
    if kind == "white":
        return w
    if kind == "pink":
        b, a = [0.049922035, -0.095993537, 0.050612699, -0.004408786], [1, -2.494956002, 2.017265875, -0.522189400]
        return signal.lfilter(b, a, w) * 3
    if kind == "brown":
        x = signal.lfilter([1], [1, -0.995], w)
        x = hp(x, 20)
        return x / (np.abs(x).max() + 1e-9)
    raise ValueError(kind)


def bp(x, lo, hi, order=2):
    nyq = SR / 2
    lo, hi = max(lo, 10) / nyq, min(hi, nyq * 0.98) / nyq
    sos = signal.butter(order, [lo, hi], btype="band", output="sos")
    return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    sos = signal.butter(order, min(f, SR * 0.49) / (SR / 2), btype="low", output="sos")
    return signal.sosfilt(sos, x)


def hp(x, f, order=2):
    sos = signal.butter(order, max(f, 10) / (SR / 2), btype="high", output="sos")
    return signal.sosfilt(sos, x)


def sweep_lp(x, f0, f1):
    """Filtre passe-bas dont la coupure glisse de f0 à f1 (par blocs)."""
    out = np.zeros_like(x)
    blk = 512
    nb = max(1, len(x) // blk + 1)
    zi = None
    for i in range(nb):
        s = x[i * blk:(i + 1) * blk]
        if len(s) == 0:
            break
        k = i / max(1, nb - 1)
        f = f0 * (f1 / f0) ** k
        b, a = signal.butter(2, min(f, SR * 0.45) / (SR / 2), btype="low")
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        y, zi = signal.lfilter(b, a, s, zi=zi)
        out[i * blk:i * blk + len(s)] = y
    return out


def resonator(x, f, q):
    """Résonance étroite (peak) autour de f."""
    b, a = signal.iirpeak(min(f, SR * 0.45) / (SR / 2), q)
    return signal.lfilter(b, a, x)


def formant(x, vowel="a"):
    F = {"a": [(800, 1.0, 80), (1150, 0.5, 90), (2900, 0.25, 120)],
         "o": [(450, 1.0, 70), (800, 0.4, 80), (2830, 0.15, 100)],
         "u": [(325, 1.0, 50), (700, 0.25, 60), (2530, 0.08, 100)],
         "e": [(400, 1.0, 60), (2000, 0.4, 100), (2550, 0.3, 120)],
         "m": [(280, 1.0, 50), (1300, 0.1, 80), (2500, 0.05, 100)]}[vowel]
    out = np.zeros_like(x)
    for f, g, bw in F:
        out += g * resonator(x, f, f / bw)
    return out


# ---------------------------------------------------------------------------
# Réverbération (réponse impulsionnelle synthétique) et utilitaires
# ---------------------------------------------------------------------------
_IR = {}


def reverb(x, room=1.2, damp=4000, wet=0.25, pre=0.012):
    key = (room, damp, pre)
    if key not in _IR:
        n = int(room * SR)
        t = np.arange(n) / SR
        ir = RNG.standard_normal(n) * np.exp(-6.9 * t / room)
        ir = lp(ir, damp)
        ir = np.concatenate([np.zeros(int(pre * SR)), ir])
        ir /= np.sqrt((ir ** 2).sum())
        _IR[key] = ir
    y = signal.fftconvolve(x, _IR[key])[:len(x) + len(_IR[key]) - 1]
    out = np.zeros(len(y))
    out[:len(x)] += x * (1 - wet * 0.5)
    out += y * wet
    return out


def fit(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def place(dst, src, at, gain=1.0):
    i = int(at * SR)
    if i >= len(dst):
        return
    j = min(len(dst), i + len(src))
    dst[i:j] += src[:j - i] * gain


def normalize(x, peak=0.9):
    m = np.abs(x).max()
    return x if m == 0 else x * (peak / m)


def fade(x, fin=0.005, fout=0.02):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x


def soft_clip(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def pitch_env(n, f0, f1, tau):
    """Fréquence instantanée qui glisse de f0 vers f1 (constante de temps tau)."""
    t = np.arange(n) / SR
    return f1 + (f0 - f1) * np.exp(-t / tau)


def osc(freq, kind="sine", phase=0.0):
    """Oscillateur ; freq : scalaire ou tableau (fréquence instantanée)."""
    if np.isscalar(freq):
        raise ValueError("passer un tableau de fréquences")
    ph = 2 * np.pi * np.cumsum(freq) / SR + phase
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if kind == "square":
        return np.sign(np.sin(ph))
    raise ValueError(kind)


def const(f, dur):
    return np.full(int(dur * SR), float(f))


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------
def bell(f=1150.0, dur=0.6, vel=1.0, bright=1.0):
    """Gankogui : cloche de fer forgé (partiels inharmoniques, attaque métallique)."""
    n = int(dur * SR)
    out = np.zeros(n)
    parts = [(1.0, 1.0, dur), (2.32, 0.55 * bright, dur * 0.5), (3.9, 0.35 * bright, dur * 0.3),
             (5.6, 0.2 * bright, dur * 0.18), (0.5, 0.15, dur * 0.8)]
    for r, g, d in parts:
        out += g * osc(const(f * r * (1 + 0.002 * RNG.standard_normal()), dur)) * env_exp(n, d, 0.0008)
    click = bp(noise(n), f * 1.5, f * 6) * env_exp(n, 0.012, 0.0003) * 0.6
    return (out + click) * vel


def shaker(dur=0.09, vel=1.0, bright=1.0):
    """Axatsɛ : hochet de calebasse (grains de bruit filtrés)."""
    n = int(dur * SR)
    x = noise(n)
    grains = (RNG.random(n) < 0.08).astype(float)
    x = x * (0.6 + grains * 2.0)
    x = bp(x, 2500 * bright, 9000) * env_adsr(n, 0.01, 0.02, 0.4, dur * 0.6)
    return x * vel * 0.8


def drum(f=180.0, kind="open", dur=0.5, vel=1.0, bend=0.0, body=1.0):
    """Tambour à peau : open (ouvert, résonant), mute (étouffé), slap (claqué), bass (frappe au centre).
    bend : glissement de hauteur en demi-tons pendant la note (tambour parlant)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    drop = {"open": 1.25, "mute": 1.15, "slap": 1.5, "bass": 1.6}[kind]
    tau = {"open": 0.02, "mute": 0.012, "slap": 0.01, "bass": 0.03}[kind]
    fr = pitch_env(n, f * drop, f, tau) * 2 ** (bend * np.clip(t / 0.25, 0, 1) / 12)
    dec = {"open": 0.45, "mute": 0.09, "slap": 0.12, "bass": 0.6}[kind] * body
    tone = osc(fr) + 0.35 * osc(fr * 1.59) * env_exp(n, dec * 0.4) + 0.15 * osc(fr * 2.14) * env_exp(n, dec * 0.25)
    tone *= env_exp(n, dec, 0.001)
    hit = noise(n) * env_exp(n, {"open": 0.02, "mute": 0.015, "slap": 0.05, "bass": 0.02}[kind], 0.0003)
    hit = bp(hit, f * 2, {"slap": 9000, "mute": 3000}.get(kind, 5000)) * {"slap": 1.4}.get(kind, 0.5)
    return (tone + hit) * vel


def water_drum(f=90.0, dur=0.7, vel=1.0):
    """Tchinkoumé : calebasse retournée sur l'eau ; grave, rond, avec un « gloup » mouillé."""
    n = int(dur * SR)
    fr = pitch_env(n, f * 1.8, f * 0.92, 0.05)
    x = osc(fr) * env_exp(n, dur * 0.7, 0.002)
    x += 0.4 * osc(fr * 2.2) * env_exp(n, 0.12)
    # le « gloup » : petite bulle qui remonte en fréquence
    m = int(0.08 * SR)
    bub = np.zeros(n)
    bub[:m] = osc(np.linspace(300, 900, m)) * env_exp(m, 0.06) * 0.25
    slosh = lp(noise(n), 900) * env_exp(n, 0.25, 0.01) * 0.25
    return (x + bub + slosh) * vel


def pot_drum(f=110.0, dur=0.6, vel=1.0, open_=1.0):
    """Zinli : jarre de terre frappée sur l'ouverture ; son creux, formant de cavité."""
    n = int(dur * SR)
    fr = pitch_env(n, f * 1.3, f, 0.03)
    x = osc(fr) * env_exp(n, dur * 0.8, 0.002)
    air = resonator(noise(n), f * 3.1, 8) * env_exp(n, 0.08, 0.001) * 0.6 * open_
    thud = lp(noise(n), 400) * env_exp(n, 0.03) * 0.5
    return (x + air + thud) * vel


def agidigbo(f=196.0, dur=1.2, vel=1.0, buzz=0.35):
    """Agidigbo : lamellophone en caisse ; lame métallique pincée, caisse grave, frisement."""
    n = int(dur * SR)
    fr = const(f, dur) * (1 + 0.003 * np.exp(-np.arange(n) / SR / 0.02))
    x = osc(fr) * env_exp(n, dur, 0.002)
    x += 0.30 * osc(fr * 2.0) * env_exp(n, dur * 0.35)
    x += 0.18 * osc(fr * 5.4) * env_exp(n, 0.09)          # partiel métallique de la lame
    box = resonator(x, f * 0.98, 6) * 0.4                   # résonance de la caisse
    pluck = bp(noise(n), 1500, 6000) * env_exp(n, 0.006, 0.0002) * 0.35
    y = x + box + pluck
    # frisement : anneau métallique posé sur la lame, qui vibre contre elle
    rattle = (np.abs(osc(fr * 1.0)) > 0.92).astype(float) * bp(noise(n), 3000, 8000) * env_exp(n, dur * 0.4)
    return (y + rattle * buzz * 0.3) * vel


def voice(f=220.0, dur=1.5, vowel="a", vel=1.0, vib=5.0, breath=0.15, attack=0.12):
    """Voix chantée (une) : dent de scie + vibrato, passée dans les formants."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    vibr = 1 + 0.006 * np.sin(2 * np.pi * vib * t) * np.clip(t / 0.3, 0, 1)
    src = osc(const(f, dur) * vibr, "saw") + breath * noise(n)
    y = formant(src, vowel)
    return y * env_adsr(n, attack, 0.1, 0.85, min(0.25, dur * 0.4)) * vel * 0.5


def choir(freqs, dur=3.0, vowel="a", vel=1.0, detune=0.004):
    out = np.zeros(int(dur * SR))
    for f in freqs:
        for k in (-1, 0, 1):
            out += voice(f * (1 + k * detune), dur, vowel, 0.33, vib=4.5 + RNG.random(), attack=0.4)
    return out * vel


def thunder(dur=3.0, vel=1.0, close=0.5, seed=0):
    """Tonnerre : craquement (proche) puis grondement de bruit brun qui roule."""
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    rumble = lp(noise(n, "white", rng), 140, 4)
    mod = lp(np.abs(rng.standard_normal(n)), 6, 2)
    mod = mod / (mod.max() + 1e-9)
    rumble *= (0.4 + mod) * np.exp(-t / (dur * 0.45)) * np.clip(t / 0.15, 0, 1)
    rumble = normalize(rumble, 1.0)
    crack = hp(noise(n, "white", rng), 800) * env_exp(n, 0.25, 0.001)
    crack += bp(noise(n, "white", rng), 200, 3000) * env_exp(n, 0.6, 0.002) * 0.6
    return (rumble * 0.9 + crack * close * 0.7) * vel


def to_stereo(x, width=0.0, pan=0.0):
    l = x * math.cos((pan + 1) * math.pi / 4)
    r = x * math.sin((pan + 1) * math.pi / 4)
    if width > 0:
        d = int(0.012 * SR * width)
        r = np.concatenate([np.zeros(d), r])[:len(x)]
    return np.stack([l, r], axis=1)


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
def write_ogg(path, x, quality=4, rate=SR):
    """Écrit un OGG Vorbis (mono ou stéréo) via ffmpeg."""
    x = np.asarray(x, dtype=np.float64)
    if x.ndim == 1:
        ch = 1
        data = x
    else:
        ch = x.shape[1]
        data = x.reshape(-1)
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype("<i2").tobytes()
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
           "-ar", str(rate), "-c:a", "libvorbis", "-q:a", str(quality), path]
    subprocess.run(cmd, input=pcm, check=True)


def write_wav(path, x):
    from scipy.io import wavfile
    wavfile.write(path, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
