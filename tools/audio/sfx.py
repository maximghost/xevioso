"""Bruitages et ambiances de Xɛvioso (calculés avec synth.py).

Sortie : <dest>/sfx/<nom>.ogg (mono) et <dest>/amb/<nom>.ogg (boucles mono).
Les variantes d'un même son portent un suffixe _1, _2... (le jeu en tire une au hasard).
"""
import sys, math
import numpy as np
from synth import *

DEST = sys.argv[1] if len(sys.argv) > 1 else "out"
SFX = {}
AMB = {}


def sfx(name, peak=0.85):
    def deco(fn):
        SFX[name] = (fn, peak)
        return fn
    return deco


def rng(seed):
    return np.random.default_rng(seed)


def loopify(x, length, cross=0.4):
    """Boucle sans couture : la queue (au-delà de length) se fond dans le début."""
    L, C = int(length * SR), int(cross * SR)
    x = fit(x, L + C)
    out = x[:L].copy()
    w = np.linspace(0, 1, C)
    out[:C] = x[:C] * np.sqrt(w) + x[L:L + C] * np.sqrt(1 - w)
    return out


def whoosh(dur, f0, f1, f2=None, q=1.0, seed=0, amp=1.0):
    """Souffle : bruit filtré dont la bande glisse de f0 à f1 (puis f2), enveloppe en cloche."""
    r = rng(seed)
    n = int(dur * SR)
    x = r.standard_normal(n)
    out = np.zeros(n)
    blk = 256
    for i in range(0, n, blk):
        k = i / n
        if f2 is None:
            fc = f0 * (f1 / f0) ** k
        else:
            fc = f0 * (f1 / f0) ** (k * 2) if k < 0.5 else f1 * (f2 / f1) ** ((k - 0.5) * 2)
        s = x[max(0, i - 2048):i + blk]
        y = bp(s, fc / (1.6 * q), fc * 1.6 * q)
        out[i:i + blk] = y[-len(x[i:i + blk]):]
    t = np.arange(n) / n
    return out * np.sin(np.pi * t) ** 1.5 * amp


def crackle(dur, density=300, seed=0, lo=2000, hi=9000):
    """Crépitement électrique : impulsions aléatoires filtrées."""
    r = rng(seed)
    n = int(dur * SR)
    imp = (r.random(n) < density / SR) * r.standard_normal(n) * 3
    return bp(imp, lo, hi) + bp(r.standard_normal(n), lo, hi) * 0.05


def tone(f, dur, kind="sine", decay=None, attack=0.003):
    n = int(dur * SR)
    return osc(const(f, dur), kind) * env_exp(n, decay or dur, attack)


def chime(notes, step=0.07, dur=0.9, bright=1.0, f_mul=1.0):
    out = silence(step * len(notes) + dur)
    for i, m in enumerate(notes):
        place(out, bell(midi(m) * f_mul, dur, 0.7, bright), i * step)
    return out


# ---------------------------------------------------------------------------
# Héros
# ---------------------------------------------------------------------------
for v in range(4):
    def _step(v=v):
        r = rng(10 + v)
        n = int(0.16 * SR)
        thump = lp(r.standard_normal(n), 180 + v * 25) * env_exp(n, 0.05, 0.002) * 2.2
        grit = bp(r.standard_normal(n) * (r.random(n) < 0.25), 1200, 5500) * env_exp(n, 0.07, 0.004) * 0.9
        return thump + grit
    sfx(f"step_{v + 1}", 0.5)(_step)

for v in range(2):
    @sfx(f"jump_{v + 1}", 0.55)
    def _jump(v=v):
        return mix(whoosh(0.2, 500 + 80 * v, 2600, seed=20 + v), lp(noise(int(0.2 * SR)), 600) * env_exp(int(0.2 * SR), 0.06) * 0.3)

for v in range(2):
    @sfx(f"land_{v + 1}", 0.6)
    def _land(v=v):
        n = int(0.22 * SR)
        r = rng(30 + v)
        boom = osc(pitch_env(n, 140, 60, 0.03)) * env_exp(n, 0.12)
        dust = bp(r.standard_normal(n), 800, 4000) * env_exp(n, 0.12, 0.005) * 0.5
        return boom + dust


@sfx("land_hard", 0.8)
def _land_hard():
    n = int(0.4 * SR)
    boom = osc(pitch_env(n, 120, 45, 0.05)) * env_exp(n, 0.25)
    dust = bp(noise(n), 500, 4000) * env_exp(n, 0.25, 0.005) * 0.6
    return boom * 1.2 + dust


for v in range(2):
    @sfx(f"throw_{v + 1}", 0.7)
    def _throw(v=v):
        w = whoosh(0.28, 380 + 60 * v, 2200, 700, seed=40 + v)
        glint = bell(2900 + 200 * v, 0.25, 0.12)
        out = mix(w, glint)
        place(out, crackle(0.12, 400, seed=41 + v) * env_exp(int(0.12 * SR), 0.1) * 0.3, 0.05)
        return out


@sfx("axe_whirr", 0.5)
def _whirr():
    # 0,5 s, 7 tours (14 Hz) : boucle exacte
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    x = bp(noise(n + 4096), 600, 2400)[4096:]
    am = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t)) ** 3
    hum = 0.08 * np.sin(2 * np.pi * 240 * t)
    return loopify(np.concatenate([x * am + hum, x[:int(0.05 * SR)] * am[:int(0.05 * SR)]]), 0.5, 0.04)


@sfx("axe_hit", 0.85)
def _axe_hit():
    thunk = drum(150, "mute", 0.25, 1.2)
    zap = crackle(0.3, 500, seed=50) * env_exp(int(0.3 * SR), 0.25) * 0.6
    ping = bell(1800, 0.3, 0.25)
    return mix(thunk, zap, ping)


@sfx("axe_fizzle", 0.6)
def _fizzle():
    clink = bell(2300, 0.3, 0.4)
    zap = crackle(0.35, 250, seed=51) * np.linspace(1, 0, int(0.35 * SR)) * 0.5
    return mix(clink, zap)


@sfx("dash", 0.9)
def _dash():
    w = whoosh(0.45, 300, 3000, 900, seed=60, amp=1.3)
    z = crackle(0.4, 600, seed=61) * env_exp(int(0.4 * SR), 0.35) * 0.5
    n = int(0.3 * SR)
    rise = osc(np.linspace(300, 1400, n), "saw") * env_exp(n, 0.25) * 0.08
    return mix(w, z, lp(rise, 4000))


def flap(dur=0.12, seed=0, f=1800):
    r = rng(seed)
    n = int(dur * SR)
    return lp(r.standard_normal(n), f) * env_adsr(n, 0.01, 0.03, 0.4, dur * 0.6)


@sfx("glide_open", 0.7)
def _glide_open():
    out = silence(0.4)
    for k in range(3):
        place(out, flap(0.1, 70 + k, 2200 - 300 * k), k * 0.06, 1.0 - 0.2 * k)
    place(out, whoosh(0.3, 800, 300, seed=72) * 0.5, 0.0)
    return out


@sfx("glide_loop", 0.45)
def _glide_loop():
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    x = lp(noise(n + 8000), 1400)[8000:]
    am = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)) ** 2      # 9 battements/s
    wind = bp(noise(n + 8000), 300, 1200)[8000:] * 0.5
    return loopify(np.concatenate([x * am + wind, (x * am + wind)[:int(0.1 * SR)]]), 1.0, 0.1)


@sfx("glide_close", 0.5)
def _glide_close():
    return flap(0.14, 75, 1500)


for v in range(2):
    @sfx(f"hurt_{v + 1}", 0.8)
    def _hurt(v=v):
        n = int(0.35 * SR)
        thud = osc(pitch_env(n, 220, 90, 0.04)) * env_exp(n, 0.15)
        sting = (osc(np.linspace(880 - 80 * v, 520, n), "square") * 0.5 + osc(np.linspace(830, 490, n), "square") * 0.5)
        sting = lp(sting, 2500) * env_exp(n, 0.18) * 0.15
        hit = bp(noise(n), 1000, 5000) * env_exp(n, 0.04) * 0.5
        return thud + sting + hit


@sfx("death", 0.8)
def _death():
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    f = 620 * (0.25 ** (t / 1.3))
    x = lp(osc(f, "tri") * (1 + 0.3 * np.sin(2 * np.pi * 12 * t)), 2000) * env_adsr(n, 0.01, 0.2, 0.6, 0.6) * 0.5
    out = mix(x, drum(90, "bass", 0.6, 0.8))
    return out


@sfx("fall_void", 0.7)
def _fall():
    return whoosh(1.0, 1800, 250, seed=80, amp=1.0)


@sfx("respawn", 0.7)
def _respawn():
    notes = [62, 65, 67, 69, 72]
    out = silence(1.3)
    for i, m in enumerate(notes):
        place(out, agidigbo(midi(m) * 2, 0.8, 0.5, 0.1), i * 0.07)
    place(out, hp(noise(int(0.8 * SR)), 5000) * env_adsr(int(0.8 * SR), 0.3, 0.1, 0.5, 0.4) * 0.08, 0.0)
    return out


@sfx("switch", 0.6)
def _switch():
    out = mix(whoosh(0.18, 600, 2500, seed=90) * 0.6)
    place(out, bell(midi(81), 0.35, 0.35), 0.05)
    place(out, bell(midi(86), 0.4, 0.3), 0.11)
    return out


@sfx("lightning_cast", 0.95)
def _cast():
    # 0,15 s de charge (le geste), puis la foudre tombe (le jeu frappe à 0,16 s)
    out = silence(2.4)
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    charge = lp(osc(300 * 2 ** (t * 12), "saw") * (t / 0.16) ** 2 * 0.15, 3500)
    place(out, charge + crackle(0.16, 300, seed=100) * (t / 0.16) * 0.4, 0.0)
    place(out, thunder(2.0, 1.0, close=1.3, seed=101), 0.15)
    place(out, crackle(1.0, 800, seed=102) * env_exp(int(1.0 * SR), 0.8) * 0.5, 0.15)
    return out


@sfx("lightning_ready", 0.6)
def _ready():
    out = chime([69, 76, 81, 88], 0.06, 1.0, 1.2)
    place(out, thunder(1.6, 0.25, close=0.0, seed=103), 0.1)
    return out


@sfx("sokpe", 0.6)
def _sokpe():
    out = silence(1.2)
    for i, m in enumerate([88, 93, 100]):
        place(out, bell(midi(m), 0.9, 0.5, 1.3) * 0.8, i * 0.06)
    place(out, hp(noise(int(0.6 * SR)), 6000) * env_exp(int(0.6 * SR), 0.5, 0.02) * 0.05, 0.02)
    return out


@sfx("checkpoint", 0.75)
def _checkpoint():
    n = int(0.6 * SR)
    ignite = whoosh(0.6, 200, 1200, 400, seed=110) + lp(noise(n), 500) * env_adsr(n, 0.05, 0.1, 0.5, 0.4) * 0.4
    out = mix(ignite)
    place(out, bell(560, 1.6, 0.6, 0.8), 0.12)
    place(out, bell(560 * 1.5, 1.4, 0.35, 0.8), 0.32)
    return out


@sfx("hero_unlock", 0.8)
def _unlock():
    out = reverb(choir([midi(57), midi(64), midi(69), midi(73)], 2.4, "a", 0.8), 2.0, 5000, 0.4)
    place(out, chime([81, 85, 88, 93], 0.09, 1.4), 0.1)
    return out


@sfx("hammer_slam", 0.95)
def _slam():
    out = mix(drum(60, "bass", 0.9, 1.5), lp(noise(int(0.6 * SR)), 900) * env_exp(int(0.6 * SR), 0.4) * 0.6)
    place(out, bell(700, 0.5, 0.25, 0.6), 0.0)
    for k in range(8):   # graviers qui retombent
        place(out, bp(noise(int(0.04 * SR)), 1500, 6000) * env_exp(int(0.04 * SR), 0.03) * 0.3, 0.15 + k * 0.05)
    return out


@sfx("grapple_throw", 0.6)
def _gthrow():
    return mix(whoosh(0.3, 900, 3500, seed=120), crackle(0.25, 300, seed=121) * 0.1)


@sfx("grapple_attach", 0.6)
def _gattach():
    return mix(bell(1500, 0.25, 0.5), drum(300, "mute", 0.15, 0.6))


@sfx("wave", 0.9)
def _wave():
    out = mix(drum(70, "bass", 1.2, 1.4), whoosh(0.6, 200, 900, 300, seed=130) * 0.6)
    place(out, drum(140, "open", 0.6, 0.6), 0.0)
    return reverb(out, 0.8, 3000, 0.2)


# ---------------------------------------------------------------------------
# Ennemis
# ---------------------------------------------------------------------------
for v in range(2):
    @sfx(f"enemy_hit_{v + 1}", 0.8)
    def _ehit(v=v):
        return mix(drum(340 + 60 * v, "slap", 0.18, 1.0), bp(noise(int(0.12 * SR)), 1500, 6000) * env_exp(int(0.12 * SR), 0.06) * 0.6)


@sfx("crawler_die", 0.8)
def _cdie():
    n = int(0.45 * SR)
    crunch = bp(noise(n) * (RNG.random(n) < 0.3), 900, 5000) * env_exp(n, 0.25) * 1.2
    squish = lp(noise(n), 700) * env_exp(n, 0.2, 0.01) * 0.6
    pop = osc(pitch_env(n, 500, 120, 0.04)) * env_exp(n, 0.1) * 0.7
    return crunch + squish + pop


@sfx("locust_buzz", 0.4)
def _buzz():
    # 1 s, 110 battements d'ailes : boucle exacte
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    wing = osc(const(110, 1.0), "saw") * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t))
    x = bp(wing, 200, 3000) + bp(noise(n), 2000, 6000) * 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * 110 * t))
    return x


@sfx("locust_die", 0.75)
def _ldie():
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    wing = osc(110 * (1 - t / 0.6), "saw") * env_exp(n, 0.35)
    return bp(wing, 150, 3000) + osc(pitch_env(n, 900, 200, 0.03)) * env_exp(n, 0.08) * 0.6


@sfx("spitter_spit", 0.7)
def _spit():
    n = int(0.3 * SR)
    puff = lp(noise(n), 1200) * env_adsr(n, 0.005, 0.05, 0.3, 0.2) * 0.9
    pop = osc(pitch_env(n, 180, 90, 0.03)) * env_exp(n, 0.12)
    return puff + pop


@sfx("clod_splat", 0.7)
def _splat():
    n = int(0.3 * SR)
    return bp(noise(n) * (RNG.random(n) < 0.4), 300, 3500) * env_exp(n, 0.18) + osc(pitch_env(n, 160, 70, 0.02)) * env_exp(n, 0.1) * 0.8


@sfx("spitter_die", 0.85)
def _sdie():
    out = silence(1.0)
    place(out, drum(80, "bass", 0.8, 1.0), 0.0)
    for k in range(14):
        place(out, bp(noise(int(0.06 * SR)), 600, 4000) * env_exp(int(0.06 * SR), 0.05) * (1 - k / 16), 0.05 + k * 0.045)
    place(out, lp(noise(int(0.9 * SR)), 400) * env_exp(int(0.9 * SR), 0.6, 0.02) * 0.5, 0.0)
    return out


@sfx("enemy_poof", 0.6)
def _poof():
    n = int(0.35 * SR)
    return lp(noise(n), 2500) * env_adsr(n, 0.005, 0.08, 0.3, 0.2) + osc(pitch_env(n, 300, 150, 0.05)) * env_exp(n, 0.1) * 0.4


# ---------------------------------------------------------------------------
# Objets et décor
# ---------------------------------------------------------------------------
@sfx("crumble_crack", 0.6)
def _crack():
    out = silence(0.5)
    for k in range(5):
        place(out, bp(noise(int(0.03 * SR)), 1500, 7000) * env_exp(int(0.03 * SR), 0.02) * (0.6 + 0.4 * RNG.random()), k * 0.08 + 0.02 * RNG.random())
    place(out, lp(noise(int(0.4 * SR)), 300) * env_exp(int(0.4 * SR), 0.3, 0.02) * 0.4, 0.0)
    return out


@sfx("crumble_fall", 0.75)
def _cfall():
    out = mix(lp(noise(int(0.9 * SR)), 500) * env_adsr(int(0.9 * SR), 0.02, 0.2, 0.5, 0.6))
    for k in range(12):
        place(out, bp(noise(int(0.05 * SR)), 800, 5000) * env_exp(int(0.05 * SR), 0.04) * 0.5, k * 0.06)
    return out


@sfx("block_smash", 0.9)
def _smash():
    out = mix(drum(90, "bass", 0.5, 1.0), bp(noise(int(0.5 * SR)), 400, 6000) * env_exp(int(0.5 * SR), 0.25) * 0.9)
    for k in range(10):
        place(out, bp(noise(int(0.04 * SR)), 1200, 6000) * env_exp(int(0.04 * SR), 0.03) * 0.4, 0.1 + k * 0.05)
    return out


@sfx("gate_open", 0.7)
def _gate():
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    rumble = lp(noise(n), 250) * env_adsr(n, 0.1, 0.2, 0.7, 0.4) * 0.8
    creak = resonator(noise(n) * (RNG.random(n) < 0.02) * 6, 600 + 300 * np.sin(t.mean()), 30)
    creak = bp(creak, 300, 2000) * env_adsr(n, 0.2, 0.3, 0.6, 0.4) * 0.6
    return rumble + creak


@sfx("drum_target", 0.85)
def _dtarget():
    # le gong de bronze frappé par la hache : grave, long, avec un battement
    g = mix(bell(196, 2.6, 1.0, 0.7), bell(197.5, 2.6, 0.6, 0.5), bell(392 * 1.01, 1.4, 0.25, 0.6))
    return reverb(mix(g, drum(220, "mute", 0.1, 0.4)), 1.2, 4000, 0.25)


@sfx("bloom", 0.8)
def _bloom():
    out = reverb(choir([midi(60), midi(67), midi(72), midi(76)], 3.2, "a", 0.7), 2.4, 6000, 0.45)
    for i, m in enumerate([60, 64, 67, 72, 76, 79, 84]):
        place(out, agidigbo(midi(m), 1.2, 0.5, 0.15), 0.2 + i * 0.12)
    place(out, chime([96, 100, 103], 0.1, 1.2), 1.0)
    return out


for v in range(2):
    sfx(f"thunder_far_{v + 1}", 0.7)(lambda v=v: thunder(7.0, 1.0, close=0.0, seed=200 + v))
    sfx(f"thunder_close_{v + 1}", 0.95)(lambda v=v: thunder(6.5, 1.0, close=1.0, seed=210 + v))


@sfx("wrath", 0.95)
def _wrath():
    n = int(4.5 * SR)
    t = np.arange(n) / SR
    quake = lp(noise(n), 90, 4) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t)) * env_adsr(n, 0.8, 0.5, 0.8, 1.5)
    return normalize(quake) + lp(noise(n) * (RNG.random(n) < 0.01) * 4, 2000) * env_adsr(n, 0.5, 0.5, 0.6, 1.0) * 0.3


# ---------------------------------------------------------------------------
# Interface
# ---------------------------------------------------------------------------
@sfx("ui_click", 0.5)
def _click():
    return mix(drum(520, "mute", 0.1, 0.8), bell(1700, 0.12, 0.15))


@sfx("ui_move", 0.3)
def _move():
    return drum(700, "mute", 0.06, 0.6)


@sfx("ui_back", 0.45)
def _back():
    return mix(drum(380, "mute", 0.12, 0.8), bell(1200, 0.12, 0.1))


@sfx("pause_open", 0.55)
def _popen():
    out = mix(pot_drum(130, 0.4, 0.8))
    place(out, shaker(0.12, 0.5), 0.05)
    return out


@sfx("pause_close", 0.5)
def _pclose():
    out = mix(shaker(0.1, 0.5))
    place(out, pot_drum(170, 0.3, 0.7), 0.04)
    return out


@sfx("dialogue_open", 0.5)
def _dopen():
    return reverb(mix(bell(620, 1.0, 0.5, 0.6), bell(930, 0.8, 0.25, 0.6)), 1.2, 4000, 0.3)


@sfx("dialogue_next", 0.4)
def _dnext():
    return agidigbo(midi(62), 0.4, 0.7, 0.1)


@sfx("text_tick", 0.18)
def _tick():
    return drum(900, "mute", 0.03, 0.5)


@sfx("caption_next", 0.3)
def _cnext():
    return agidigbo(midi(67), 0.35, 0.5, 0.05)


@sfx("game_start", 0.8)
def _gstart():
    out = thunder(2.5, 0.8, close=1.0, seed=230)
    place(out, chime([69, 74, 81], 0.08, 1.2), 0.05)
    return out


# ---------------------------------------------------------------------------
# Scène d'ouverture
# ---------------------------------------------------------------------------
@sfx("stone_shatter", 0.95)
def _shatter():
    out = thunder(2.0, 0.9, close=1.3, seed=300)
    for k in range(18):   # éclats de cristal
        f = 2500 + 4000 * RNG.random()
        place(out, bell(f, 0.4, 0.25, 1.5), 0.02 + k * 0.03 * RNG.random() * 2)
    return out


@sfx("adaka_appear", 0.8)
def _aappear():
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    drone = sum(osc(const(f, 3.0), "saw") for f in (43.0, 43.6, 64.5)) / 3
    drone = lp(drone, 300) * env_adsr(n, 1.2, 0.5, 0.7, 1.0)
    dust = bp(noise(n), 300, 2500) * env_adsr(n, 0.8, 0.5, 0.5, 1.2) * 0.4
    return drone + dust


@sfx("adaka_inhale", 0.85)
def _inhale():
    n = int(3.2 * SR)
    t = np.arange(n) / SR
    x = sweep_lp(noise(n), 200, 5000) * (t / 3.2) ** 1.5
    low = lp(osc(const(55, 3.2), "saw"), 200) * (t / 3.2) * 0.4
    out = x + low
    out[-int(0.08 * SR):] *= np.linspace(1, 0, int(0.08 * SR))
    gulp = osc(pitch_env(int(0.4 * SR), 200, 60, 0.06)) * env_exp(int(0.4 * SR), 0.3)
    full = silence(3.7)
    place(full, out, 0)
    place(full, gulp, 3.15, 1.2)
    return full


@sfx("adaka_laugh", 0.8)
def _laugh():
    out = silence(2.2)
    for k in range(5):   # « ha... ha... ha » grave, guttural, qui descend
        d = 0.26
        n = int(d * SR)
        f = 92 - k * 6
        src = osc(const(f, d) * (1 + 0.02 * np.sin(np.arange(n) / SR * 2 * np.pi * 30)), "saw") + 0.4 * noise(n)
        y = soft_clip(formant(src, "o") * 3, 2.5) * env_adsr(n, 0.02, 0.05, 0.7, 0.1)
        place(out, y, 0.1 + k * 0.33, 1.0 - 0.1 * k)
    return reverb(out, 1.5, 2500, 0.35)


@sfx("wind_stop", 0.6)
def _wstop():
    n = int(2.5 * SR)
    t = np.arange(n) / SR
    return sweep_lp(noise(n), 1500, 150) * np.exp(-t / 0.7)


@sfx("emblem_appear", 0.9)
def _emblem():
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    swell = hp(noise(n), 3000) * (t / 2.0) ** 3 * 0.4                    # cymbale à l'envers
    out = silence(6.0)
    place(out, swell, 0)
    gong = mix(bell(130, 4.0, 1.0, 0.7), bell(196, 3.5, 0.5, 0.6))
    place(out, gong, 2.0)
    place(out, choir([midi(45), midi(52), midi(57)], 3.6, "o", 0.6), 2.0)
    return reverb(out, 2.5, 3500, 0.4)


@sfx("designate", 0.95)
def _designate():
    out = thunder(2.2, 0.8, close=1.4, seed=310)
    place(out, chime([76, 81, 83, 88, 93], 0.07, 1.6), 0.15)
    place(out, choir([midi(64), midi(69), midi(76)], 2.0, "a", 0.5), 0.2)
    return out


for v in range(3):
    @sfx(f"chicken_{v + 1}", 0.45)
    def _cluck(v=v):
        out = silence(0.5)
        for k in range(2 + v % 2):
            d = 0.06
            n = int(d * SR)
            f = 520 + 90 * v + 40 * k
            src = osc(np.linspace(f * 1.2, f, n), "saw")
            place(out, formant(src, "e") * env_adsr(n, 0.005, 0.02, 0.5, 0.03), k * 0.09)
        return out


@sfx("chicken_flap", 0.45)
def _cflap():
    out = silence(0.5)
    for k in range(5):
        place(out, flap(0.06, 330 + k, 2500), k * 0.07, 0.8)
    place(out, _cluck(2) * 0.8, 0.05)
    return out


@sfx("heartbeat", 0.8)
def _heartbeat():
    # deux coups sourds, profonds (lub-dub), comme un cœur énorme dans le bois
    out = silence(0.9)
    for at, g, f in ((0.0, 1.0, 52), (0.2, 0.7, 46)):
        n = int(0.45 * SR)
        thump = osc(pitch_env(n, f * 1.8, f, 0.03)) * env_exp(n, 0.3)
        body = lp(noise(n), 160) * env_exp(n, 0.12) * 0.6
        place(out, (thump + body) * g, at)
    return lp(out, 400)


@sfx("tree_groan", 0.8)
def _groan():
    # le gémissement du vieil arbre : craquements de bois lents, grave qui glisse
    n = int(3.2 * SR)
    t = np.arange(n) / SR
    f = 70 + 25 * np.sin(2 * np.pi * t / 3.2) + 8 * np.sin(2 * np.pi * 0.9 * t)
    # frottement : impulsions irrégulières passées dans des résonances de bois
    rate = 18 + 30 * np.sin(np.pi * t / 3.2)
    ph = np.cumsum(rate) / SR
    imp = (np.diff(np.floor(ph), prepend=0) > 0).astype(float) * (0.5 + RNG.random(n))
    creak = resonator(imp, 340, 12) + resonator(imp, 610, 14) * 0.6 + resonator(imp, 1150, 18) * 0.3
    groan = lp(osc(f, "saw"), 300) * 0.5
    env = env_adsr(n, 0.6, 0.4, 0.8, 1.2)
    return reverb((creak * 0.8 + groan) * env, 2.4, 2500, 0.45)


@sfx("drum_roll", 0.8)
def _roll():
    out = silence(2.2)
    for k in range(22):
        place(out, drum(110, "open", 0.4, 0.3 + 0.7 * k / 22), k * 0.08 * (1 - k / 60))
    return reverb(out, 1.0, 3000, 0.2)


@sfx("vine_swish", 0.7)
def _vine_swish():
    """La boule de ronces passe au plus bas : un souffle qui enfle et retombe, un froissement de
    feuilles, le grincement de la liane."""
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    env = np.sin(np.pi * t / t[-1]) ** 2
    whoosh = bp(noise(n), 400, 1800) * env
    leaves = bp(noise(n), 2500, 7000) * env ** 2 * (0.5 + 0.5 * np.sin(2 * np.pi * 40 * t))
    creak = np.sin(2 * np.pi * (180 + 60 * t) * t) * (np.sin(2 * np.pi * 25 * t) > 0.5) * env * 0.15
    return whoosh * 0.9 + leaves * 0.35 + creak


@sfx("bounce", 0.8)
def _bounce():
    """Le champignon qui fait bondir : un « bloup » mou qui monte, sur un petit coup sourd."""
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    f = 140 + 520 * (1 - np.exp(-t * 9)) + 30 * np.sin(2 * np.pi * 18 * t) * np.exp(-t * 6)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)
    thud = lp(noise(n), 300) * np.exp(-t * 40) * 1.4
    return lp(body * 0.8 + thud, 3000)


# ---------------------------------------------------------------------------
# Forêt des irokos (partie 2) : sanctuaire, Tambour parlant, canopée, Adan
# ---------------------------------------------------------------------------
@sfx("armor_clank", 0.75)
def _armor_clank():
    """La hache rebondit sur le Poussiéreux : un choc sourd de terre tassée et un tintement."""
    n = int(0.3 * SR)
    thud = lp(noise(n), 350) * env_exp(n, 0.06) * 1.6
    ting = osc(pitch_env(n, 1400, 1100, 0.05)) * env_exp(n, 0.12) * 0.25
    grit = bp(noise(n), 1500, 5000) * env_exp(n, 0.05) * 0.4
    return thud + ting + grit


@sfx("fall_asleep", 0.5)
def _fall_asleep():
    """Une créature s'endort : un souffle qui descend, deux notes douces."""
    return mix(whoosh(0.6, 1600, 400, seed=91, amp=0.5), chime([79, 74], step=0.18, dur=0.7, bright=0.5) * 0.4)


@sfx("fireflies", 0.45)
def _fireflies():
    """On emporte les lucioles : un scintillement de petites clochettes qui montent."""
    return chime([84, 88, 91, 96, 100], step=0.05, dur=0.6, bright=1.3) * 0.6


@sfx("rat_squeak", 0.5)
def _rat_squeak():
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    f = 2900 + 1100 * np.sin(np.pi * t / t[-1])
    sq = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.hanning(n)
    m = int(0.35 * SR)
    steps = bp(noise(m), 1500, 6000) * (np.sin(2 * np.pi * 19 * np.arange(m) / SR) > 0.6) * np.hanning(m) * 0.6
    out = silence(0.45)
    place(out, sq, 0.0); place(out, steps, 0.08)
    return out


for v, (f, bend) in enumerate(((120.0, -1.0), (170.0, 0.0), (240.0, 1.0))):
    def _drum_voice(f=f, bend=bend):
        """Tambour-arbre à fente : bois creux frappé, résonance de la cavité (grave, médium, aigu)."""
        n = int(1.2 * SR)
        body = drum(f, "open", 1.2, 1.0, bend=bend, body=1.4)
        wood = resonator(noise(n) * env_exp(n, 0.01), f * 2.7, 14) * 0.5
        knock = bp(noise(n), 800, 3500) * env_exp(n, 0.012) * 0.6
        return reverb(body + wood + knock, room=1.6, damp=5000, wet=0.25)
    sfx(f"drum_voice_{v}", 0.85)(_drum_voice)

for v, f in enumerate((1300.0, 1700.0, 2250.0)):
    def _bird_note(f=f):
        """L'oiseau siffle la voix du tambour : une note pure, un petit glissé vers le haut."""
        n = int(0.32 * SR)
        t = np.arange(n) / SR
        fr = f * (1 + 0.06 * np.clip(t / 0.08, 0, 1)) * (1 + 0.012 * np.sin(2 * np.pi * 22 * t))
        x = np.sin(2 * np.pi * np.cumsum(fr) / SR) * env_adsr(n, 0.01, 0.05, 0.8, 0.12)
        return reverb(x + 0.25 * np.sin(2 * np.pi * np.cumsum(fr * 2) / SR) * env_adsr(n, 0.01, 0.05, 0.6, 0.1), room=1.0, wet=0.2)
    sfx(f"bird_note_{v}", 0.6)(_bird_note)


@sfx("bird_call", 0.55)
def _bird_call():
    """Le touraco annonce son chant : « kow kow kow ». """
    out = silence(0.8)
    for k in range(3):
        n = int(0.09 * SR)
        t = np.arange(n) / SR
        x = np.sin(2 * np.pi * (700 - 120 * t / t[-1]) * t)
        x = lp(x + 0.4 * np.sign(x) * 0.3, 2200) * env_adsr(n, 0.005, 0.02, 0.8, 0.03)
        place(out, x, k * 0.2)
    return out


@sfx("bird_happy", 0.6)
def _bird_happy():
    out = silence(1.2)
    for k, f in enumerate((1700, 2250, 1900, 2600, 2250, 3000)):
        n = int(0.1 * SR)
        t = np.arange(n) / SR
        place(out, np.sin(2 * np.pi * f * (1 + 0.1 * t / t[-1]) * t) * np.hanning(n), k * 0.12)
    return reverb(out, room=1.0, wet=0.2)


@sfx("puzzle_good", 0.55)
def _pgood():
    return chime([76, 83], step=0.08, dur=0.7, bright=0.9)


@sfx("puzzle_bad", 0.7)
def _pbad():
    n = int(0.6 * SR)
    return lp(osc(pitch_env(n, 160, 70, 0.2), "saw"), 900) * env_exp(n, 0.35) * 0.7 + lp(noise(n), 300) * env_exp(n, 0.1) * 0.5


@sfx("puzzle_timeout", 0.5)
def _ptime():
    return chime([79, 74, 70], step=0.12, dur=0.6, bright=0.4) * 0.6


@sfx("puzzle_solved", 0.85)
def _psolved():
    out = chime([64, 71, 76, 79, 83, 88], step=0.09, dur=1.6, bright=1.1)
    return reverb(mix(out, choir([midi(64), midi(71), midi(76)], 2.0, "a", 0.5) * 0.5), room=2.0, wet=0.35)


@sfx("roots_open", 0.85)
def _roots_open():
    """La porte de racines s'enfonce : craquements de bois, frottement de terre, grondement."""
    n = int(1.4 * SR)
    rumble = lp(noise(n), 120) * env_adsr(n, 0.1, 0.3, 0.7, 0.4) * 1.2
    creak = np.zeros(n)
    r = rng(71)
    for k in range(9):
        m = int(r.uniform(0.05, 0.14) * SR); i = int(r.uniform(0, 1.2) * SR)
        tt = np.arange(m) / SR
        c = np.sin(2 * np.pi * r.uniform(150, 400) * tt) * (np.sin(2 * np.pi * r.uniform(30, 60) * tt) > 0.3) * np.hanning(m)
        creak[i:i + m] += c[:max(0, min(m, n - i))] * 0.5
    soil = bp(noise(n), 400, 2500) * env_adsr(n, 0.05, 0.4, 0.5, 0.5) * 0.4
    return rumble + creak + soil


@sfx("roots_close", 0.85)
def _roots_close():
    n = int(0.6 * SR)
    burst = lp(noise(n), 200) * env_exp(n, 0.2, 0.005) * 1.4
    snap = bp(noise(n), 900, 4000) * env_exp(n, 0.05) * 0.8
    return burst + snap


@sfx("root_grow", 0.7)
def _root_grow():
    """Une racine sacrée pousse : bois qui s'étire en craquant vers le haut, une note claire."""
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    groan = lp(osc(80 + 140 * t / t[-1], "saw"), 700) * env_adsr(n, 0.05, 0.2, 0.6, 0.2) * 0.4
    crk = bp(noise(n) * (rng(5).random(n) < 0.02), 1200, 5000) * 2.0
    return groan + crk + fit(chime([86], dur=0.6, bright=0.7), n) * 0.25


@sfx("root_shrink", 0.5)
def _root_shrink():
    return mix(whoosh(0.5, 900, 250, seed=33, amp=0.6), lp(noise(int(0.5 * SR)), 200) * env_exp(int(0.5 * SR), 0.2) * 0.4)


for name, f, bend in (("talking_drum_hi", 230.0, 3.0), ("talking_drum_lo", 170.0, -3.0)):
    def _talk(f=f, bend=bend):
        """Le Tambour parlant : la peau tendue par les cordes, la note glisse comme une parole."""
        return reverb(mix(drum(f, "open", 0.5, 1.0, bend=bend, body=1.2), drum(f * 0.5, "bass", 0.4, 0.4)), room=1.2, wet=0.2)
    sfx(name, 0.85)(_talk)


@sfx("wind_gust", 0.6)
def _wind_gust():
    return mix(whoosh(1.8, 300, 1400, 500, q=0.8, seed=44, amp=1.0), whoosh(1.8, 2000, 5000, 2500, q=1.2, seed=45, amp=0.25))


@sfx("adan_roar", 0.95)
def _adan_roar():
    """Le rugissement d'Adan : une gorge de bois et de braise ; grave, rauque, qui s'étire."""
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    f = 75 + 25 * np.sin(np.pi * t / t[-1]) + 4 * np.sin(2 * np.pi * 7 * t)
    src = osc(f, "saw") + 0.6 * noise(n)
    y = formant(src, "a") * 1.4 + formant(src * 0.7, "o")
    y = soft_clip(y * env_adsr(n, 0.15, 0.4, 0.8, 0.6) * 1.5, 2.0)
    crackle_ = crackle(2.0, 120, seed=6, lo=1500, hi=7000) * env_adsr(n, 0.2, 0.3, 0.6, 0.6) * 0.3
    return reverb(y + crackle_ + lp(noise(n), 90) * env_adsr(n, 0.2, 0.5, 0.7, 0.5) * 0.8, room=2.5, damp=2500, wet=0.35)


@sfx("adan_growl", 0.8)
def _adan_growl():
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    src = osc(60 + 10 * np.sin(2 * np.pi * 9 * t), "saw") + 0.5 * noise(n)
    return soft_clip(formant(src, "o") * env_adsr(n, 0.05, 0.2, 0.7, 0.3) * 2.0, 2.0)


@sfx("adan_charge", 0.85)
def _adan_charge():
    return mix(whoosh(0.9, 200, 900, q=0.7, seed=61, amp=1.0), _adan_growl() * 0.5)


@sfx("adan_crash", 0.95)
def _adan_crash():
    n = int(1.0 * SR)
    boom = osc(pitch_env(n, 90, 40, 0.1)) * env_exp(n, 0.4) * 1.3
    wood = bp(noise(n), 300, 3000) * env_exp(n, 0.25, 0.002) * 0.9
    debris = crackle(1.0, 200, seed=8, lo=800, hi=5000) * env_exp(n, 0.5) * 0.6
    return reverb(mix(boom, wood, debris), room=1.8, wet=0.25)


@sfx("adan_slam", 0.95)
def _adan_slam():
    n = int(1.2 * SR)
    boom = osc(pitch_env(n, 70, 30, 0.12)) * env_exp(n, 0.6) * 1.5
    soil = lp(noise(n), 500) * env_exp(n, 0.4) * 0.9
    fire = bp(noise(n), 1500, 6000) * env_exp(n, 0.3, 0.02) * 0.4
    return reverb(boom + soil + fire, room=2.0, wet=0.3)


@sfx("adan_hit", 0.75)
def _adan_hit():
    n = int(0.35 * SR)
    knock = bp(noise(n), 400, 2500) * env_exp(n, 0.06) * 1.2
    sizzle = bp(noise(n), 3000, 9000) * env_exp(n, 0.2, 0.01) * 0.4
    grunt = formant(osc(const(90, 0.35), "saw"), "o") * env_exp(n, 0.15) * 0.6
    return knock + sizzle + grunt


@sfx("adan_tired", 0.7)
def _adan_tired():
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    pant = formant(noise(n), "a") * (0.5 + 0.5 * np.sin(2 * np.pi * 2.2 * t)) * env_adsr(n, 0.1, 0.3, 0.7, 0.3)
    hiss = bp(noise(n), 2500, 7000) * env_exp(n, 0.8) * 0.3
    return pant + hiss


@sfx("adan_call", 0.7)
def _adan_call():
    return mix(_adan_growl() * 0.6, whoosh(0.8, 600, 2400, seed=62, amp=0.6))


@sfx("adan_death", 0.95)
def _adan_death():
    """Adan s'effondre : un dernier râle qui se brise, le bois qui éclate, la braise qui s'éteint
    dans un long souffle de cendre."""
    n = int(3.5 * SR)
    t = np.arange(n) / SR
    f = 90 - 50 * (t / t[-1])
    rale = formant(osc(f, "saw") + 0.5 * noise(n), "a") * env_adsr(n, 0.1, 0.8, 0.3, 1.5) * 1.3
    cracks = crackle(3.5, 60, seed=9, lo=500, hi=4000) * env_exp(n, 2.0) * 0.9
    ash = bp(noise(n), 2000, 8000) * env_adsr(n, 0.8, 1.0, 0.4, 1.5) * 0.3
    boom = osc(pitch_env(n, 60, 30, 0.3)) * env_exp(n, 1.2) * 1.0
    return reverb(rale + cracks + ash + boom, room=3.0, damp=3000, wet=0.4)


@sfx("spear_throw", 0.7)
def _spear_throw():
    return mix(whoosh(0.4, 600, 2500, seed=63, amp=0.8), crackle(0.4, 200, seed=10) * env_exp(int(0.4 * SR), 0.3) * 0.4)


@sfx("spear_burst", 0.7)
def _spear_burst():
    n = int(0.4 * SR)
    return crackle(0.4, 500, seed=11, lo=1000, hi=7000) * env_exp(n, 0.15) + lp(noise(n), 400) * env_exp(n, 0.06) * 0.6


@sfx("fury_burst", 0.95)
def _fury_burst():
    n = int(1.6 * SR)
    whoom = whoosh(1.6, 150, 1200, 400, q=0.8, seed=64, amp=1.4)
    fire = bp(noise(n), 500, 4000) * env_adsr(n, 0.1, 0.4, 0.6, 0.8) * 0.9
    return reverb(mix(whoom, fire, _adan_roar()[:n] * 0.5), room=2.0, wet=0.3)


@sfx("fire_whoosh", 0.8)
def _fire_whoosh():
    n = int(1.0 * SR)
    return mix(whoosh(1.0, 200, 1500, 700, q=0.7, seed=65, amp=1.0), crackle(1.0, 400, seed=12, lo=1500, hi=8000) * env_exp(n, 0.6) * 0.5)


@sfx("forest_revival", 0.85)
def _revival():
    """La forêt redevient sacrée : un chœur qui s'ouvre, des clochettes, des oiseaux."""
    out = silence(4.0)
    place(out, choir([midi(52), midi(59), midi(64), midi(68)], 3.5, "a", 0.8), 0.0)
    place(out, chime([76, 80, 83, 88, 92, 95], step=0.18, dur=2.0, bright=1.1), 0.6)
    for k, f in enumerate((1900, 2400, 2100, 2800)):
        m = int(0.12 * SR); tt = np.arange(m) / SR
        place(out, np.sin(2 * np.pi * f * (1 + 0.15 * tt / tt[-1]) * tt) * np.hanning(m) * 0.3, 1.5 + k * 0.35)
    return reverb(out, room=3.0, wet=0.4)


@sfx("bat_flutter", 0.35)
def _bat_flutter():
    """Le vol d'une chauve-souris (boucle) : battements secs et rapides de membrane."""
    L = 1.0
    n = int((L + 0.4) * SR)
    t = np.arange(n) / SR
    flaps = (0.5 + 0.5 * np.sin(2 * np.pi * 12 * t)) ** 5
    x = bp(noise(n), 300, 2200) * flaps
    return loopify(x, L, 0.4)


# ---------------------------------------------------------------------------
# Ambiances (boucles)
# ---------------------------------------------------------------------------
def amb(name):
    def deco(fn):
        AMB[name] = fn
        return fn
    return deco


def gusts(n, seed, rate=0.15):
    r = rng(seed)
    m = lp(r.standard_normal(n), rate, 2)
    m = (m - m.min()) / (m.max() - m.min() + 1e-9)
    return m


@amb("wind_dry")
def _wind_dry():
    L = 16.0
    n = int((L + 1.0) * SR)
    g = gusts(n, 400)
    x = bp(noise(n), 180, 1100) * (0.3 + 0.7 * g)
    whistle = bp(noise(n), 1400, 2200) * g ** 3 * 0.25
    return normalize(loopify(x + whistle, L, 1.0), 0.6)


@amb("storm_wind")
def _storm_wind():
    L = 18.0
    n = int((L + 1.0) * SR)
    g = gusts(n, 401, 0.25)
    x = bp(noise(n), 120, 1500) * (0.35 + 0.65 * g)
    out = x * 1.0
    place(out, thunder(5.0, 0.35, close=0.0, seed=402), 3.0)
    place(out, thunder(5.0, 0.3, close=0.0, seed=403), 11.0)
    return normalize(loopify(out, L, 1.0), 0.7)


@amb("village_day")
def _village():
    L = 24.0
    n = int((L + 1.0) * SR)
    out = bp(noise(n), 200, 900) * (0.25 + 0.4 * gusts(n, 410)) * 0.5
    r = rng(411)
    # oiseaux : petites mélodies de sifflets
    for k in range(18):
        at = r.random() * L
        notes = r.integers(2, 6)
        for j in range(notes):
            d = 0.06 + 0.05 * r.random()
            m = int(d * SR)
            f0 = 2600 + 1800 * r.random()
            ch = osc(np.linspace(f0, f0 * (0.8 + 0.5 * r.random()), m)) * env_adsr(m, 0.005, 0.02, 0.6, 0.02)
            place(out, ch * 0.12 * (0.4 + 0.6 * r.random()), at + j * (d + 0.03))
    # poules au loin
    for k in range(5):
        place(out, lp(_cluck(k % 3), 2500) * 0.25, r.random() * L)
    # pilon au loin (thump régulier pendant quelques secondes)
    for k in range(10):
        place(out, lp(drum(95, "mute", 0.2, 0.25), 600), 5.0 + k * 0.62)
    return normalize(loopify(out, L, 1.0), 0.5)


@amb("rain")
def _rain():
    """Pluie (stéréo) : un fond doux et feutré (pas un souffle aigu), des milliers d'impacts
    discrets sur le sol et les feuilles, quelques « plocs » dans les flaques, de grosses
    gouttes sourdes ; chaque canal a ses propres gouttes."""
    L = 12.0
    n = int((L + 0.6) * SR)
    chans = []
    for c in range(2):
        r = rng(420 + c)
        # le fond : bruit rose filtré et feutré, qui respire lentement
        wash = bp(noise(n, "pink", r), 220, 2200, 2)
        wash *= 0.75 + 0.25 * gusts(n, 421 + c, 0.2)
        wash = wash / (np.abs(wash).max() + 1e-9) * 0.28
        # les impacts : impulsions d'intensités très inégales, chacune un tic bref filtré
        out = wash
        for band, (lo, hi, rate) in enumerate(((700, 2200, 420), (1800, 4500, 520), (3200, 6500, 160))):
            imp = (r.random(n) < rate / SR) * r.lognormal(0.0, 1.15, n)
            kern_n = int(0.006 * SR)
            kern = r.standard_normal(kern_n) * np.exp(-np.arange(kern_n) / (kern_n / 4))
            ticks = signal.fftconvolve(imp, kern)[:n]
            ticks = bp(ticks, lo, hi, 2)
            out = out + ticks / (np.abs(ticks).max() + 1e-9) * (0.32, 0.26, 0.14)[band]
        # les « plocs » dans les flaques : petite bulle qui sonne en montant
        for k in range(int(L * 14)):
            at = r.random() * L
            m = int(0.04 * SR)
            f0 = 900 + 2200 * r.random()
            tt = np.arange(m) / SR
            plink = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 3.0 * tt)) / SR) * np.exp(-tt / 0.012)
            place(out, plink * 0.08 * (0.3 + r.random()), at)
        # grosses gouttes sourdes (toits de chaume, sol)
        for k in range(int(L * 25)):
            at = r.random() * L
            m = int(0.03 * SR)
            place(out, lp(r.standard_normal(m), 500) * np.exp(-np.arange(m) / (m / 4)) * 0.25 * r.random(), at)
        out = lp(out, 7000, 4)                              # rien de sifflant au-dessus
        out = reverb(out, 0.6, 3000, 0.15)[:n]
        chans.append(loopify(out, L, 0.6))
    st = np.stack(chans, axis=1)
    return st / (np.abs(st).max() + 1e-9) * 0.7


@amb("night")
def _night():
    L = 12.0
    n = int((L + 0.5) * SR)
    out = bp(noise(n), 150, 600) * 0.15
    r = rng(430)
    for c in range(4):   # quatre grillons, chacun son rythme
        f = 4200 + 600 * c
        period = 0.55 + 0.25 * c
        t0 = r.random() * period
        while t0 < L + 0.5:
            m = int(0.12 * SR)
            tt = np.arange(m) / SR
            chirp = np.sin(2 * np.pi * f * tt) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 45 * tt))) * env_adsr(m, 0.005, 0.02, 0.8, 0.02)
            place(out, chirp * 0.05 * (0.5 + 0.5 * r.random()), t0)
            t0 += period * (0.9 + 0.2 * r.random())
    return normalize(loopify(out, L, 0.5), 0.4)


@amb("forest")
def _forest():
    """Le sous-bois malade : un bourdonnement d'insectes qui pulse (cigales, criquets), des
    chauves-souris qui froufroutent et piaillent, des rats qui détalent dans les feuilles
    en couinant, des gouttes, une branche qui craque. Stéréo, 24 s en boucle : ça ne se tait
    jamais tout à fait, on se sent épié."""
    L = 24.0
    n = int((L + 0.8) * SR)
    r = rng(613)
    out = np.zeros((n, 2))
    tt = np.arange(n) / SR
    def put(x, t, pan, g):
        i = int(t * SR); m = min(len(x), n - i)
        if m <= 0: return
        out[i:i + m, 0] += x[:m] * g * np.cos((pan + 1) * np.pi / 4)
        out[i:i + m, 1] += x[:m] * g * np.sin((pan + 1) * np.pi / 4)
    # insectes : deux nappes de cigales qui pulsent à des rythmes différents (gauche, droite)
    for pan, f0, rate, ph in ((-0.7, 4300, 13.0, 0.0), (0.7, 5200, 17.0, 1.3)):
        bed = bp(noise(n), f0 - 600, f0 + 600)
        am = (0.5 + 0.5 * np.sin(2 * np.pi * rate * tt + ph)) ** 3
        swell = 0.6 + 0.4 * np.sin(2 * np.pi * tt / (L / 3) + ph)     # 3 houles par boucle
        put(bed * am * swell, 0.0, pan, 0.05)
    for k in range(30):                     # criquets : courtes stridulations
        m = int(0.28 * SR); t_ = np.arange(m) / SR
        chirp = np.sin(2 * np.pi * r.uniform(3600, 4400) * t_) * (np.sin(2 * np.pi * 30 * t_) > 0.2) * np.hanning(m)
        put(chirp, r.uniform(0, L), r.uniform(-0.9, 0.9), r.uniform(0.012, 0.025))
    low = lp(noise(n), 160) * 0.07
    out[:, 0] += low; out[:, 1] += low
    for k in range(40):                     # gouttes
        m = int(0.05 * SR); t_ = np.arange(m) / SR
        f0 = r.uniform(1400, 3000)
        put(np.sin(2 * np.pi * (f0 + 2500 * t_) * t_) * np.exp(-t_ * 90), r.uniform(0, L), r.uniform(-0.9, 0.9), r.uniform(0.02, 0.06))
    def bat_flutter(dur):
        m = int(dur * SR); t_ = np.arange(m) / SR
        flaps = (0.5 + 0.5 * np.sin(2 * np.pi * r.uniform(11, 15) * t_)) ** 4
        return bp(noise(m), 300, 1800) * flaps * np.hanning(m)
    def bat_squeak():
        parts = []
        for j in range(r.integers(2, 5)):
            m = int(r.uniform(0.012, 0.025) * SR); t_ = np.arange(m) / SR
            f0 = r.uniform(7000, 9500)
            parts.append(np.sin(2 * np.pi * (f0 - 3000 * t_ / t_[-1] * 0.5) * t_) * np.hanning(m))
            parts.append(np.zeros(int(r.uniform(0.03, 0.06) * SR)))
        return np.concatenate(parts)
    for t in (2.0, 7.5, 11.0, 16.5, 21.0):  # chauves-souris : elles passent d'un côté à l'autre
        dur = r.uniform(0.9, 1.4)
        fl = bat_flutter(dur)
        m = len(fl)
        start = int(t * SR)
        if start + m >= n: continue
        p0, p1 = (-0.9, 0.9) if r.random() < 0.5 else (0.9, -0.9)
        pan = np.linspace(p0, p1, m)
        out[start:start + m, 0] += fl * 0.09 * np.cos((pan + 1) * np.pi / 4)
        out[start:start + m, 1] += fl * 0.09 * np.sin((pan + 1) * np.pi / 4)
        for j in range(2):
            put(bat_squeak(), t + r.uniform(0.1, dur - 0.2), p0 + (p1 - p0) * r.uniform(0.2, 0.8), 0.03)
    def rat():
        m = int(r.uniform(0.35, 0.6) * SR); t_ = np.arange(m) / SR
        steps = (np.sin(2 * np.pi * r.uniform(16, 22) * t_) > 0.6).astype(float)
        scurry = bp(noise(m), 1500, 6000) * steps * np.hanning(m)
        sq = int(0.07 * SR); ts = np.arange(sq) / SR
        f = r.uniform(2600, 3400)
        squeak = np.sin(2 * np.pi * (f + 900 * np.sin(np.pi * ts / ts[-1])) * ts) * np.hanning(sq)
        x = scurry * 0.6
        k0 = int(len(x) * r.uniform(0.3, 0.7))
        x[k0:k0 + sq] += squeak[:max(0, min(sq, len(x) - k0))] * 0.5
        return x
    for t in (4.5, 9.0, 14.0, 19.0, 22.5):  # rats qui détalent dans les feuilles
        put(rat(), t, r.uniform(-0.8, 0.8), 0.09)
    for t in (6.0, 18.0):                   # une branche craque
        m = int(0.25 * SR)
        put(bp(noise(m), 300, 2000) * np.exp(-np.arange(m) / SR * 18), t, r.uniform(-1, 1), 0.08)
    y = np.stack([loopify(out[:, 0], L, 0.8), loopify(out[:, 1], L, 0.8)], 1)
    return y / (np.abs(y).max() + 1e-9) * 0.45


@amb("fire")
def _fire():
    L = 4.0
    n = int((L + 0.3) * SR)
    r = rng(440)
    roar = lp(noise(n), 400) * (0.5 + 0.5 * gusts(n, 441, 2.0)) * 1.2
    pops = (r.random(n) < 25 / SR) * r.standard_normal(n) * 1.5
    pops = bp(pops, 1000, 7000) + bp(r.standard_normal(n) * (r.random(n) < 0.002), 3000, 8000)
    return normalize(loopify(roar + pops, L, 0.3), 0.6)


@amb("stone_hum")
def _hum():
    L = 2.0       # 220 Hz et 330,5 Hz : battement lent, entiers de périodes sur 2 s
    t = np.arange(int(L * SR)) / SR
    x = 0.5 * np.sin(2 * np.pi * 220 * t) + 0.35 * np.sin(2 * np.pi * 330.5 * t) + 0.15 * np.sin(2 * np.pi * 660 * t)
    return x * (0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t)) * 0.5


if __name__ == "__main__":
    only = sys.argv[2:]
    for name, (fn, peak) in SFX.items():
        if only and name not in only:
            continue
        x = fn()
        x = normalize(np.nan_to_num(x), peak)
        loop = name in ("axe_whirr", "glide_loop", "locust_buzz")
        write_ogg(f"{DEST}/sfx/{name}.ogg", x if loop else fade(x, 0.001, 0.01), quality=4)
    for name, fn in AMB.items():
        if only and name not in only:
            continue
        x = np.nan_to_num(fn())
        write_ogg(f"{DEST}/amb/{name}.ogg", x, quality=4 if x.ndim == 2 else 3)
    print(len(SFX), "bruitages,", len(AMB), "ambiances")
