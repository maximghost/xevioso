"""Musiques de Xɛvioso, sur des rythmes du sud du Bénin (compositions originales, calculées).

Repères rythmiques (mesure à 12 pulsations, 12/8) :
  * la cloche gankogui joue la « ligne du temps » à 7 frappes : x . x . x x . x . x . x
    (frappe grave sur le 1) — c'est elle qui tient tout l'orchestre ;
  * le hochet axatsɛ double chaque pulsation, accentué avec la cloche ;
  * kaganu (petit tambour aigu) sur les contretemps, kidi et sogo (tambours moyens) en
    dialogue ouvert/étouffé, atsimevu (tambour maître) lance des appels ;
  * agbadja (Fon/Ewe) pour l'élan du village ; zinli (Abomey, jarre frappée, lent et grave)
    pour le deuil des malheurs ; tchinkoumé (tambour d'eau) pour la saison des pluies.
Mélodies pentatoniques : l'agidigbo (lamellophone) et les voix en appel/réponse.

Chaque morceau est une boucle sans couture (la réverbération et les notes qui débordent
de la fin retombent au début).
"""
import sys
import numpy as np
from synth import *

DEST = sys.argv[1] if len(sys.argv) > 1 else "out"
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note_num(s):
    """« A4 », « C#5 », « Bb3 » -> numéro MIDI."""
    n = NOTE[s[0]]
    i = 1
    if s[i] in "#b":
        n += 1 if s[i] == "#" else -1
        i += 1
    return n + 12 * (int(s[i:]) + 1)


def seq(text):
    """« A4:2 -:1 C5:3 | ... » -> [(pulsation, note MIDI ou None, durée)]."""
    out, t = [], 0
    for tok in text.replace("|", " ").split():
        n, d = tok.split(":")
        d = float(d)
        out.append((t, None if n == "-" else note_num(n), d))
        t += d
    return out


class Track:
    def __init__(self, bpm, bars, tail=4.0, swing=0.0, seed=1):
        self.p = 60.0 / (bpm * 3)            # durée d'une pulsation (croche de 12/8)
        self.bars = bars
        self.L = int(round(bars * 12 * self.p * SR))
        self.buf = np.zeros((self.L + int(tail * SR), 2))
        self.send = np.zeros_like(self.buf)  # envoi vers la réverbération
        self.rng = np.random.default_rng(seed)
        self.cache = {}

    def at(self, bar, pulse):
        return (bar * 12 + pulse) * self.p

    def add(self, x, t, gain=1.0, pan=0.0, rev=0.15, jitter=0.004):
        t = max(0.0, t + self.rng.normal(0, jitter))
        i = int(t * SR)
        n = min(len(x), len(self.buf) - i)
        if n <= 0:
            return
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        seg_ = x[:n] * gain
        self.buf[i:i + n, 0] += seg_ * l
        self.buf[i:i + n, 1] += seg_ * r
        self.send[i:i + n, 0] += seg_ * l * rev
        self.send[i:i + n, 1] += seg_ * r * rev

    def inst(self, key, fn):
        """Rendu mis en cache (quelques variantes par clé pour garder de la vie)."""
        k = key + (int(self.rng.integers(0, 3)),)
        if k not in self.cache:
            self.cache[k] = fn()
        return self.cache[k]

    def render(self, room=1.6, damp=5000, wet=0.35, master=0.85):
        wetbuf = np.zeros_like(self.buf)
        for c in range(2):
            y = reverb(self.send[:, c], room, damp, 1.0, pre=0.015 + 0.004 * c)
            y = y[:len(self.buf)] - self.send[:, c] * 0.5   # la fonction mélange le sec ; on ne garde que l'effet
            wetbuf[:, c] = y
        mixb = self.buf + wetbuf * wet
        # boucle : ce qui dépasse la fin retombe au début
        out = mixb[:self.L].copy()
        tail = mixb[self.L:]
        out[:len(tail)] += tail[:self.L]
        # bus maître : léger compresseur doux, puis normalisation
        out = soft_clip(out / (np.abs(out).max() + 1e-9) * 1.3, 1.2)
        return out * master


# ---------------------------------------------------------------------------
# Motifs rythmiques (pulsations sur 12)
# ---------------------------------------------------------------------------
BELL_HI = [2, 4, 5, 7, 9, 11]
BELL_LO = [0]


def groove_agbadja(tr, bar, level=3, bells=True, f_bell=1180.0):
    """Une mesure d'agbadja. level : 1 = cloche + hochet, 2 = + kaganu et sogo, 3 = tout."""
    p = tr.p
    b0 = tr.at(bar, 0)
    if bells:
        for s in BELL_HI:
            tr.add(tr.inst(("bell", f_bell), lambda: bell(f_bell, 0.5, 1.0)), b0 + s * p, 0.32, 0.35, 0.12)
        for s in BELL_LO:
            tr.add(tr.inst(("bell", f_bell * 0.78), lambda: bell(f_bell * 0.78, 0.6, 1.0)), b0 + s * p, 0.38, 0.35, 0.12)
    for s in range(12):
        v = 0.55 if s in BELL_HI + BELL_LO else 0.3
        tr.add(tr.inst(("shk",), lambda: shaker(0.09, 1.0)), b0 + s * p, v * 0.5, -0.45, 0.08)
    if level >= 2:
        for s in (2, 5, 8, 11):
            tr.add(tr.inst(("kag",), lambda: drum(420, "slap", 0.15, 1.0)), b0 + s * p, 0.28, 0.55, 0.1)
        for s, k in ((0, "bass"), (3, "open"), (5, "mute"), (6, "bass"), (9, "open"), (10, "mute")):
            tr.add(tr.inst(("sogo", k), lambda k=k: drum(150, k, 0.6, 1.0)), b0 + s * p, 0.32 if k == "bass" else 0.42, -0.15, 0.12)
    if level >= 3:
        for s, k in ((2, "open"), (4, "open"), (6, "mute"), (7, "mute"), (8, "mute"), (10, "open")):
            tr.add(tr.inst(("kidi", k), lambda k=k: drum(235, k, 0.4, 1.0)), b0 + s * p, 0.4, 0.2, 0.12)
        tr.add(tr.inst(("sato",), lambda: drum(72, "bass", 0.9, 1.0)), b0, 0.38, 0.0, 0.1)


def lead_call(tr, bar, kind=0, f=120.0):
    """Appel du tambour maître (atsimevu) : roulements et notes « parlantes » glissées."""
    b0 = tr.at(bar, 0)
    pats = [[(0, "open", 0), (1, "open", 0), (2, "slap", 0), (6, "open", 4), (8, "open", -3), (9, "slap", 0)],
            [(0, "slap", 0), (2, "open", 3), (3, "open", 3), (4, "open", 0), (7, "slap", 0), (8, "slap", 0), (10, "open", -4)],
            [(0, "open", 5), (3, "open", 0), (4, "mute", 0), (5, "mute", 0), (6, "open", 5), (9, "open", 0), (11, "slap", 0)]]
    for s, k, bend in pats[kind % 3]:
        tr.add(drum(f, k, 0.6, 1.0, bend=bend, body=1.3), b0 + s * tr.p, 0.42, -0.3, 0.2)


def play_melody(tr, start_bar, text, inst="agi", oct_shift=0, gain=0.5, pan=0.0, rev=0.3, vowel="a"):
    for t, n, d in seq(text):
        if n is None:
            continue
        f = midi(n + 12 * oct_shift)
        dur = d * tr.p
        when = tr.at(start_bar, 0) + t * tr.p
        if inst == "agi":
            x = tr.inst(("agi", n + 12 * oct_shift, round(dur, 2)), lambda: agidigbo(f, max(0.6, dur * 1.6), 1.0))
            tr.add(x, when, gain, pan, rev)
        elif inst == "voice":
            x = voice(f, dur * 0.98 + 0.08, vowel, 1.0, attack=0.04)
            tr.add(x, when, gain, pan, rev, jitter=0.002)
        elif inst == "choir":
            x = choir([f, f * 0.5 if n > 62 else f * 2 ** (7 / 12)], dur * 0.98 + 0.1, vowel, 1.0)
            tr.add(x, when, gain, pan, rev, jitter=0.002)


def pad(tr, bar, bars, notes, vowel="o", gain=0.25, pan=0.0):
    dur = bars * 12 * tr.p + 0.6
    x = choir([midi(note_num(n)) for n in notes], dur, vowel, 1.0)
    x = fade(x, 0.4, 0.6)
    tr.add(x, tr.at(bar, 0), gain, pan, 0.4, jitter=0)


# ---------------------------------------------------------------------------
# Morceaux
# ---------------------------------------------------------------------------
def village():
    """Niveau du village (sécheresse) : agbadja entraînant, appel/réponse en ré mineur penta."""
    tr = Track(bpm=104, bars=32, seed=2)
    RIFF = ["D3:2 A2:1 D3:2 F3:1 G3:2 F3:1 D3:2 C3:1", "A2:2 C3:1 D3:2 F3:1 D3:2 C3:1 A2:2 G2:1"]
    CALL = ["A4:2 A4:1 C5:3 A4:2 G4:1 F4:3 | D4:3 F4:2 G4:1 A4:6",
            "F4:2 G4:1 A4:3 C5:2 D5:1 C5:3 | A4:3 G4:3 F4:2 G4:1 A4:3"]
    RESP = ["D5:2 C5:1 A4:3 G4:2 A4:1 C5:3 | A4:3 G4:2 F4:1 D4:6",
            "D5:2 D5:1 C5:3 A4:2 G4:1 A4:3 | G4:3 F4:2 D4:1 D4:6"]
    LEAD = "D5:1 C5:1 A4:1 G4:2 A4:1 C5:2 A4:1 G4:1 F4:2 | G4:1 A4:1 G4:1 F4:2 D4:1 F4:3 G4:3"
    for bar in range(32):
        lvl = 1 if bar < 2 else (2 if bar < 4 else 3)
        if 20 <= bar < 24:
            lvl = 1
        groove_agbadja(tr, bar, lvl)
        if bar >= 2 and not (20 <= bar < 22):
            play_melody(tr, bar, RIFF[(bar // 4) % 2], "agi", 0, 0.55, -0.1, 0.2)
        if 20 <= bar < 24:   # pause : tambour d'eau
            for s in (0, 6, 8):
                tr.add(tr.inst(("wd",), lambda: water_drum(88, 0.7)), tr.at(bar, s), 0.6, 0.1, 0.2)
        if bar in (7, 11, 15, 19, 27, 31):
            lead_call(tr, bar, bar)
    for k, bar in enumerate((4, 8, 24, 28)):
        play_melody(tr, bar, CALL[k % 2], "voice", 0, 0.42, 0.15, 0.35, "a")
        play_melody(tr, bar + 2, RESP[k % 2], "choir", 0, 0.32, -0.1, 0.4, "a")
    for bar in (12, 14, 16, 18):
        play_melody(tr, bar, LEAD, "agi", 1, 0.4, 0.25, 0.3)
    return tr.render()


def fete():
    """La fête de la pluie (sol majeur penta) : agbadja joyeux, voix, tambour d'eau."""
    tr = Track(bpm=114, bars=24, seed=3)
    RIFF = "G2:2 D3:1 G3:2 A3:1 B3:2 A3:1 G3:2 D3:1"
    CALL = ["B4:2 D5:1 E5:3 D5:2 B4:1 A4:3 | G4:3 A4:2 B4:1 D5:6",
            "D5:2 E5:1 G5:3 E5:2 D5:1 B4:3 | A4:3 B4:2 A4:1 G4:6"]
    RESP = ["E5:2 D5:1 B4:3 A4:2 B4:1 D5:3 | B4:3 A4:2 G4:1 G4:6",
            "G5:2 E5:1 D5:3 B4:2 D5:1 E5:3 | D5:3 B4:2 A4:1 G4:6"]
    ARP = "G5:1 D5:1 B4:1 D5:1 G5:1 A5:1 G5:1 E5:1 D5:1 B4:1 D5:1 E5:1"
    for bar in range(24):
        groove_agbadja(tr, bar, 1 if bar < 1 else 3, f_bell=1250.0)
        play_melody(tr, bar, RIFF, "agi", 0, 0.55, -0.1, 0.2)
        for s in (0, 7):
            tr.add(tr.inst(("wd",), lambda: water_drum(96, 0.6)), tr.at(bar, s), 0.45, 0.25, 0.2)
        if bar % 4 == 3:
            lead_call(tr, bar, bar // 4, 135.0)
    for k, bar in enumerate((2, 6, 14, 18)):
        play_melody(tr, bar, CALL[k % 2], "voice", 0, 0.42, 0.15, 0.35, "a")
        play_melody(tr, bar + 2, RESP[k % 2], "choir", 0, 0.32, -0.15, 0.4, "a")
    for bar in (10, 11, 12, 13, 22, 23):
        play_melody(tr, bar, ARP, "agi", 0, 0.28, 0.4, 0.3)
    return tr.render()


def titre():
    """Écran titre : mystérieux et ample (ré mineur), sato profond, chœur, agidigbo, orage lointain."""
    tr = Track(bpm=80, bars=16, seed=4, tail=6.0)
    CH = [["D3", "A3", "F4"], ["C3", "G3", "E4"], ["A2", "E3", "C4"], ["D3", "A3", "F4"]]
    for i, bar in enumerate(range(0, 16, 4)):
        pad(tr, bar, 4, CH[i], "o", 0.28)
    for bar in range(16):
        b0 = tr.at(bar, 0)
        tr.add(tr.inst(("sato",), lambda: drum(62, "bass", 1.2, 1.0)), b0, 0.55, 0.0, 0.25)
        tr.add(tr.inst(("satoo",), lambda: drum(62, "open", 0.8, 1.0)), tr.at(bar, 6), 0.45, 0.0, 0.25)
        tr.add(tr.inst(("satom",), lambda: drum(62, "mute", 0.3, 1.0)), tr.at(bar, 9), 0.4, 0.0, 0.2)
        if bar >= 4:
            for s in (0, 7):
                tr.add(tr.inst(("bell2",), lambda: bell(1050, 0.9, 1.0, 0.8)), tr.at(bar, s), 0.22, 0.4, 0.35)
            for s in range(0, 12, 2):
                tr.add(tr.inst(("shk",), lambda: shaker(0.1, 1.0, 0.8)), tr.at(bar, s), 0.12, -0.4, 0.2)
    MEL = "D4:3 F4:2 A4:1 G4:6 | F4:3 D4:3 C4:6 | D4:3 F4:2 G4:1 A4:3 C5:3 | A4:12"
    MEL2 = "A4:3 C5:2 D5:1 C5:6 | A4:3 G4:3 F4:6 | G4:3 A4:2 G4:1 F4:3 D4:3 | D4:12"
    play_melody(tr, 4, MEL, "agi", 0, 0.5, 0.1, 0.45)
    play_melody(tr, 8, MEL2, "agi", 0, 0.5, 0.1, 0.45)
    play_melody(tr, 12, MEL, "voice", -1, 0.35, -0.15, 0.5, "o")
    tr.add(thunder(5.0, 0.35, 0.0, seed=501), tr.at(0, 2), 0.6, -0.3, 0.2, 0)
    tr.add(thunder(5.0, 0.3, 0.0, seed=502), tr.at(8, 4), 0.5, 0.4, 0.2, 0)
    return tr.render(room=2.2, wet=0.45)


def intro_village():
    """Matin au village (sol majeur penta) : agidigbo, tambour d'eau, hochet, cloche douce."""
    tr = Track(bpm=92, bars=16, seed=5)
    MEL = ["G4:3 B4:3 D5:3 B4:3 | A4:3 G4:3 E4:6 | G4:2 A4:1 B4:3 D5:2 E5:1 D5:3 | B4:3 A4:3 G4:6",
           "D5:3 E5:3 D5:2 B4:1 A4:3 | B4:3 G4:3 A4:6 | G4:2 B4:1 D5:3 E5:2 G5:1 E5:3 | D5:3 B4:3 G4:6"]
    BASS = ["G2:6 D3:6", "E2:6 B2:6", "G2:6 D3:6", "D2:6 A2:6"]
    for bar in range(16):
        b0 = tr.at(bar, 0)
        for s in (0, 6, 9):
            tr.add(tr.inst(("wd",), lambda: water_drum(92, 0.7)), tr.at(bar, s), 0.5 if s != 9 else 0.3, 0.1, 0.2)
        for s in range(12):
            tr.add(tr.inst(("shk",), lambda: shaker(0.08, 1.0, 0.9)), b0 + s * tr.p, 0.18 if s % 3 == 0 else 0.09, -0.4, 0.1)
        for s in (0, 5, 7):
            tr.add(tr.inst(("bell3",), lambda: bell(1350, 0.5, 1.0, 0.6)), tr.at(bar, s), 0.13, 0.45, 0.2)
        play_melody(tr, bar, BASS[bar % 4], "agi", 0, 0.45, -0.15, 0.2)
    play_melody(tr, 0, MEL[0], "agi", 0, 0.5, 0.15, 0.3)
    play_melody(tr, 4, MEL[1], "agi", 0, 0.5, 0.15, 0.3)
    play_melody(tr, 8, MEL[0], "agi", 1, 0.32, 0.25, 0.35)
    play_melody(tr, 8, MEL[0], "voice", 0, 0.25, -0.1, 0.4, "o")
    play_melody(tr, 12, MEL[1], "agi", 0, 0.5, 0.15, 0.3)
    return tr.render()


def intro_drame():
    """La nuit du vol : battement de cœur grave, bourdon dissonant, chœur sombre, cloche lointaine."""
    tr = Track(bpm=50, bars=10, seed=6, tail=6.0)     # ~24 s
    L = tr.L / SR
    n = int((L + 6) * SR)
    t = np.arange(n) / SR
    drone = sum(osc(const(f, L + 6), "saw") for f in (55.0, 58.27, 82.4)) / 3
    drone = lp(drone, 260) * (0.7 + 0.3 * np.sin(2 * np.pi * t / L))
    tr.add(drone, 0, 0.35, 0, 0.3, 0)
    for bar in range(10):
        for s, g in ((0, 0.8), (2, 0.55)):            # lub-dub
            tr.add(tr.inst(("hb",), lambda: drum(52, "bass", 0.8, 1.0)), tr.at(bar, s), g, 0, 0.2)
        if bar % 2 == 0:
            tr.add(tr.inst(("dust",), lambda: shaker(0.6, 0.6, 0.5)), tr.at(bar, 7), 0.2, 0.5, 0.4)
    for bar, notes in ((1, ["A3", "Bb3", "E4"]), (6, ["G3", "Ab3", "D4"])):
        pad(tr, bar, 3, notes, "u", 0.32)
    for bar in (3, 8):
        tr.add(bell(523, 3.0, 1.0, 0.5), tr.at(bar, 4), 0.18, -0.5, 0.6, 0)
    return tr.render(room=2.6, damp=3000, wet=0.5)


def intro_malheurs():
    """Les malheurs : rythme lent de zinli (jarre frappée), cloche grave, voix de deuil (la mineur)."""
    tr = Track(bpm=64, bars=16, seed=7, tail=6.0)
    for bar in range(16):
        for s, k, g in ((0, 1.0, 0.8), (3, 0.4, 0.4), (6, 1.0, 0.65), (8, 0.4, 0.4), (10, 0.7, 0.5)):
            tr.add(tr.inst(("zinli", k), lambda k=k: pot_drum(96 if k > 0.5 else 140, 0.8, 1.0, k)), tr.at(bar, s), g * 0.55, -0.1, 0.25)
        tr.add(tr.inst(("gkl",), lambda: bell(620, 1.2, 1.0, 0.6)), tr.at(bar, 0), 0.2, 0.35, 0.3)
        tr.add(tr.inst(("gkh",), lambda: bell(830, 0.8, 1.0, 0.6)), tr.at(bar, 6), 0.14, 0.35, 0.3)
        play_melody(tr, bar, "A2:6 E2:6", "agi", 0, 0.22, 0.0, 0.3)
    MEL = ["A3:6 C4:3 B3:3 | A3:9 -:3 | E4:6 D4:3 C4:3 | A3:12",
           "C4:6 D4:3 E4:3 | D4:6 C4:6 | B3:6 A3:3 G3:3 | A3:12"]
    play_melody(tr, 4, MEL[0], "voice", 0, 0.7, 0.1, 0.45, "o")
    play_melody(tr, 8, MEL[1], "voice", 0, 0.7, 0.1, 0.45, "o")
    play_melody(tr, 12, MEL[0], "choir", 0, 0.5, -0.1, 0.5, "o")
    play_melody(tr, 12, MEL[0], "agi", 0, 0.35, 0.2, 0.4)
    pad(tr, 0, 4, ["A2", "E3"], "m", 0.2)
    return tr.render(room=2.0, damp=3500, wet=0.45)


def intro_appel():
    """L'appel de Xɛvioso : solennel (ré mineur), sato et tambour parlant, cloche, chœur ample."""
    tr = Track(bpm=70, bars=16, seed=8, tail=6.0)
    CH = [["D3", "A3", "F4"], ["Bb2", "F3", "D4"], ["C3", "G3", "E4"], ["D3", "A3", "D4", "F4"]]
    for i, bar in enumerate(range(0, 16, 4)):
        pad(tr, bar, 4, CH[i], "a", 0.3)
    for bar in range(16):
        tr.add(tr.inst(("sato",), lambda: drum(58, "bass", 1.2, 1.0)), tr.at(bar, 0), 0.55, 0.0, 0.3)
        tr.add(tr.inst(("satoo",), lambda: drum(58, "open", 0.9, 1.0)), tr.at(bar, 6), 0.55, 0.0, 0.3)
        tr.add(tr.inst(("bl",), lambda: bell(700, 1.4, 1.0, 0.7)), tr.at(bar, 0), 0.22, 0.4, 0.35)
        if bar >= 4:
            tr.add(tr.inst(("bh",), lambda: bell(930, 1.0, 1.0, 0.7)), tr.at(bar, 7), 0.16, 0.4, 0.35)
        if bar % 2 == 1:
            lead_call(tr, bar, bar // 2, 110.0)
    MEL = "D4:6 F4:3 G4:3 | A4:9 G4:3 | F4:6 D4:3 C4:3 | D4:12"
    play_melody(tr, 8, MEL, "agi", 0, 0.45, 0.15, 0.45)
    play_melody(tr, 12, MEL, "choir", 0, 0.32, -0.1, 0.5, "a")
    return tr.render(room=2.6, wet=0.5)


def victoire():
    """Jingle de victoire : roulement, puis accord du chœur, cloches en cascade, tambour d'eau."""
    p = 60.0 / (110 * 3)
    out = np.zeros((int(7 * SR), 2))
    def put(x, t, g=1.0, pan=0.0):
        i = int(t * SR); n = min(len(x), len(out) - i)
        out[i:i + n, 0] += x[:n] * g * np.cos((pan + 1) * np.pi / 4)
        out[i:i + n, 1] += x[:n] * g * np.sin((pan + 1) * np.pi / 4)
    for k in range(10):
        put(drum(150, "open", 0.4, 0.4 + 0.06 * k), k * p * 0.5, 0.6)
    T = 10 * p * 0.5
    put(drum(70, "bass", 1.2, 1.0), T, 0.9)
    put(choir([midi(55), midi(62), midi(67), midi(71)], 3.5, "a", 1.0), T, 0.45)
    for i, m in enumerate([79, 83, 86, 91, 95]):
        put(bell(midi(m), 1.5, 1.0, 1.2), T + i * p, 0.2, 0.4 - 0.2 * i)
    for i, m in enumerate([55, 59, 62, 67, 71, 74]):
        put(agidigbo(midi(m), 1.5, 1.0), T + 0.1 + i * p * 0.66, 0.4, -0.2)
    put(water_drum(90, 0.8), T + 6 * p, 0.6, 0.2)
    put(water_drum(90, 0.8), T + 9 * p, 0.6, 0.2)
    wet = np.stack([reverb(out[:, c], 1.8, 5000, 1.0)[:len(out)] for c in range(2)], axis=1)
    y = out + (wet - out * 0.5) * 0.35
    y = soft_clip(y / np.abs(y).max() * 1.2, 1.2) * 0.85
    y[-int(1.0 * SR):] *= np.linspace(1, 0, int(1.0 * SR))[:, None]
    return y


def game_over():
    """Jingle de fin de partie : trois coups de jarre qui descendent, chœur qui retombe."""
    out = np.zeros((int(6 * SR), 2))
    def put(x, t, g=1.0, pan=0.0):
        i = int(t * SR); n = min(len(x), len(out) - i)
        out[i:i + n, 0] += x[:n] * g * np.cos((pan + 1) * np.pi / 4)
        out[i:i + n, 1] += x[:n] * g * np.sin((pan + 1) * np.pi / 4)
    for k, f in enumerate((147, 123, 98)):
        put(pot_drum(f, 1.0, 1.0), k * 0.55, 0.5)
    put(choir([midi(62), midi(65), midi(69)], 1.2, "o", 1.0), 0.0, 0.35)
    put(choir([midi(57), midi(60), midi(64)], 1.2, "o", 1.0), 0.55, 0.35)
    put(choir([midi(50), midi(57), midi(62)], 3.0, "o", 1.0), 1.1, 0.4)
    put(bell(523, 3.0, 1.0, 0.5), 1.1, 0.2, 0.4)
    wet = np.stack([reverb(out[:, c], 2.2, 3500, 1.0)[:len(out)] for c in range(2)], axis=1)
    y = out + (wet - out * 0.5) * 0.45
    y = soft_clip(y / np.abs(y).max() * 1.2, 1.2) * 0.85
    y[-int(1.2 * SR):] *= np.linspace(1, 0, int(1.2 * SR))[:, None]
    return y


def foret():
    """La forêt des irokos (mi mineur) : mystérieuse et sacrée. Tambour d'eau grave et lent,
    agidigbo en ostinato qui tourne comme la brume, hochet très doux, cloche lointaine ; un
    bourdon de chœur fermé ; le tambour parlant lance de rares appels au loin (on ne sait pas
    encore qui joue). La seconde moitié s'épaissit : sogo étouffé, voix qui répond."""
    tr = Track(bpm=84, bars=24, seed=12, tail=6.0)
    OST = ["E3:2 B3:1 D4:2 B3:1 E4:2 D4:1 B3:2 A3:1", "E3:2 B3:1 D4:2 B3:1 G4:2 E4:1 D4:2 B3:1"]
    BASS = ["E2:12", "E2:12", "C2:12", "D2:12"]
    MEL = ["B4:6 D5:3 E5:3 | D5:6 B4:6 | A4:3 B4:3 G4:3 E4:3 | E4:12",
           "E5:6 G5:3 E5:3 | D5:6 B4:3 A4:3 | B4:6 A4:3 G4:3 | E4:12"]
    for bar in range(24):
        b0 = tr.at(bar, 0)
        for s, g in ((0, 0.55), (7, 0.3), (9, 0.35)):
            tr.add(tr.inst(("wd",), lambda: water_drum(80, 0.8)), tr.at(bar, s), g, 0.0, 0.3)
        for s in range(0, 12, 2):
            tr.add(tr.inst(("shk",), lambda: shaker(0.1, 1.0, 0.8)), b0 + s * tr.p, 0.07 if s % 6 else 0.12, -0.5, 0.2)
        if bar % 2 == 0:
            tr.add(tr.inst(("bellf",), lambda: bell(990, 1.4, 1.0, 0.5)), tr.at(bar, 0), 0.1, 0.55, 0.5)
        play_melody(tr, bar, OST[(bar // 2) % 2], "agi", 0, 0.32, 0.2, 0.35)
        play_melody(tr, bar, BASS[(bar // 2) % 4], "agi", -1, 0.3, -0.1, 0.3)
        if bar >= 12:
            for s, k in ((0, "bass"), (5, "mute"), (6, "bass"), (11, "mute")):
                tr.add(tr.inst(("sogo", k), lambda k=k: drum(140, k, 0.6, 1.0)), tr.at(bar, s), 0.22, -0.2, 0.2)
    for bar, kind in ((5, 0), (11, 1), (17, 2), (21, 0)):   # le tambour parlant, au loin
        b0 = tr.at(bar, 0)
        for s, k, bend in ((0, "open", 4), (1, "open", 0), (3, "open", -3), (6, "slap", 0), (8, "open", 5)):
            tr.add(drum(118, k, 0.6, 1.0, bend=bend, body=1.3), b0 + s * tr.p, 0.22, -0.55, 0.55)
    for bar in range(0, 24, 4):
        pad(tr, bar, 4, ["E3", "B3"] if bar % 8 == 0 else ["C3", "G3"], "u", 0.16)
    play_melody(tr, 8, MEL[0], "agi", 1, 0.26, 0.3, 0.45)
    play_melody(tr, 12, MEL[1], "voice", 0, 0.28, -0.15, 0.5, "o")
    play_melody(tr, 16, MEL[0], "voice", 0, 0.24, -0.15, 0.5, "o")
    play_melody(tr, 16, MEL[0], "agi", 1, 0.2, 0.3, 0.45)
    play_melody(tr, 20, MEL[1], "agi", 1, 0.26, 0.3, 0.45)
    return tr.render(room=2.4, damp=3800, wet=0.45)


TRACKS = {"village": village, "fete": fete, "titre": titre, "intro_village": intro_village,
          "intro_drame": intro_drame, "intro_malheurs": intro_malheurs, "intro_appel": intro_appel,
          "victoire": victoire, "game_over": game_over, "foret": foret}

if __name__ == "__main__":
    only = sys.argv[2:]
    for name, fn in TRACKS.items():
        if only and name not in only:
            continue
        y = np.nan_to_num(fn())
        # même intensité perçue pour tous les morceaux (jingles un peu plus présents)
        import pyloudnorm as pyln
        target = -15.0 if name in ("victoire", "game_over") else -16.0
        lufs = pyln.Meter(SR).integrated_loudness(y)
        y = y * 10 ** ((target - lufs) / 20)
        y = 0.95 * np.tanh(y / 0.95) if np.abs(y).max() > 0.95 else y
        write_ogg(f"{DEST}/music/{name}.ogg", y, quality=2)
        print(name, round(len(y) / SR, 1), "s")
