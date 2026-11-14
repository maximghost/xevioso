"""Décors de la forêt des irokos, deuxième génération : des arbres variés, bien ancrés au sol.

Chaque décor existe en deux états : <nom>.png (forêt malade, poussière grise d'Adaka) et
<nom>_green.png (forêt guérie, échangé à la victoire).

Ancrage : chaque arbre descend SINK px sous la ligne du sol (le niveau les pose ainsi, et la
terre les recouvre) ; ses racines courent à la surface en s'amincissant, une ombre de contact
assombrit le pied, et une litière de mousse, de feuilles et de petites pousses habille la
jonction. Pas de contour en bas : rien ne « flotte ».

  iroko        le géant aux contreforts, écorce brune striée, racines rampantes
  fromager     tronc gris lisse hérissé d'épines coniques, immenses contreforts en planches
  raphia       palmier à tronc fibreux et palmes en arc (balancent)
  arbre_mort   squelette gris, branches cassées, trou, champignons-consoles
  figuier      figuier étrangleur : un treillis de racines autour d'un vide (l'arbre hôte est mort)
  termitiere   termitière cathédrale à cheminées
  colocase     grandes feuilles en cœur (balancent)
  grande_fougere, toile (toile d'araignée), champignons_bleus (lumineux : leur lueur est
  ajoutée par le niveau)
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dlib import Sprite, BAY, OUTLINE, hexc, BARK, LEAF, MOSS

OUT = sys.argv[1]
SINK = 8                                     # px de l'arbre sous la ligne du sol

LITTER = {True: [hexc(c) for c in ("2b5229", "3c6e33", "58904a", "6b4a22", "8a5a2a")],
          False: [hexc(c) for c in ("4a4640", "5a554d", "6e685e", "6a645a", "7e776b")]}
GREYBARK = [hexc(c) for c in ("1c1c1b", "2f2f2c", "45443f", "5d5b54", "77746a", "918d80", "aaa596")]
DEADBARK = [hexc(c) for c in ("1a1816", "2c2925", "403b35", "57514a", "6e675e", "878074")]
PALMBARK = [hexc(c) for c in ("1d150f", "30231a", "463427", "5e4736", "7a5e48")]
TERM = [hexc(c) for c in ("2b1d16", "3e2a1f", "54392a", "6b4a37", "835c45", "9c7158")]
WEB = (200, 200, 196)


def outline_open(s, open_rows):
    """Contour sombre, sauf sur les « open_rows » lignes du bas (le pied entre dans le sol)."""
    a = s.a
    o = np.zeros_like(a)
    o[1:] |= a[:-1]; o[:-1] |= a[1:]; o[:, 1:] |= a[:, :-1]; o[:, :-1] |= a[:, 1:]
    o &= ~a
    o[s.h - open_rows:] = False
    s.rgb[o] = OUTLINE
    s.a |= o


def contact(s, ground_y, depth=18, strength=0.55):
    """Ombre de contact : le pied s'assombrit en approchant du sol (lumière qui ne passe pas)."""
    k = np.clip((s.yy - (ground_y - depth)) / depth, 0, 1) * strength
    sel = s.a & (k > 0)
    s.rgb[sel] = (s.rgb[sel] * (1 - k[sel, None])).astype(np.uint8)


def litter(s, ground_y, x0, x1, healthy, seed, density=1.0):
    """Litière au pied : petites touffes de mousse, feuilles mortes, brins, pousses."""
    r = random.Random(seed)
    pal = LITTER[healthy]
    for i in range(int((x1 - x0) * 0.9 * density)):
        x = r.uniform(x0, x1)
        y = ground_y - r.choice((0, 0, 0, 1, 1, 2))
        c = pal[r.randrange(len(pal))]
        for dx in range(r.choice((1, 2, 2, 3))):
            xi, yi = int(x + dx), int(y)
            if 0 <= xi < s.w and 0 <= yi < s.h:
                s.rgb[yi, xi] = c; s.a[yi, xi] = True
    for i in range(int((x1 - x0) / 14 * density)):   # brins d'herbe et pousses
        x = int(r.uniform(x0, x1))
        h = r.randint(2, 5)
        c = pal[r.randrange(3)]
        for j in range(h):
            yi, xi = ground_y - 1 - j, x + (1 if j > h // 2 and r.random() < 0.4 else 0)
            if 0 <= xi < s.w and 0 <= yi < s.h:
                s.rgb[yi, xi] = c; s.a[yi, xi] = True


def dust(s, healthy, amount, seed):
    if healthy:
        return
    rr = np.random.default_rng(seed)
    sel = s.a & (rr.random(s.a.shape) < amount)
    s.rgb[sel] = (126, 120, 110)


def shade_band(s, m, u, ridge, pal, light=1.0, rim=True, base=0.1, span=0.55):
    """Ombrage générique d'un volume : u = position 0..1 dans la largeur (lumière à gauche)."""
    val = base + span * (1 - u) ** 1.3 * light + 0.13 * ridge + (0.16 * (u < 0.05) if rim else 0)
    val[ridge < -0.82] = 0.0
    s.paint(m, val, pal)


def edge_line(s, m, color, below):
    """Trace le bord d'une forme (pour détacher un contrefort de celui qui est derrière)."""
    e = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    e &= s.yy < below
    s.rgb[e] = color


def root_tendril(d, x0, y0, length, side, thick, sag, rnd):
    """Une racine qui court au sol : épaisse au départ, fine au bout, qui ondule un peu."""
    pts_top, pts_bot = [], []
    for j in range(16):
        t = j / 15
        x = x0 + side * length * t
        y = y0 + sag * t + 1.2 * math.sin(t * 9 + rnd)
        w = thick * (1 - t) ** 1.4 + 0.6
        pts_top.append((x, y - w)); pts_bot.append((x, y + w * 0.4))
    d.polygon(pts_top + pts_bot[::-1], fill=255)


# =========================================================================================
def iroko(healthy):
    W, H = 240, 330
    s = Sprite(W, H)
    g = H - SINK                      # ligne du sol dans l'image
    cx, top = 120, 0
    def half(y):
        t = (y - top) / (g - top)
        return 26 + 3 * math.sin(t * 7) + 46 * t ** 8
    # racines rampantes (derrière, dessinées d'abord) : elles partent des contreforts
    rnd = random.Random(7)
    for side in (-1, 1):
        for k, (L, th, sag) in enumerate(((95, 5, 2), (70, 4, 3), (55, 3.5, 1))):
            x0 = cx + side * (half(g) + 6 - k * 10)
            m = s.mask(lambda d, x0=x0, L=L, th=th, sag=sag, side=side: root_tendril(d, x0, g - 1, L, side, th, sag, rnd.uniform(0, 6)))
            u = np.clip((s.yy - (g - 6)) / 7, 0, 1)
            ridge = np.sin(s.xx * 0.7)
            shade_band(s, m, u, ridge * 0.3, BARK, light=0.9 if side < 0 else 0.6, rim=False, base=0.15)
    # contreforts
    for side in (-1, 1):
        for k, (spread, h) in enumerate(((62, 105), (40, 135), (20, 80))):
            def fin(d, side=side, spread=spread, h=h):
                pts = [(cx + side * (half(g - h + h * j / 8) - 4), g - h + h * j / 8) for j in range(9)]
                pts.append((cx + side * (half(g) - 6), g + SINK))
                pts.append((cx + side * (half(g) - 4 + spread + 6), g + SINK))
                for j in range(14, -1, -1):
                    t = j / 14
                    y = g - h * (1 - t) ** 0.65
                    # le bord extérieur s'écarte en courbe concave puis plonge dans le sol
                    pts.append((cx + side * (half(y) - 4 + spread * t ** 2.0), y))
                d.polygon(pts, fill=255)
            m = s.mask(fin)
            u = s.across(m)
            ang = np.arctan2(s.xx - cx, s.yy + 160)
            ridge = np.sin(ang * 95 + k + side + 0.6 * np.sin(s.yy * 0.05))
            shade_band(s, m, u, ridge, BARK, light=(1.0 if side < 0 else 0.55) * (0.75 + 0.12 * k))
            edge_line(s, m, (20, 14, 10), g - 1)
    # le fût
    m = s.mask(lambda d: d.polygon([(cx - half(y), y) for y in range(top, g + 1, 6)] + [(cx - half(g), H), (cx + half(g), H)] +
                                   [(cx + half(y), y) for y in range(g, top - 1, -6)], fill=255))
    u = s.across(m)
    ang = np.arctan2(s.xx - cx, s.yy + 160)
    ridge = np.sin(ang * 95 + 0.6 * np.sin(s.yy * 0.05))
    shade_band(s, m, u, ridge, BARK)
    # nœuds et plaques d'écorce
    for (x, y, r) in ((cx - 10, 120, 4), (cx + 8, 60, 3), (cx - 4, 200, 3)):
        mm = s.mask(lambda d, x=x, y=y, r=r: d.ellipse((x - r, y - r * 1.4, x + r, y + r * 1.4), fill=255))
        s.paint(mm & s.a, 0.3 + 0.4 * np.clip(-(s.xx - x) / r, -1, 1), BARK[:4])
    # mousse côté ombre et lianes
    rr = random.Random(5)
    for i in range(260):
        x = cx + rr.uniform(-110, 110); y = g - rr.uniform(0, 110) ** 1.05
        if 0 <= int(y) < H and 0 <= int(x) < W and s.a[int(y), int(x)] and (x > cx - 10 or rr.random() < 0.3):
            s.rgb[int(y), int(x)] = MOSS[healthy][rr.randrange(3)]
    for k in range(3):
        x0 = cx + rr.uniform(-20, 20)
        mm = s.mask(lambda d, x0=x0, k=k: d.line([(x0 + 3 * math.sin(y * 0.04 + k), y) for y in range(0, 190 + k * 30, 3)], fill=255, width=2))
        s.paint(mm, np.full(mm.shape, 0.2), MOSS[healthy])
    contact(s, g, 26, 0.6)
    litter(s, g, 6, W - 6, healthy, 11)
    outline_open(s, SINK + 2)
    dust(s, healthy, 0.012, 1)
    return s


def fromager(healthy):
    """Fromager (kapokier) : fût gris et lisse, épines coniques, contreforts minces et immenses."""
    W, H = 260, 340
    s = Sprite(W, H)
    g = H - SINK
    cx = 130
    def half(y):
        t = y / g
        return 22 + 2 * math.sin(t * 5) + 18 * t ** 6
    for side in (-1, 1):                         # contreforts en planches, ondulés
        for k, (spread, h, wav) in enumerate(((100, 170, 5), (66, 140, 3), (32, 95, 2))):
            def fin(d, side=side, spread=spread, h=h, wav=wav):
                pts = [(cx + side * (half(g - h + h * j / 10) - 3), g - h + h * j / 10) for j in range(11)]
                pts.append((cx + side * (half(g) - 3), g + SINK)); pts.append((cx + side * (half(g) + spread + 4), g + SINK))
                for j in range(24, -1, -1):
                    t = j / 24
                    y = g - h * (1 - t) ** 0.55
                    x = cx + side * (half(y) - 3 + spread * t ** 1.6 + wav * math.sin(t * 9))
                    pts.append((x, y))
                d.polygon(pts, fill=255)
            m = s.mask(fin)
            u = s.across(m)
            ridge = 0.25 * np.sin(s.yy * 0.12 + s.xx * 0.05)
            shade_band(s, m, u, ridge, GREYBARK, light=(1.0 if side < 0 else 0.55) * (0.7 + 0.15 * k), base=0.08, span=0.6)
            edge_line(s, m, (24, 24, 22), g - 1)
            # l'arête du contrefort : une ligne claire (la planche est mince, elle accroche la lumière)
            e = m & ~np.roll(m, side, axis=1) & np.roll(m, -side, axis=1)
            s.rgb[e & (s.yy < g - 2)] = GREYBARK[5 if side < 0 else 3]
    m = s.mask(lambda d: d.polygon([(cx - half(y), y) for y in range(0, g + 1, 6)] + [(cx - half(g), H), (cx + half(g), H)] +
                                   [(cx + half(y), y) for y in range(g, -1, -6)], fill=255))
    u = s.across(m)
    shade_band(s, m, u, 0.2 * np.sin(s.yy * 0.08), GREYBARK, base=0.15, span=0.62)
    # épines coniques (le fromager en est couvert)
    rr = random.Random(3)
    for i in range(70):
        y = rr.uniform(5, g - 40); side = rr.choice((-1, 1))
        x = cx + side * rr.uniform(0, half(y) - 2)
        L = rr.uniform(3, 6)
        mm = s.mask(lambda d, x=x, y=y, L=L, side=side: d.polygon([(x - 2, y + 1.5), (x + 2, y + 1.5), (x + side * L * 0.6, y - L)], fill=255))
        s.paint(mm, np.full(mm.shape, 0.75 if side < 0 else 0.45), GREYBARK)
    # lichens clairs et mousse
    for i in range(200):
        x = rr.uniform(0, W); y = rr.uniform(0, g)
        if s.a[int(y), int(x)]:
            s.rgb[int(y), int(x)] = (MOSS[healthy][rr.randrange(3)] if rr.random() < 0.5 else (150, 156, 140) if healthy else (140, 136, 128))
    contact(s, g, 30, 0.6)
    litter(s, g, 4, W - 4, healthy, 12)
    outline_open(s, SINK + 2)
    dust(s, healthy, 0.01, 2)
    return s


def raphia(healthy):
    """Palmier raphia : tronc fibreux aux cicatrices en losanges, palmes en arc (balancent)."""
    W, H = 220, 240
    s = Sprite(W, H)
    g = H - SINK
    cx = 110
    crown = 70
    # tronc légèrement courbe
    def tx(y): return cx + 6 * math.sin((g - y) / (g - crown) * 1.2)
    m = s.mask(lambda d: d.polygon([(tx(y) - 6 - (2 if y > g - 14 else 0), y) for y in range(crown, g + 1, 4)] + [(cx - 8, H), (cx + 8, H)] +
                                   [(tx(y) + 6 + (2 if y > g - 14 else 0), y) for y in range(g, crown - 1, -4)], fill=255))
    u = s.across(m)
    ridge = np.sin(s.yy * 0.9 + (s.xx - cx) * 0.6) * np.sin(s.yy * 0.9 - (s.xx - cx) * 0.6)   # losanges
    shade_band(s, m, u, ridge, PALMBARK, base=0.12)
    # fibres qui pendent sous la couronne
    rr = random.Random(9)
    for i in range(40):
        x = tx(crown + 4) + rr.uniform(-8, 8); L = rr.uniform(6, 22)
        mm = s.mask(lambda d, x=x, L=L: d.line([(x, crown), (x + rr.uniform(-2, 2), crown + L)], fill=255))
        s.paint(mm, np.full(mm.shape, 0.3 + 0.4 * rr.random()), PALMBARK)
    # palmes : longues nervures arquées, folioles qui pendent
    pal = LEAF[healthy]
    for k in range(11):
        a = math.radians(-170 + k * 34 + rr.uniform(-8, 8)) if k < 11 else 0
        a = math.radians([200, 178, 160, 140, 118, 95, 72, 50, 30, 10, -12][k] + rr.uniform(-6, 6))
        L = rr.uniform(78, 100)
        pts = []
        for j in range(18):
            t = j / 17
            x = tx(crown) + math.cos(a) * L * t
            y = crown - math.sin(a) * L * t + (t ** 2) * L * 0.75
            pts.append((x, y))
        mm = s.mask(lambda d, pts=pts: d.line(pts, fill=255, width=1))
        s.paint(mm, np.full(mm.shape, 0.35), pal)
        for j in range(2, 18):
            px, py = pts[j]
            lf = 10 * math.sin(j / 17 * math.pi) + 2
            for sd in (-1, 1):
                mm = s.mask(lambda d, px=px, py=py, lf=lf, sd=sd: d.line([(px, py), (px + sd * 1.5, py + lf)], fill=255))
                s.paint(mm, np.full(mm.shape, 0.25 + 0.5 * (py < crown) + 0.15 * (sd < 0)), pal)
    contact(s, g, 14, 0.5)
    litter(s, g, cx - 30, cx + 30, healthy, 13)
    outline_open(s, SINK + 2)
    dust(s, healthy, 0.02, 3)
    return s


def arbre_mort(healthy):
    """Arbre mort : fût creux, branches cassées, champignons-consoles. Mort dans les deux états
    (la forêt guérie garde ses morts), mais couvert de mousse et de lierre une fois guérie."""
    W, H = 150, 240
    s = Sprite(W, H)
    g = H - SINK
    cx = 75
    def half(y): return 13 + 14 * (y / g) ** 7
    def draw_trunk(d):
        d.polygon([(cx - half(y) + 2 * math.sin(y * 0.03), y) for y in range(40, g + 1, 5)] + [(cx - half(g), H), (cx + half(g), H)] +
                  [(cx + half(y) + 2 * math.sin(y * 0.03), y) for y in range(g, 39, -5)], fill=255)
        # cime cassée en dents
        d.polygon([(cx - 13, 42), (cx - 8, 22), (cx - 3, 36), (cx + 3, 14), (cx + 8, 34), (cx + 13, 42)], fill=255)
    m = s.mask(draw_trunk)
    branches = [((cx - 10, 90), (cx - 52, 52), 5), ((cx - 40, 66), (cx - 60, 70), 2), ((cx + 10, 120), (cx + 50, 84), 4),
                ((cx + 38, 94), (cx + 46, 70), 2), ((cx - 11, 150), (cx - 34, 138), 3)]
    for (a, b, w) in branches:
        m |= s.mask(lambda d, a=a, b=b, w=w: d.line([a, b], fill=255, width=w))
    u = s.across(m)
    ridge = np.sin((s.xx - cx) * 0.9 + np.sin(s.yy * 0.07) * 2)
    shade_band(s, m, u, ridge, DEADBARK, base=0.14)
    # le trou noir dans le fût
    mm = s.mask(lambda d: d.ellipse((cx - 5, 160, cx + 4, 178), fill=255))
    s.rgb[mm] = (10, 8, 7)
    # champignons-consoles
    for (x, y, w) in ((cx + 12, 130, 9), (cx + 13, 140, 7), (cx - 15, 190, 8)):
        mm = s.mask(lambda d, x=x, y=y, w=w: d.chord((x - w // 2, y - 3, x + w // 2, y + 3), 180, 360, fill=255))
        s.paint(mm, 0.4 + 0.4 * np.clip(-(s.yy - y) / 3, -1, 1), [hexc("6e4a2a"), hexc("9a6a3a"), hexc("c89a5a")] if healthy else [hexc("55504a"), hexc("706a60"), hexc("8c8578")])
    rr = random.Random(4)
    if healthy:                                   # lierre et mousse
        for i in range(320):
            x = rr.uniform(0, W); y = rr.uniform(40, g)
            if s.a[int(y), int(x)] and rr.random() < 0.6:
                s.rgb[int(y), int(x)] = MOSS[True][rr.randrange(3)]
    contact(s, g, 16, 0.55)
    litter(s, g, cx - 40, cx + 40, healthy, 14)
    outline_open(s, SINK + 2)
    dust(s, healthy, 0.03, 4)
    return s


def figuier(healthy):
    """Figuier étrangleur : ses racines ont enserré un arbre qui a fini par pourrir. Il reste un
    treillis vivant autour d'un vide où l'on voit le fond de la forêt."""
    W, H = 200, 320
    s = Sprite(W, H)
    g = H - SINK
    cx = 100
    rr = random.Random(21)
    def half(y): return 40 + 30 * (y / g) ** 6
    m = np.zeros((H, W), bool)
    for k in range(11):                             # cordes qui errent et se croisent
        off = -1 + 2 * k / 10
        x_rel = off * 0.7
        pts = []
        for y in range(0, g + SINK + 1, 4):
            x_rel += rr.uniform(-0.09, 0.09)
            x_rel = max(-0.95, min(0.95, x_rel))
            pts.append((cx + half(min(y, g)) * x_rel, y))
        m |= s.mask(lambda d, pts=pts, w=rr.choice((3, 3, 4, 5)): d.line(pts, fill=255, width=w))
    for i in range(16):                               # ponts entre les cordes (elles fusionnent)
        y = rr.uniform(10, g - 30); hw = half(y)
        x0 = cx + hw * rr.uniform(-0.9, 0.2); x1 = x0 + hw * rr.uniform(0.3, 0.8)
        m |= s.mask(lambda d, y=y, x0=x0, x1=x1: d.line([(x0, y), ((x0 + x1) / 2, y + rr.uniform(-6, 6)), (x1, y + rr.uniform(-8, 8))], fill=255, width=3))
    # pieds : les racines s'écartent en arches
    for side in (-1, 1):
        for k in range(3):
            x0 = cx + side * (12 + k * 14)
            m |= s.mask(lambda d, x0=x0, side=side, k=k: d.line([(x0, g - 40 - k * 6), (x0 + side * (14 + k * 10), g - 12), (x0 + side * (24 + k * 14), g + SINK)], fill=255, width=4))
    u = np.clip((s.xx - (cx - 60)) / 120, 0, 1)
    ridge = np.sin(s.yy * 0.4 + s.xx * 0.3) * 0.4
    shade_band(s, m, u, ridge, [hexc(c) for c in ("1f1a14", "302820", "463a2d", "5f4f3c", "7a674f", "938064")], rim=False, base=0.18, span=0.6)
    for i in range(220):
        x = rr.uniform(0, W); y = rr.uniform(0, g)
        if s.a[int(y), int(x)] and rr.random() < (0.5 if healthy else 0.25):
            s.rgb[int(y), int(x)] = MOSS[healthy][rr.randrange(3)]
    contact(s, g, 20, 0.55)
    litter(s, g, cx - 60, cx + 60, healthy, 15)
    outline_open(s, SINK + 2)
    dust(s, healthy, 0.015, 5)
    return s


def termitiere(healthy):
    """Termitière cathédrale : un massif de terre à cheminées, cannelé par la pluie."""
    W, H = 70, 104
    s = Sprite(W, H)
    g = H - SINK
    spires = [(35, 6, 12), (22, 30, 9), (49, 22, 9), (14, 56, 7), (56, 50, 7)]
    m = np.zeros((H, W), bool)
    for (x, top, w) in spires:
        m |= s.mask(lambda d, x=x, top=top, w=w: d.polygon([(x - w, g + SINK), (x - w * 0.6, top + 18), (x - 2, top), (x + 2, top), (x + w * 0.6, top + 18), (x + w, g + SINK)], fill=255))
    m |= s.mask(lambda d: d.polygon([(2, H), (8, g - 22), (62, g - 26), (68, H)], fill=255))
    u = s.across(m)
    ridge = np.sin(s.xx * 1.1 + np.sin(s.yy * 0.15) * 1.5)
    shade_band(s, m, u, ridge * 0.6, TERM, base=0.15)
    rr = random.Random(2)
    for i in range(10):                                # trous de sortie
        x = rr.randint(10, 60); y = rr.randint(30, g - 4)
        if s.a[y, x]:
            s.rgb[y, x] = (16, 10, 8); s.rgb[y, x + 1] = (16, 10, 8)
    if healthy:
        for i in range(60):
            x = rr.uniform(0, W); y = rr.uniform(g - 30, g)
            if s.a[int(y), int(x)]:
                s.rgb[int(y), int(x)] = MOSS[True][rr.randrange(3)]
    contact(s, g, 14, 0.5)
    litter(s, g, 0, W, healthy, 16)
    outline_open(s, SINK + 2)
    dust(s, healthy, 0.03, 6)
    return s


def colocase(healthy):
    """Colocase : trois grandes feuilles en cœur au bout de longues tiges (balancent)."""
    W, H = 96, 76
    s = Sprite(W, H)
    pal = LEAF[healthy]
    for (bx, by, ang, sz) in ((26, 20, -0.6, 22), (68, 14, 0.5, 24), (48, 32, 0.05, 18)):
        m = s.mask(lambda d, bx=bx, by=by: d.line([(48, H - 1), (bx, by + 6)], fill=255, width=2))
        s.paint(m, np.full(m.shape, 0.35), pal)
        def leaf(d, bx=bx, by=by, ang=ang, sz=sz):
            pts = []
            for j in range(40):
                t = j / 39 * 2 * math.pi
                r = sz * (1 - math.sin(t)) * 0.55 + 1
                x = r * math.cos(t); y = -r * math.sin(t) * 0.75
                ca, sa = math.cos(ang), math.sin(ang)
                pts.append((bx + x * ca - y * sa, by + 6 + x * sa + y * ca))
            d.polygon(pts, fill=255)
        m = s.mask(leaf)
        val = 0.4 + 0.35 * np.clip(-((s.xx - bx) + (s.yy - by)) / sz, -1, 1)
        s.paint(m, val, pal)
        m2 = s.mask(lambda d, bx=bx, by=by, sz=sz, ang=ang: d.line([(bx, by + 6), (bx + math.sin(ang) * -sz * 0.4, by + 6 + sz * 0.8)], fill=255))
        s.rgb[m2 & m] = pal[min(len(pal) - 1, 4)]
    outline_open(s, 1)
    dust(s, healthy, 0.04, 7)
    return s


def grande_fougere(healthy):
    W, H = 80, 50
    s = Sprite(W, H)
    rr = random.Random(5)
    pal = LEAF[healthy]
    for k in range(9):
        a0 = math.radians(30 + k * 15 + rr.uniform(-5, 5))
        L = rr.uniform(38, 46) * (1.0 - 0.25 * abs(k - 4) / 4)
        side = -1 if a0 > math.pi / 2 else 1
        pts = [(40 + math.cos(a0) * L * t + side * t * t * 10, H - 1 - math.sin(a0) * L * t + t ** 3 * L * 0.35) for t in [j / 17 for j in range(18)]]
        m = s.mask(lambda d, pts=pts: d.line(pts, fill=255, width=1))
        s.paint(m, np.full(m.shape, 0.25), pal)
        for j in range(2, 18):
            px, py = pts[j]
            lf = (1 - j / 18) * 6 + 2
            for sd in (-1, 1):
                m = s.mask(lambda d, px=px, py=py, lf=lf, sd=sd: d.line([(px, py), (px + sd * lf * 0.6, py + lf * 0.55)], fill=255))
                s.paint(m, np.full(m.shape, 0.35 + 0.35 * (sd < 0) + 0.2 * (py < H * 0.4)), pal)
    outline_open(s, 1)
    dust(s, healthy, 0.03, 8)
    return s


def toile(healthy):
    """Toile d'araignée tendue en coin (à poser contre un tronc) ; dans la forêt malade, pleine
    de poussière, elle se voit mieux."""
    W, H = 44, 44
    s = Sprite(W, H)
    c = (0, 0)
    col = (170, 168, 160) if healthy else (196, 190, 176)
    rays = [math.radians(a) for a in (5, 22, 40, 58, 75, 88)]
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    for a in rays:
        d.line([(1, 1), (1 + math.cos(a) * 46, 1 + math.sin(a) * 46)], fill=255)
    for r in range(6, 46, 6):
        pts = [(1 + math.cos(a) * r * (0.95 + 0.05 * math.sin(r + a * 3)), 1 + math.sin(a) * r) for a in rays]
        d.line(pts, fill=255)
    m = np.array(im) > 127
    s.rgb[m] = col
    s.a |= m
    return s


def champignons_bleus(healthy):
    W, H = 30, 18
    s = Sprite(W, H)
    for x, h, r in ((7, 10, 5), (16, 13, 6), (24, 7, 4)):
        m = s.mask(lambda d, x=x, h=h: d.rectangle((x - 1, H - 1 - h, x + 1, H - 1), fill=255))
        s.paint(m, np.full(m.shape, 0.7), [hexc("8aa6b8"), hexc("c0dce8")])
        m = s.mask(lambda d, x=x, h=h, r=r: d.pieslice((x - r, H - 1 - h - r * 0.8, x + r, H - 1 - h + r * 0.8), 180, 360, fill=255))
        s.paint(m, 0.35 + 0.5 * np.clip(-(s.xx - x) / (2 * r) - (s.yy - (H - 1 - h)) / r, -1, 1),
                [hexc("1f5a7a"), hexc("2f88b0"), hexc("5ac0e0"), hexc("a8eeff")])
    outline_open(s, 1)
    return s


ALL = {"iroko": iroko, "fromager": fromager, "raphia": raphia, "arbre_mort": arbre_mort, "figuier": figuier,
       "termitiere": termitiere, "colocase": colocase, "grande_fougere": grande_fougere, "toile": toile,
       "champignons_bleus": champignons_bleus}

if __name__ == "__main__":
    names = sys.argv[2:] or list(ALL)
    for n in names:
        ALL[n](False).save(f"{OUT}/{n}.png")
        ALL[n](True).save(f"{OUT}/{n}_green.png")
    # Aperçu : tout sur une bande de sol, malade en haut, guéri en bas
    prev = Image.new("RGBA", (1400, 760), (40, 58, 52, 255))
    d = ImageDraw.Draw(prev)
    for row, suf in enumerate(("", "_green")):
        gy = 350 + row * 380
        d.rectangle((0, gy, 1400, gy + 30), fill=(70, 56, 40, 255))
        x = 6
        for n in names:
            im = Image.open(f"{OUT}/{n}{suf}.png")
            sink = SINK if n in ("iroko", "fromager", "raphia", "arbre_mort", "figuier", "termitiere") else 0
            prev.alpha_composite(im, (x, gy - im.height + sink))
            d.rectangle((0, gy, 1400, gy + 30), fill=None)
            x += im.width + 4
        # la terre recouvre le pied
        over = Image.new("RGBA", (1400, 30), (70, 56, 40, 255))
        prev.alpha_composite(over, (0, gy))
    prev.save(f"{OUT}/decor2_prev.png")
