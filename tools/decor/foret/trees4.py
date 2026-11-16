"""Nouvelles essences de la forêt (même rendu en volume que trees3.py) : la forêt devient dense.

  bananier       (120 × 150)  faux-tronc gainé, grandes feuilles déchirées en lanières qui
                              retombent, un régime de bananes et son bourgeon violet
  acacia         (230 × 230)  tronc tortueux qui se divise, couronne plate en parasol
  cailcedrat     (260 × 320)  caïlcédrat : fût gris à écailles, grosses branches, houppier dense
  citronnier     (110 × 110)  petit arbre au feuillage serré et luisant, citrons jaunes
  buisson_dense  (70 × 44)    buisson de sous-bois, feuilles en paquets
  buisson_fleuri (64 × 40)    buisson à fleurs rouges (hibiscus)
  herbe_haute    (48 × 40)    touffe de hautes herbes souples
Version sèche (<nom>.png, forêt malade : feuilles grises, fruits ternes) et guérie (_green).

Utilisation : python3 trees4.py DOSSIER_SORTIE [noms…]
"""
import math, os, random, sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dlib import Sprite, hexc
from trees3 import (fbm, poly_mask, relief, lit, paint, outline, contact, litter, mossify, curve,
                    LEAF, GREYBARK, IROKO, SINK)

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
BANANA_STEM = {True: [hexc(c) for c in ("1c2a14", "2c4220", "3f5c2c", "56783a", "6f924a")],
               False: [hexc(c) for c in ("2a2924", "3b3933", "4e4b43", "625e54", "777266")]}
BANANA_LEAF = {True: [hexc(c) for c in ("173018", "224a22", "2f6630", "43843c", "62a24e", "86bc64")],
               False: [hexc(c) for c in ("292824", "383631", "4a4740", "5d5950", "726d62", "898376")]}
DRY_LEAF = [hexc(c) for c in ("2a1e12", "45321c", "604628", "7c5c36")]
ACACIA_BARK = [hexc(c) for c in ("17110d", "261c15", "36291f", "47372a", "5a4636", "6e5844")]
FRUIT = {True: [hexc(c) for c in ("6a5a10", "a89018", "d8c030", "f4e070")], False: [hexc(c) for c in ("4a4636", "625d48", "7a745c", "908a70")]}
BUD = {True: [hexc(c) for c in ("2a0e1e", "4a1834", "70264a", "963a60")], False: [hexc(c) for c in ("2e2a2c", "433d40", "585155", "6c656a")]}
RED = {True: [hexc(c) for c in ("5a0e0e", "901a16", "c42c20", "ea5a3a")], False: [hexc(c) for c in ("3e3634", "554b48", "6c605c", "807470")]}


def crown(s, blobs, pal, seed, ambient=0.14, texture=1.0, tips=True, squash=1.0):
    """Un feuillage : une union de paquets de feuilles (des sphères bosselées au bord
    découpé en feuilles), éclairée en volume, creusée de trous sombres et de feuilles."""
    rr = random.Random(seed)
    H, W = s.h, s.w
    hg = np.zeros((H, W)); m = np.zeros((H, W), bool)
    for (bx, by, r) in blobs:
        ang = np.arctan2(s.yy - by, s.xx - bx)
        ph = rr.uniform(0, 6.28)
        rad = r * (1 + 0.05 * np.sin(ang * 5 + ph) + 0.06 * np.sin(ang * 11 + ph * 2) + 0.04 * np.sin(ang * 23 + ph))
        d = np.sqrt((s.xx - bx) ** 2 + ((s.yy - by) / squash) ** 2)
        inside = d < rad
        h = np.sqrt(np.clip(1 - (d / np.maximum(rad, 1)) ** 2, 0, 1)) * r * 0.8
        hg = np.where(inside, np.maximum(hg, h + rr.uniform(0, r * 0.15)), hg)
        m |= inside
    leaf = fbm(H, W, seed + 1, (5, 3, 2))
    hg = hg + texture * 3.0 * leaf
    val = lit(hg, m, ambient)
    val -= 0.22 * (leaf < 0.22)                                  # creux sombres entre les feuilles
    paint(s, m, val, pal)
    if tips:                                                       # feuilles qui dépassent du bord
        edge = np.argwhere(m & ~ndimage.binary_erosion(m, iterations=1))
        for (y, x) in edge[rr.sample(range(len(edge)), min(len(edge), len(edge) // 5))] if len(edge) else []:
            a = math.atan2(y - H / 2, x - W / 2) + rr.uniform(-0.8, 0.8)
            for k in range(1, rr.choice((2, 3, 3, 4))):
                xi, yi = int(x + math.cos(a) * k), int(y + math.sin(a) * k + 0.4 * k)
                if 0 <= xi < W and 0 <= yi < H and not m[yi, xi]:
                    s.rgb[yi, xi] = pal[max(0, min(len(pal) - 1, 2 + (y < H * 0.4)))]; s.a[yi, xi] = True
    return m


def branch(s, pts, w0, w1, pal, light=1.0):
    """Une branche (ou un tronc) suivant une courbe, qui s'amincit, éclairée en cylindre."""
    P = curve(*pts, n=60) if len(pts) == 4 else np.array(pts, float)
    left, right = [], []
    for j in range(len(P)):
        t = j / (len(P) - 1)
        k2, k1 = min(j + 1, len(P) - 1), max(j - 1, 0)
        dx, dy = P[k2] - P[k1]; nl = math.hypot(dx, dy) or 1
        nx, ny = -dy / nl, dx / nl
        w = w0 + (w1 - w0) * t
        left.append((P[j][0] + nx * w, P[j][1] + ny * w)); right.append((P[j][0] - nx * w, P[j][1] - ny * w))
    m = poly_mask(s, left + right[::-1])
    paint(s, m, lit(relief(m, max(w0, 2.0)), m, 0.16) * light, pal)
    return m


# =========================================================================================
def bananier(healthy):
    W, H = 160, 160
    s = Sprite(W, H)
    g = H - 4
    cx = 80
    rr = random.Random(21)
    # feuilles sèches pendues le long du faux-tronc
    for k, side in enumerate((-1, 1, -1)):
        y0 = 72 + k * 10
        m = branch(s, [(cx, y0), (cx + side * 8, y0 + 12), (cx + side * 12, y0 + 30), (cx + side * 10, y0 + 46)], 4, 1.5, DRY_LEAF, 0.9)
    # le faux-tronc : gaines superposées, légèrement renflé au pied
    def half(y): return 6 + 3 * ((y - 60) / (g - 60)) ** 2.5
    m = poly_mask(s, [(cx - half(y) + 1.5 * math.sin(y * 0.05), y) for y in range(60, g + 1, 3)] + [(cx - 9, H), (cx + 9, H)] +
                  [(cx + half(y) + 1.5 * math.sin(y * 0.05), y) for y in range(g, 59, -3)])
    sheath = ((s.xx - cx) * 0.6 + s.yy * 0.15) % 6 / 6.0
    paint(s, m, lit(relief(m, 6.0) + np.where(m, 1.6 * sheath, 0), m, 0.16), BANANA_STEM[healthy])
    st = m & (fbm(H, W, 3, (4, 2)) > 0.75)
    s.rgb[st] = (s.rgb[st] * 0.75).astype(np.uint8)                # taches brunes des gaines
    # le régime et son bourgeon (côté droit, il pend sous la couronne)
    stalk = branch(s, [(cx + 2, 60), (cx + 12, 64), (cx + 18, 72), (cx + 20, 82)], 1.6, 1.2, BANANA_STEM[healthy])
    for row in range(4):
        for k in range(4):
            bx, by = cx + 14 + k * 2.5 - row * 0.5, 68 + row * 5
            mm = poly_mask(s, curve((bx, by), (bx + 3, by - 1), (bx + 5, by - 4), (bx + 5, by - 7), 10).tolist() + [(bx + 1, by + 1)])
            paint(s, mm, lit(relief(mm, 2.0), mm, 0.2), FRUIT[healthy] if healthy else FRUIT[False])
    bud = poly_mask(s, [(cx + 18, 82), (cx + 23, 84), (cx + 22, 94), (cx + 19, 98), (cx + 17, 92)])
    paint(s, bud, lit(relief(bud, 3.0), bud, 0.2), BUD[healthy])
    # les feuilles : grandes, nervure centrale, limbe déchiré en lanières qui retombent
    leaves = [(-165, 78), (-140, 74), (-112, 64), (-68, 70), (-40, 76), (-15, 74), (-92, 56)]
    for deg, L in leaves:
        a = math.radians(deg)
        x0, y0 = cx, 60
        rise = -math.sin(a)
        P = curve((x0, y0), (x0 + math.cos(a) * L * 0.35, y0 - L * (0.4 + 0.45 * rise)),
                  (x0 + math.cos(a) * L * 0.75, y0 - L * (0.2 + 0.35 * rise)), (x0 + math.cos(a) * L * 0.95, y0 + L * (0.15 - 0.2 * rise)), 40)
        for j in range(4, len(P)):
            t = j / (len(P) - 1)
            px, py = P[j]
            dx, dy = P[min(j + 1, len(P) - 1)] - P[j - 1]; nl = math.hypot(dx, dy) or 1
            nx, ny = -dy / nl, dx / nl
            if ny > 0: nx, ny = -nx, -ny
            w = 11 * math.sin(math.pi * min(1, t * 1.05)) ** 0.7 + 1
            torn = rr.random() < 0.25
            for sd, frac in ((1, 0.8), (-1, 1.0)):
                if torn and sd < 0: continue                         # une lanière arrachée
                ex = px + sd * nx * w * frac
                ey = py + sd * ny * w * frac + (w * 0.55 if sd < 0 else 0)
                mm = s.mask(lambda d, px=px, py=py, ex=ex, ey=ey: d.line([(px, py), (ex, ey)], fill=255, width=2))
                v = (0.68 if sd > 0 else 0.38) - 0.15 * t + 0.06 * rr.random()
                paint(s, mm, np.full(mm.shape, v), BANANA_LEAF[healthy])
        mm = s.mask(lambda d, P=P: d.line([tuple(p) for p in P[3:]], fill=255, width=1))
        paint(s, mm, np.full(mm.shape, 0.85), BANANA_LEAF[healthy])
    outline(s, 6)
    contact(s, g, 10, 0.4)
    litter(s, g, cx - 24, cx + 24, healthy, 31)
    return s


def acacia(healthy):
    W, H = 230, 230
    s = Sprite(W, H)
    g = H - SINK
    pal = LEAF[healthy]
    # tronc tortueux qui se divise en trois charpentières
    branch(s, [(112, g + 6), (108, g - 50), (122, g - 90), (114, g - 120)], 8, 6, ACACIA_BARK)
    branch(s, [(114, g - 118), (90, g - 140), (70, g - 160), (52, g - 176)], 5.5, 2.5, ACACIA_BARK)
    branch(s, [(116, g - 118), (126, g - 150), (146, g - 166), (170, g - 180)], 5, 2.5, ACACIA_BARK)
    branch(s, [(115, g - 120), (112, g - 150), (110, g - 170), (108, g - 186)], 4, 2, ACACIA_BARK)
    branch(s, [(62, g - 168), (46, g - 170), (34, g - 174), (24, g - 180)], 2, 1, ACACIA_BARK)
    branch(s, [(160, g - 174), (180, g - 176), (196, g - 180), (208, g - 184)], 2, 1, ACACIA_BARK)
    # la couronne plate en parasol : des paquets étalés en nappes
    blobs = []
    rr = random.Random(41)
    for k in range(46):
        x = rr.uniform(14, 216); y = 34 + 5 * math.sin(x * 0.05) + rr.uniform(-5, 5) + 0.0018 * (x - 115) ** 2
        blobs.append((x, y, rr.uniform(10, 17)))
    crown(s, blobs, pal, 41, 0.12, squash=0.55)
    # dessous de la couronne : ombre plate (les acacias ont un dessous net)
    under = s.a & (s.yy > 40) & (s.yy < 70) & (s.xx > 10) & (s.xx < 220)
    flat = under & ~np.roll(s.a, -3, 0)
    s.rgb[flat] = np.array(pal[0])
    outline(s, SINK + 2)
    contact(s, g, 16, 0.5)
    litter(s, g, 80, 150, healthy, 42)
    return s


def cailcedrat(healthy):
    W, H = 260, 320
    s = Sprite(W, H)
    g = H - SINK
    pal = LEAF[healthy]
    tex = fbm(H, W, 51, (8, 4))
    # fût droit, épais, écorce grise en écailles qui se détachent ; contreforts discrets
    def cx(y): return 128 + 3 * math.sin(y * 0.01)
    def half(y): t = (y - 120) / (g - 120); return 17 + 12 * max(t, 0) ** 6
    for side, sp, h in ((-1, 26, 46), (1, 30, 40)):
        pts = [(cx(g - h) + side * (half(g - h) - 2), g - h)]
        for j in range(1, 13):
            t = j / 12; y = g - h * (1 - t) ** 2
            pts.append((cx(y) + side * (half(y) - 2 + sp * t), y))
        pts += [(cx(g) + side * (half(g) + sp), H), (cx(g), H)]
        m = poly_mask(s, pts)
        paint(s, m, lit(relief(m, 5.0), m, 0.15) * (1 if side < 0 else 0.75), GREYBARK)
    m = poly_mask(s, [(cx(y) - half(y), y) for y in range(110, g + 1, 4)] + [(cx(g) - half(g), H), (cx(g) + half(g), H)] +
                  [(cx(y) + half(y), y) for y in range(g, 109, -4)])
    scales = (np.abs(np.sin(s.xx * 0.5 + tex * 5)) < 0.18) | (np.abs(np.sin(s.yy * 0.33 + s.xx * 0.08 + tex * 4)) < 0.12)
    paint(s, m, lit(relief(m, 18.0) - np.where(m, 2.2 * scales, 0), m, 0.17) + 0.05 * (tex - 0.5), GREYBARK)
    # grosses branches qui partent dans le houppier
    branch(s, [(cx(116) - 6, 118), (110, 96), (82, 84), (56, 70)], 8, 3, GREYBARK, 0.95)
    branch(s, [(cx(116) + 6, 116), (150, 92), (176, 80), (204, 66)], 8, 3, GREYBARK, 0.8)
    branch(s, [(cx(112), 114), (130, 86), (126, 60), (132, 40)], 7, 3, GREYBARK, 0.9)
    # houppier dense et arrondi, en gros paquets
    rr = random.Random(52)
    blobs = [(130, 50, 46), (80, 66, 36), (186, 62, 38), (52, 86, 24), (210, 84, 24), (112, 30, 30), (158, 32, 30)]
    while len(blobs) < 47:
        x, y = rr.uniform(26, 234), rr.uniform(16, 100)
        if ((x - 130) / 100) ** 2 + ((y - 60) / 46) ** 2 < 1:
            blobs.append((x, y, rr.uniform(9, 18)))
    crown(s, blobs, pal, 52, 0.12)
    # sous le houppier, l'ombre sur le fût
    sh = m & (s.yy < 150)
    s.rgb[sh] = (s.rgb[sh] * (0.6 + 0.4 * np.clip((s.yy[sh] - 110) / 40, 0, 1))[:, None]).astype(np.uint8)
    mossify(s, s.a & (s.yy > g - 60), healthy, 53, 1, 0.2)
    outline(s, SINK + 2)
    contact(s, g, 26, 0.55)
    litter(s, g, 60, 200, healthy, 54)
    return s


def citronnier(healthy):
    W, H = 110, 110
    s = Sprite(W, H)
    g = H - 4
    branch(s, [(54, g + 4), (52, g - 20), (58, g - 34), (54, g - 46)], 4, 3, ACACIA_BARK)
    branch(s, [(54, g - 40), (44, g - 50), (36, g - 56), (28, g - 60)], 2.5, 1.2, ACACIA_BARK)
    branch(s, [(55, g - 42), (66, g - 52), (74, g - 58), (82, g - 62)], 2.5, 1.2, ACACIA_BARK)
    rr = random.Random(61)
    blobs = [(55, 40, 30), (34, 50, 20), (78, 48, 21), (50, 22, 18), (70, 26, 16)]
    for k in range(10):
        blobs.append((rr.uniform(26, 86), rr.uniform(18, 64), rr.uniform(7, 12)))
    m = crown(s, blobs, LEAF[healthy], 61, 0.14)
    # citrons : petites sphères jaunes, éclairées, à moitié cachées dans le feuillage
    for k in range(16):
        x, y = rr.uniform(26, 86), rr.uniform(22, 70)
        if not m[int(y), int(x)]: continue
        mm = s.mask(lambda d, x=x, y=y: d.ellipse((x - 2.5, y - 2, x + 2.5, y + 3), fill=255))
        paint(s, mm, lit(relief(mm, 2.5), mm, 0.25), FRUIT[healthy])
    outline(s, 4)
    contact(s, g, 8, 0.4)
    litter(s, g, 30, 80, healthy, 62)
    return s


def buisson_dense(healthy):
    W, H = 70, 44
    s = Sprite(W, H)
    rr = random.Random(71)
    blobs = [(35, 28, 16), (18, 32, 12), (52, 31, 13), (28, 18, 10), (44, 18, 9)]
    for k in range(8): blobs.append((rr.uniform(10, 60), rr.uniform(16, 38), rr.uniform(5, 8)))
    crown(s, blobs, LEAF[healthy], 71, 0.12)
    s.a[H - 1:] = s.a[H - 1:]; outline(s, 3)
    contact(s, H - 2, 12, 0.5)
    return s


def buisson_fleuri(healthy):
    W, H = 64, 40
    s = Sprite(W, H)
    rr = random.Random(81)
    blobs = [(32, 25, 14), (16, 29, 10), (48, 28, 11), (26, 15, 9), (40, 16, 8)]
    m = crown(s, blobs, LEAF[healthy], 81, 0.14)
    for k in range(9):
        x, y = rr.uniform(10, 54), rr.uniform(10, 32)
        if not m[int(y), int(x)]: continue
        for a in range(5):                                           # une fleur : cinq pétales
            ang = a * 2 * math.pi / 5 + k
            mm = s.mask(lambda d, x=x, y=y, ang=ang: d.ellipse((x + 2 * math.cos(ang) - 1.3, y + 2 * math.sin(ang) - 1.3,
                                                                x + 2 * math.cos(ang) + 1.3, y + 2 * math.sin(ang) + 1.3), fill=255))
            paint(s, mm, np.full(mm.shape, 0.6 + 0.3 * (math.sin(ang) < 0)), RED[healthy])
        s.rgb[int(y), int(x)] = (240, 210, 90) if healthy else (130, 124, 110)
    outline(s, 3)
    contact(s, H - 2, 10, 0.45)
    return s


def herbe_haute(healthy):
    W, H = 48, 40
    s = Sprite(W, H)
    rr = random.Random(91)
    pal = LEAF[healthy]
    for k in range(26):
        x0 = 10 + rr.uniform(0, 28); L = rr.uniform(18, 38); bend = rr.uniform(-14, 14)
        P = curve((x0, H), (x0 + bend * 0.1, H - L * 0.5), (x0 + bend * 0.6, H - L * 0.9), (x0 + bend, H - L + abs(bend) * 0.3), 20)
        for j, (x, y) in enumerate(P):
            w = 1.2 * (1 - j / 20)
            mm = s.mask(lambda d, x=x, y=y, w=w: d.ellipse((x - w, y - 0.6, x + w, y + 0.6), fill=255))
            paint(s, mm, np.full(mm.shape, 0.3 + 0.45 * (bend < 0) + 0.15 * rr.random()), pal)
    return s


ALL = {"bananier": bananier, "acacia": acacia, "cailcedrat": cailcedrat, "citronnier": citronnier,
       "buisson_dense": buisson_dense, "buisson_fleuri": buisson_fleuri, "herbe_haute": herbe_haute}

if __name__ == "__main__":
    names = sys.argv[2:] or list(ALL)
    for n in names:
        for healthy, suf in ((False, ""), (True, "_green")):
            sp = ALL[n](healthy)
            im = np.zeros((sp.h, sp.w, 4), np.uint8); im[..., :3] = sp.rgb; im[..., 3] = sp.a * 255
            Image.fromarray(im, "RGBA").save(os.path.join(OUT, n + suf + ".png"))
    print("essences :", ", ".join(names))
