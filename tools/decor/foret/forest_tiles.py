"""Tuiles de la forêt des irokos (16 × 16) : humus, mousse (ou cendre grise quand la forêt
est corrompue), plateformes en branches. Usage : forest_tiles.py <sortie.png> [sain|corrompu]

Technique : pas de bruit pixel par pixel, mais des amas (mottes, cailloux éclairés,
strates), dessinés « en boucle » pour que les tuiles se raccordent sans couture.
Lumière venant d'en haut à gauche.

Atlas (colonne, ligne) :
  ligne 0 : coin haut gauche, sommet A, B, C, coin haut droit, colonne isolée (haut)
  ligne 1 : bord gauche, plein A, B, C, bord droit, colonne isolée (milieu)
  ligne 2 : coin bas gauche, bas A, B, C, coin bas droit, colonne isolée (bas)
  ligne 3 : coin intérieur gauche, coin intérieur droit, planche gauche, milieu, droite
"""
from PIL import Image
import random, sys
T = 16
CLEAR = (0, 0, 0, 0)
MODE = sys.argv[2] if len(sys.argv) > 2 else "sain"
def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
OUT = rgb("140d0c")
# humus : brun froid et sombre
L = [rgb(c) for c in ("2a1c13", "3a291c", "4c3725", "5e4630", "72583c", "8a6e4e")]
BASE = L[2]
if MODE == "sain":       # mousse vivante
    G = [rgb(c) for c in ("1d3a1f", "2b5229", "3c6e33", "58904a", "86b66a")]
else:                    # la poussière d'Adaka : herbe morte, cendre grise
    G = [rgb(c) for c in ("3a3733", "55514a", "726c62", "958d7f", "b8af9e")]
    L = [rgb(c) for c in ("2c241f", "3b322b", "4c4137", "5d5044", "6f6253", "837565")]
    BASE = L[2]
LITTER = [rgb(c) for c in (("6b4a22", "8a5a2a", "5a3a1e") if MODE == "sain" else ("6a645a", "7e776b", "55504a"))]
# branches : écorce sombre
W = [rgb(c) for c in ("1c120c", "2f1f15", "45301f", "5c432c", "7a5c3e")]

atlas = Image.new("RGBA", (T * 6, T * 4), CLEAR)

def px(im, x, y, c):
    im.putpixel((x % T, y % T), c)

def dirt(seed):
    """Latérite pleine, raccordable : strates, mottes, cailloux, fissure."""
    rnd = random.Random(seed)
    im = Image.new("RGBA", (T, T), BASE)
    # strates horizontales douces (deux bandes légèrement plus sombres)
    for band_y in (rnd.randrange(0, 8), rnd.randrange(8, 16)):
        for x in range(T):
            if rnd.random() < 0.55:
                px(im, x, band_y + (1 if (x // 5) % 2 else 0), L[1] if rnd.random() < 0.5 else L[3])
    # mottes sombres (amas de 3 à 5 pixels)
    for _ in range(3):
        cx, cy = rnd.randrange(T), rnd.randrange(T)
        for dx, dy in [(0, 0), (1, 0), (0, 1), (1, 1), (2, 1)][: rnd.randrange(3, 6)]:
            px(im, cx + dx, cy + dy, L[1])
    # cailloux éclairés : reflet en haut à gauche, ombre en bas à droite
    for _ in range(2):
        cx, cy = rnd.randrange(T), rnd.randrange(T)
        px(im, cx, cy, L[4]); px(im, cx + 1, cy, L[3])
        px(im, cx, cy + 1, L[3]); px(im, cx + 1, cy + 1, L[1]); px(im, cx + 2, cy + 1, L[0])
        if rnd.random() < 0.5: px(im, cx - 1, cy + 1, L[5])
    # radicelles : petits fils clairs qui serpentent dans l'humus
    if rnd.random() < 0.7:
        x, y = rnd.randrange(T), rnd.randrange(T)
        for _ in range(rnd.randrange(4, 8)):
            px(im, x, y, L[4]); x += 1; y += rnd.choice((-1, 0, 0, 1))
    return im

def turf(im, seed):
    """Dessus : sol tassé sombre et herbe sèche brin par brin (rangées 0 à 6)."""
    rnd = random.Random(seed)
    for x in range(T):
        for y in range(0, 7):
            im.putpixel((x, y), CLEAR)
    for x in range(T):
        im.putpixel((x, 6), L[1])                       # sol tassé
        im.putpixel((x, 7), L[1] if rnd.random() < 0.6 else L[2])
        im.putpixel((x, 5), G[0])                       # pied de l'herbe
        im.putpixel((x, 4), G[1])
        im.putpixel((x, 3), G[2] if rnd.random() < 0.75 else G[1])
    # brins : tiges de 1 à 3 pixels au-dessus du tapis, pointe claire
    for x in range(T):
        h = rnd.choice((0, 1, 1, 2, 2, 3, 3))
        for k in range(h):
            y = 2 - k
            im.putpixel((x, y), G[3] if k == h - 1 else G[2])
    for x in range(T):                                   # reflets sur le tapis
        if rnd.random() < 0.25: im.putpixel((x, 3), G[3])
    for _ in range(3):                                   # litière : feuilles tombées dans l'humus
        x, y = rnd.randrange(T - 1), rnd.randrange(8, 11)
        leaf = LITTER[rnd.randrange(len(LITTER))]
        im.putpixel((x, y), leaf); im.putpixel((x + 1, y), leaf)
    return im

def side(im, which):
    """Bord vertical : contour, liseré clair (gauche, côté lumière) ou ombre (droite)."""
    xo, xi = (0, 1) if which == "left" else (T - 1, T - 2)
    for y in range(T):
        if im.getpixel((xo, y))[3] == 0:
            continue
        im.putpixel((xo, y), OUT)
        c = im.getpixel((xi, y))
        if c[:3] in [g[:3] for g in G]:
            continue
        im.putpixel((xi, y), L[3] if which == "left" else L[1])
    return im

def round_top(im, which):
    """Arrondit l'herbe au coin : le tapis descend et se termine par une touffe."""
    xs = (0, 1, 2) if which == "left" else (T - 1, T - 2, T - 3)
    for i, x in enumerate(xs):
        for y in range(0, 4 - i):
            im.putpixel((x, y), CLEAR)
    x0, x1 = xs[0], xs[1]
    im.putpixel((x0, 4), G[0]); im.putpixel((x0, 5), OUT); im.putpixel((x1, 3), G[1])
    for y in range(6, T):
        im.putpixel((x0, y), OUT)
    return im

def underside(im):
    """Dessous : contour, ombre portée, petites racines."""
    rnd = random.Random(im.getpixel((3, 3))[0])
    for x in range(T):
        im.putpixel((x, T - 1), OUT)
        if im.getpixel((x, T - 2))[3]:
            im.putpixel((x, T - 2), L[0])
            im.putpixel((x, T - 3), L[1] if rnd.random() < 0.6 else im.getpixel((x, T - 3)))
    return im

def put(im, c, r):
    atlas.paste(im, (c * T, r * T))

# Ligne 0 — sommets
put(side(round_top(turf(dirt(1), 101), "left"), "left"), 0, 0)
for i in range(3):
    put(turf(dirt(10 + i), 110 + i), 1 + i, 0)
put(side(round_top(turf(dirt(4), 104), "right"), "right"), 4, 0)
put(side(side(round_top(round_top(turf(dirt(5), 105), "left"), "right"), "left"), "right"), 5, 0)
# Ligne 1 — côtés et plein
put(side(dirt(21), "left"), 0, 1)
for i in range(3):
    put(dirt(30 + i), 1 + i, 1)
put(side(dirt(24), "right"), 4, 1)
put(side(side(dirt(25), "left"), "right"), 5, 1)
# Ligne 2 — dessous
put(underside(side(dirt(41), "left")), 0, 2)
for i in range(3):
    put(underside(dirt(50 + i)), 1 + i, 2)
put(underside(side(dirt(44), "right")), 4, 2)
put(underside(side(side(dirt(45), "left"), "right")), 5, 2)

# Ligne 3 — coins intérieurs : plein, avec l'herbe du sommet voisin qui déborde
def inner(which, seed):
    im = dirt(seed)
    rnd = random.Random(seed)
    xs = range(0, 6) if which == "left" else range(T - 6, T)
    for i, x in enumerate(xs):
        reach = (6 - i) if which == "left" else (i + 1)
        for y in range(0, max(1, reach // 2)):
            im.putpixel((x, y), G[1] if y else G[0])
        im.putpixel((x, max(1, reach // 2)), L[1])
    return im
put(inner("left", 61), 0, 3)
put(inner("right", 62), 1, 3)

def plank(kind):
    """Branche couchée (6 px) : écorce ronde, lumière en haut, liée par une liane aux bouts."""
    im = Image.new("RGBA", (T, T), CLEAR)
    rnd = random.Random(hash(kind) % 100)
    for x in range(T):
        im.putpixel((x, 0), W[1])
        im.putpixel((x, 1), W[4] if (x + 1) % 6 else W[3])
        im.putpixel((x, 2), W[3])
        im.putpixel((x, 3), W[2] if x % 5 else W[1])
        im.putpixel((x, 4), W[1])
        im.putpixel((x, 5), W[0])
    for x in (4, 11):                                    # nœuds de l'écorce
        im.putpixel((x, 2), W[1]); im.putpixel((x + 1, 3), W[0])
    for _ in range(3):                                   # mousse ou cendre sur le dessus
        x = rnd.randrange(T)
        im.putpixel((x, 0), G[2]); im.putpixel((min(T - 1, x + 1), 0), G[1])
    if kind in ("left", "right"):
        xo = 0 if kind == "left" else T - 1
        for y in range(0, 6): im.putpixel((xo, y), OUT)
        p = 3 if kind == "left" else T - 4               # liane qui pend du bout
        for y in range(0, T):
            if y < 6: im.putpixel((p, y), G[1] if y % 2 else G[0])
            else: im.putpixel((p + (1 if (y // 3) % 2 else 0), y), G[1] if y % 3 else G[2])
    return im
put(plank("left"), 2, 3); put(plank("mid"), 3, 3); put(plank("right"), 4, 3)

atlas.save(sys.argv[1])

# Aperçu : un morceau de terrain, sur le fond du ciel
pv = Image.new("RGBA", (T * 16, T * 8), (40, 58, 52, 255))
def at(c, r): return atlas.crop((c * T, r * T, c * T + T, r * T + T))
rows = [
    "................",
    ".........lmr....",
    "................",
    ".A12B.......A2B.",
    ".LabR...A31IabR.",
    ".LbcK123JabcabR.",
    ".LcabcabcabcabR.",
    ".DxyzxyzxyzxyzE.",
]
m = {"A": (0, 0), "1": (1, 0), "2": (2, 0), "3": (3, 0), "B": (4, 0),
     "L": (0, 1), "a": (1, 1), "b": (2, 1), "c": (3, 1), "R": (4, 1),
     "D": (0, 2), "x": (1, 2), "y": (2, 2), "z": (3, 2), "E": (4, 2),
     "J": (0, 3), "K": (1, 3), "I": (0, 3), "l": (2, 3), "m": (3, 3), "r": (4, 3)}
for y, row in enumerate(rows):
    for x, ch in enumerate(row):
        if ch in m: pv.alpha_composite(at(*m[ch]), (x * T, y * T))
pv.resize((pv.width * 4, pv.height * 4), Image.NEAREST).save(f"tiles_prev_{MODE}.png")

# ---------------------------------------------------------------------------
# Profondeur : versions assombries de la ligne 1 (lignes 4 à 7), et paroi de grotte
# ---------------------------------------------------------------------------
def darken(im, k):
    out = im.copy()
    for y in range(T):
        for x in range(T):
            c = im.getpixel((x, y))
            if c[3] == 0 or c[:3] == OUT[:3]: continue
            # on assombrit et on refroidit légèrement (la lumière ne descend pas si bas)
            out.putpixel((x, y), (int(c[0] * k), int(c[1] * k * 0.98), int(c[2] * k * 1.02), 255))
    return out

big = Image.new("RGBA", (T * 6, T * 8), CLEAR)
big.paste(atlas, (0, 0))
def dither_top(lighter, darker):
    """Fond enchaîné : le haut de la tuile sombre reprend la tuile claire, en tramage,
    pour que le passage d'une profondeur à l'autre ne fasse pas une ligne droite."""
    out = darker.copy()
    for y in range(6):
        for x in range(T):
            if (y * 16 / 6) < (15 - BAYER4[y % 4][x % 4]):
                out.putpixel((x, y), lighter.getpixel((x, y)))
    return out
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
for col in range(6):
    tile_ = atlas.crop((col * T, T, col * T + T, 2 * T))
    d1, d2 = darken(tile_, 0.84), darken(tile_, 0.70)
    big.paste(dither_top(tile_, d1), (col * T, 4 * T))   # passage clair → sombre
    big.paste(d1, (col * T, 5 * T))                         # sombre
    big.paste(dither_top(d1, d2), (col * T, 6 * T))         # passage sombre → très sombre
    big.paste(d2, (col * T, 7 * T))                         # très sombre
# paroi de grotte (case 5,3) : terre très sombre, sans collision, derrière les cavités
cave = darken(dirt(90), 0.5)
big.paste(cave, (5 * T, 3 * T))
big.save(sys.argv[1])
