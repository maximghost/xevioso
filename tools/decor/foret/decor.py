"""Décors posés de la forêt des irokos. Chaque décor existe en deux états :
  <nom>.png        : la forêt malade (feuillage gris, poussière d'Adaka) — au début du niveau ;
  <nom>_green.png  : la forêt guérie (le niveau échange les images à la victoire).
Décors : grand tronc d'iroko (pied et contreforts, le haut se perd hors de l'écran), fougère,
champignons, souche, tronc couché, buisson. Lumière : d'en haut à gauche.
"""
import math, random, sys
import numpy as np
from PIL import Image, ImageDraw

OUT = sys.argv[1]
BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
OUTLINE = (12, 9, 8)


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


BARK = [hexc(c) for c in ("130e0b", "1f1712", "2c211a", "3b2d23", "4c3a2d", "5f4a3a", "75604d")]
LEAF = {True: [hexc(c) for c in ("12261a", "1c3824", "28502f", "3a6c3c", "54884c", "76a662")],
        False: [hexc(c) for c in ("2a2926", "3a3834", "4d4a44", "625e56", "7a756b", "948e82")]}
MOSS = {True: [hexc(c) for c in ("1d3a1f", "2b5229", "3c6e33")], False: [hexc(c) for c in ("3a3733", "4a4640", "5a554d")]}
CAP = {True: [hexc(c) for c in ("5a2a16", "8a4420", "b8662e", "e0a060", "f0d8a8")],
       False: [hexc(c) for c in ("3c3832", "55504a", "6e685e", "8c8578", "a8a090")]}


class Sprite:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3), np.uint8)
        self.a = np.zeros((h, w), bool)
        self.yy, self.xx = np.mgrid[0:h, 0:w]

    def mask(self, fn):
        im = Image.new("L", (self.w, self.h), 0)
        fn(ImageDraw.Draw(im))
        return np.array(im) > 127

    def paint(self, m, val, pal):
        bay = BAY[self.yy % 4, self.xx % 4]
        idx = np.clip(np.floor(val * (len(pal) - 1) + bay), 0, len(pal) - 1).astype(int)
        for i, c in enumerate(pal):
            self.rgb[m & (idx == i)] = c
        self.a |= m

    def across(self, m):
        u = np.zeros(m.shape)
        for y in range(self.h):
            row = np.nonzero(m[y])[0]
            if len(row):
                for run in np.split(row, np.nonzero(np.diff(row) > 1)[0] + 1):
                    u[y, run] = (run - run[0]) / max(1, run[-1] - run[0])
        return u

    def outline(self):
        a = self.a
        o = np.zeros_like(a)
        o[1:] |= a[:-1]; o[:-1] |= a[1:]; o[:, 1:] |= a[:, :-1]; o[:, :-1] |= a[:, 1:]
        o &= ~a
        self.rgb[o] = OUTLINE
        self.a |= o

    def save(self, name):
        im = np.zeros((self.h, self.w, 4), np.uint8)
        im[..., :3] = self.rgb
        im[..., 3] = self.a * 255
        Image.fromarray(im, "RGBA").save(f"{OUT}/{name}.png")


def bark(s, m, phase=0.0, fan=None):
    u = s.across(m)
    fx, fy = fan if fan else (s.w / 2, -200)
    ang = np.arctan2(s.xx - fx, s.yy - fy)
    ridge = np.sin(ang * 90 + phase + 0.6 * np.sin(s.yy * 0.05))
    val = 0.12 + 0.55 * (1 - u) ** 1.3 + 0.13 * ridge + 0.15 * (u < 0.05)
    val[ridge < -0.8] = 0.0
    s.paint(m, val, BARK)


def tuft(s, x, y, r, pal, seed):
    """Touffe de feuillage ronde, dentelée, éclairée en haut à gauche."""
    rr = random.Random(seed)
    ang = np.arctan2(s.yy - y, s.xx - x)
    jag = 0.2 * np.sin(ang * rr.choice((5, 6, 7)) + rr.uniform(0, 6))
    d = np.hypot((s.xx - x) / r, (s.yy - y) / (r * 0.8))
    m = d < 1 + jag
    lit = -((s.xx - x) + (s.yy - y)) / (2 * r)
    val = 0.4 + 0.35 * lit
    val = np.where(d > 0.8 + jag, val - 0.25, val)
    s.paint(m, val, pal)


def dust(s, healthy, amount=0.06, seed=0):
    """La poussière d'Adaka : un voile de points gris sur la forêt malade."""
    if healthy:
        return
    rr = np.random.default_rng(seed)
    sel = s.a & (rr.random(s.a.shape) < amount)
    s.rgb[sel] = (120, 114, 104)


# ------------------------------------------------------------------------------------------
def iroko_tronc(healthy):
    """Le pied d'un iroko géant : tronc de 70 px, contreforts jusqu'à 180 px, 300 px de haut."""
    s = Sprite(200, 300)
    cx, base, top = 100, 299, 0
    def trunk_half(y):
        t = (y - top) / (base - top)
        return 30 + 4 * math.sin(t * 7) + 58 * t ** 9
    for side in (-1, 1):                     # contreforts
        for k, (spread, h) in enumerate(((66, 90), (44, 120), (22, 70))):
            def fin(d, side=side, spread=spread, h=h):
                pts = [(cx + side * (trunk_half(base - h + h * j / 8) - 4), base - h + h * j / 8) for j in range(9)]
                for j in range(12, -1, -1):
                    t = j / 12
                    y = base - h * (1 - t) ** 0.7
                    pts.append((cx + side * (trunk_half(y) - 4 + spread * t ** 2.2), y))
                d.polygon(pts, fill=255)
            m = s.mask(fin)
            bark(s, m, phase=k * 1.3 + side, fan=(cx, -120))
            if side > 0:
                s.rgb[m] = (s.rgb[m] * 0.75).astype(np.uint8)       # côté à l'ombre
    m = s.mask(lambda d: d.polygon([(cx - trunk_half(y), y) for y in range(top, base + 1, 10)] +
                                   [(cx + trunk_half(y), y) for y in range(base, top - 1, -10)], fill=255))
    bark(s, m, fan=(cx, -120))
    rr = random.Random(5)
    for i in range(140):                     # mousse (ou cendre) au pied et côté ombre
        x = cx + rr.uniform(-90, 90); y = base - rr.uniform(0, 70) ** 1.1
        if 0 <= int(y) < s.h and s.a[int(y), int(x)]:
            s.rgb[int(y), int(x)] = MOSS[healthy][rr.randrange(3)]
    for k in range(3):                        # lianes qui descendent le long du tronc
        x0 = cx + rr.uniform(-24, 24)
        m = s.mask(lambda d, x0=x0, k=k: d.line([(x0 + 3 * math.sin(y * 0.04 + k), y) for y in range(0, 200 + k * 30, 3)], fill=255, width=2))
        s.paint(m, np.full(m.shape, 0.5), MOSS[healthy])
    s.outline()
    dust(s, healthy, 0.015, 1)
    return s


def fougere(healthy):
    """Fougère : sept palmes qui jaillissent du pied et retombent en arc, folioles de chaque côté."""
    s = Sprite(48, 30)
    rr = random.Random(3)
    pal = LEAF[healthy]
    for k in range(7):
        a0 = math.radians(48 + k * 14 + rr.uniform(-5, 5))
        L = rr.uniform(26, 31) * (1.0 - 0.2 * abs(k - 3) / 3)
        side = -1 if a0 > math.pi / 2 else 1           # elle retombe vers l'extérieur
        pts = []
        for j in range(14):
            t = j / 13
            a = a0 - side * t * 0.9
            x = 24 + math.cos(a0) * L * t + side * t * t * 6
            y = 29 - math.sin(a0) * L * t + t ** 3 * L * 0.3
            pts.append((x, y))
        m = s.mask(lambda d, pts=pts: d.line(pts, fill=255, width=1))
        s.paint(m, np.full(m.shape, 0.25), pal)
        for j in range(2, 14):
            px, py = pts[j]
            lf = (1 - j / 14) * 4.5 + 1.5
            for sd in (-1, 1):
                m = s.mask(lambda d, px=px, py=py, lf=lf, sd=sd: d.line([(px, py), (px + sd * lf * 0.6, py + lf * 0.5)], fill=255, width=1))
                s.paint(m, np.full(m.shape, 0.4 + 0.35 * (sd < 0) + 0.2 * (py < 14)), pal)
    s.outline()
    return s


def champignons(healthy):
    s = Sprite(26, 16)
    for x, h, r in ((7, 9, 5), (15, 12, 6), (21, 6, 3.5)):
        m = s.mask(lambda d, x=x, h=h: d.rectangle((x - 1, 15 - h, x + 1, 15), fill=255))
        s.paint(m, np.full(m.shape, 0.7), [hexc("b8ac94"), hexc("d8ccb0")] if healthy else [hexc("7a756b"), hexc("948e82")])
        m = s.mask(lambda d, x=x, h=h, r=r: d.pieslice((x - r, 15 - h - r * 0.8, x + r, 15 - h + r * 0.8), 180, 360, fill=255))
        s.paint(m, 0.35 + 0.5 * np.clip(-(s.xx - x) / (2 * r) - (s.yy - (15 - h)) / r, -1, 1), CAP[healthy])
    s.outline()
    return s


def souche(healthy):
    s = Sprite(36, 26)
    m = s.mask(lambda d: d.polygon([(6, 25), (9, 8), (12, 4), (24, 4), (27, 8), (30, 25)], fill=255))
    bark(s, m, fan=(18, -60))
    m = s.mask(lambda d: d.ellipse((10, 2, 26, 8), fill=255))
    s.paint(m, 0.5 + 0.3 * np.sin(np.hypot(s.xx - 18, (s.yy - 5) * 2.5) * 1.2), [hexc("4a3626"), hexc("6e523a"), hexc("8a6c4e")])
    for x, y in ((3, 25), (33, 25)):        # racines
        m = s.mask(lambda d, x=x, y=y: d.polygon([(18, 20), (x, y), (18, 25)], fill=255))
        bark(s, m)
    for i in range(14):
        rr = random.Random(i)
        x, y = rr.randrange(8, 28), rr.randrange(14, 25)
        if s.a[y, x]:
            s.rgb[y, x] = MOSS[healthy][rr.randrange(3)]
    s.outline()
    dust(s, healthy, 0.05, 2)
    return s


def tronc_couche(healthy):
    s = Sprite(80, 22)
    m = s.mask(lambda d: d.rounded_rectangle((2, 4, 74, 21), radius=8, fill=255))
    v = 1 - np.abs(s.yy - 9) / 12
    ridge = np.sin(s.yy * 1.6 + np.sin(s.xx * 0.08) * 2)
    val = 0.15 + 0.55 * v + 0.12 * ridge
    val[ridge < -0.85] = 0.0
    s.paint(m, val, BARK)
    m = s.mask(lambda d: d.ellipse((68, 4, 78, 21), fill=255))          # la coupe, aux cernes
    s.paint(m, 0.45 + 0.3 * np.sin(np.hypot((s.xx - 73) * 1.7, s.yy - 12.5) * 1.3), [hexc("4a3626"), hexc("6e523a"), hexc("8a6c4e")])
    rr = random.Random(8)
    for i in range(50):                    # mousse sur le dessus
        x, y = rr.randrange(4, 68), rr.randrange(4, 9)
        if s.a[y, x]:
            s.rgb[y, x] = MOSS[healthy][rr.randrange(3)]
    s.outline()
    dust(s, healthy, 0.05, 3)
    return s


def buisson(healthy):
    s = Sprite(44, 26)
    rr = random.Random(4)
    for i in range(16):
        x = rr.uniform(8, 36); y = rr.uniform(9, 22); r = rr.uniform(5, 8)
        tuft(s, x, y, r, LEAF[healthy], i)
    s.a[25:] = s.a[25:]
    s.outline()
    dust(s, healthy, 0.03, 4)
    return s


for name, fn in (("iroko_tronc", iroko_tronc), ("fougere", fougere), ("champignons", champignons),
                 ("souche", souche), ("tronc_couche", tronc_couche), ("buisson_foret", buisson)):
    fn(False).save(name)
    fn(True).save(name + "_green")

# Aperçu côte à côte
names = ["iroko_tronc", "fougere", "champignons", "souche", "tronc_couche", "buisson_foret"]
prev = Image.new("RGBA", (560, 620), (40, 58, 52, 255))
for row, suffix in enumerate(("", "_green")):
    x = 4
    for n in names:
        im = Image.open(f"{OUT}/{n}{suffix}.png")
        prev.alpha_composite(im, (x, 305 * row + 300 - im.height))
        x += im.width + 6
prev.resize((1120, 1240), Image.NEAREST).save(f"{OUT}/decor_prev.png")
