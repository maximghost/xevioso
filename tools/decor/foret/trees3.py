"""Arbres de la forêt des irokos, troisième génération : des volumes, plus des silhouettes.

Chaque forme est éclairée comme un vrai volume : on calcule un relief (distance au bord,
plafonnée selon l'épaisseur de la pièce : un contrefort est une planche mince, un fût est un
cylindre), on y creuse l'écorce (fissures, côtes, cicatrices), puis on éclaire ce relief
(lumière en haut à gauche) et on tramé dans une palette courte. Les silhouettes sont
asymétriques, en courbes continues (pas de segments raides).

  fromager  kapokier : fût gris, légèrement penché, épines coniques ; contreforts en planches
            minces et sinueuses qui courent loin, inégaux des deux côtés, un de face
  iroko     le géant sacré : fût brun-gris profondément fissuré, contreforts épais arrondis,
            racines qui serpentent au sol, un pied qui s'évase
  raphia    palmier raphia : tronc couvert de bases de palmes et de fibres, palmes immenses en
            arc qui retombent souplement, folioles qui pendent, palmes sèches le long du tronc

Utilisation : python3 trees3.py DOSSIER_SORTIE [noms…]   (écrit <nom>.png et <nom>_green.png)
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dlib import Sprite, OUTLINE, hexc, MOSS

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
SINK = 8
LIGHT = np.array([-0.62, -0.55, 0.56]); LIGHT /= np.linalg.norm(LIGHT)

GREYBARK = [hexc(c) for c in ("161615", "24241f", "34332e", "47453e", "5b5850", "716d62", "888376", "a19b8c")]
IROKO = [hexc(c) for c in ("120d0a", "1e1611", "2b2019", "3a2c22", "4b3a2d", "5d4939", "715a47", "866d58")]
PALM = [hexc(c) for c in ("17110c", "251b13", "35271c", "473526", "5b4532", "715740")]
DRYFROND = [hexc(c) for c in ("221810", "382a1b", "4f3b26", "654c31", "7a5d3d")]
LEAF = {True: [hexc(c) for c in ("0f2416", "17361f", "21492a", "2e6036", "3f7a43", "5a9652", "7cb068")],
        False: [hexc(c) for c in ("252421", "33312d", "423f3a", "54504a", "68635b", "7e786e", "958f83")]}
LITTER = {True: [hexc(c) for c in ("2b5229", "3c6e33", "58904a", "6b4a22", "8a5a2a")],
          False: [hexc(c) for c in ("4a4640", "5a554d", "6e685e", "6a645a", "7e776b")]}


def fbm(h, w, seed, cells):
    r = np.random.default_rng(seed)
    out = np.zeros((h, w)); amp, tot = 1.0, 0.0
    for c in cells:
        g = r.random((h // c + 3, w // c + 3))
        out += amp * ndimage.zoom(g, c, order=3)[:h, :w]; tot += amp; amp *= 0.5
    out /= tot
    return (out - out.min()) / (np.ptp(out) + 1e-9)


def poly_mask(s, pts):
    return s.mask(lambda d: d.polygon([(float(x), float(y)) for x, y in pts], fill=255))


def relief(m, cap, soft=1.0):
    """Relief d'une pièce : bombé au bord, plat au-delà de « cap » px (planche) ou bombé
    jusqu'au milieu (cap grand : cylindre)."""
    d = ndimage.distance_transform_edt(m)
    t = np.clip(d / cap, 0, 1)
    return np.sqrt(1 - (1 - t) ** 2) * cap * soft


def lit(hgt, m, ambient=0.18):
    gy, gx = np.gradient(ndimage.gaussian_filter(hgt, 0.7))
    n = np.stack([-gx, -gy, np.ones_like(hgt)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    v = np.clip((n @ LIGHT), 0, 1)
    return np.where(m, ambient + (1 - ambient) * v, 0)


def paint(s, m, val, pal):
    s.paint(m, np.clip(val, 0, 0.999), pal)


def outline(s, open_rows):
    a = s.a
    o = np.zeros_like(a)
    o[1:] |= a[:-1]; o[:-1] |= a[1:]; o[:, 1:] |= a[:, :-1]; o[:, :-1] |= a[:, 1:]
    o &= ~a
    o[s.h - open_rows:] = False
    s.rgb[o] = OUTLINE; s.a |= o


def contact(s, g, depth, k):
    f = np.clip((s.yy - (g - depth)) / depth, 0, 1) * k
    sel = s.a & (f > 0)
    s.rgb[sel] = (s.rgb[sel] * (1 - f[sel, None])).astype(np.uint8)


def litter(s, g, x0, x1, healthy, seed, density=1.0):
    r = random.Random(seed); pal = LITTER[healthy]
    for _ in range(int((x1 - x0) * density)):
        x = int(r.uniform(x0, x1)); y = g - r.choice((0, 0, 0, 1, 1, 2))
        c = pal[r.randrange(len(pal))]
        for dx in range(r.choice((1, 2, 2, 3))):
            if 0 <= x + dx < s.w: s.rgb[y, x + dx] = c; s.a[y, x + dx] = True
    for _ in range(int((x1 - x0) / 9 * density)):
        x = int(r.uniform(x0, x1)); h = r.randint(2, 6); c = pal[r.randrange(3)]
        for j in range(h):
            xi = x + int(round(math.sin(j * 0.6 + x) * (j / h) * 1.5))
            if 0 <= xi < s.w: s.rgb[g - 1 - j, xi] = c; s.a[g - 1 - j, xi] = True


def mossify(s, m, healthy, seed, side_bias, amount):
    """Mousse : plutôt côté ombre (droite) et vers le pied, en plaques (pas en poussière)."""
    n = fbm(s.h, s.w, seed, (12, 6, 3))
    want = m & (n > 1 - amount) & ((s.xx - s.w / 2) * side_bias > -10)
    pal = MOSS[healthy]
    s.rgb[want] = np.array(pal)[np.clip(((n[want] - (1 - amount)) / amount * 3).astype(int), 0, 2)]


def curve(p0, p1, p2, p3, n=40):
    t = np.linspace(0, 1, n)[:, None]
    P = [np.array(p, float) for p in (p0, p1, p2, p3)]
    return ((1 - t) ** 3) * P[0] + 3 * (1 - t) ** 2 * t * P[1] + 3 * (1 - t) * t * t * P[2] + t ** 3 * P[3]


# =========================================================================================
def fromager(healthy):
    W, H = 260, 340
    s = Sprite(W, H)
    g = H - SINK
    def cx(y): return 128 + 7 * ((g - y) / g) ** 1.6          # le fût penche un peu vers la droite en montant
    def half(y):
        t = y / g
        return 19 + 1.5 * math.sin(t * 6.3) + 26 * t ** 7
    tex = fbm(H, W, 4, (16, 8, 4))
    # --- contreforts : (côté, portée, hauteur de départ, ondulation, recul [plus = derrière])
    fins = [(-1, 112, 168, 6, 2), (1, 74, 150, 4, 2), (-1, 52, 110, 3, 1), (1, 104, 96, 5, 1), (0, 26, 132, 0, 0)]
    def fin_pts(side, spread, h, wav):
        y0 = g - h
        if side == 0:                                        # le contrefort de face : une arête qui s'élargit
            top = curve((cx(y0) - 3, y0), (cx(y0) - 6, y0 + h * 0.5), (cx(g) - 16, g - 18), (cx(g) - 22, g + SINK))
            bot = curve((cx(g) + 18, g + SINK), (cx(g) + 12, g - 20), (cx(y0) + 8, y0 + h * 0.5), (cx(y0) + 3, y0))
            return list(map(tuple, top)) + list(map(tuple, bot))
        root_x = cx(y0) + side * (half(y0) - 4)
        edge = []
        for j in range(30, -1, -1):
            t = j / 30
            y = g - h * (1 - t) ** 2.1 + 3 * math.sin(t * 6.0 + side) * t * (1 - t)
            x = cx(y) + side * (half(y) - 3 + spread * t ** 1.05 + wav * math.sin(t * 8.5 + side) * t)
            edge.append((x, y))
        inner = [(cx(y0 + h * j / 10) + side * (half(y0 + h * j / 10) - 6), y0 + h * j / 10) for j in range(11)]
        return inner + [(cx(g) + side * (half(g) - 6), g + SINK), (cx(g) + side * (half(g) + spread + 6), g + SINK)] + edge
    def paint_fin(spec):
        side, spread, h, wav, back = spec
        m = poly_mask(s, fin_pts(side, spread, h, wav))
        # la planche : mince (relief plafonné à 3 px), sa face ondule doucement
        und = 1.6 * np.sin((s.xx * (0.09 if side else 0.3)) + tex * 4)
        hg = relief(m, 3.0) + np.where(m, und, 0)
        val = lit(hg, m, 0.16) * (0.82 - 0.12 * back) + 0.08 * (tex - 0.5)
        if side == 1: val *= 0.78                            # côté droit : à l'ombre du fût
        paint(s, m, val, GREYBARK)
        # le dessus de la planche accroche la lumière (une arête claire), l'ombre portée sous le fût
        top = m & ~np.roll(m, 1, 0)
        s.rgb[top & (s.yy < g - 2)] = GREYBARK[6 if side <= 0 else 4]
        return m
    for spec in sorted(fins[:4], key=lambda f: -f[4]):
        paint_fin(spec)
    # --- le fût : cylindre, écorce lisse à fines bandes horizontales
    trunk = [(cx(y) - half(y), y) for y in range(0, g + 1, 4)] + [(cx(g) - half(g), H), (cx(g) + half(g), H)] + \
            [(cx(y) + half(y), y) for y in range(g, -1, -4)]
    m = poly_mask(s, trunk)
    hg = relief(m, 26.0) - np.where(m, 1.2 * (np.sin(s.yy * 0.55 + tex * 6) > 0.85) + 2.0 * (tex > 0.78), 0)
    val = lit(hg, m, 0.2) + 0.07 * (tex - 0.5)
    paint(s, m, val, GREYBARK)
    # ombre portée des contreforts sur le fût (du côté opposé à la lumière)
    shadow = m & (s.yy > g - 150) & (s.xx > cx(g) + 6)
    s.rgb[shadow] = (s.rgb[shadow] * 0.8).astype(np.uint8)
    paint_fin(fins[4])
    # --- épines coniques, éclairées (pointe vers le haut)
    rr = random.Random(3)
    for _ in range(85):
        y = rr.uniform(6, g - 30)
        u = rr.uniform(-0.92, 0.92)
        x = cx(y) + u * half(y)
        L = rr.uniform(3, 7) * (1.0 - 0.5 * abs(u))
        b = rr.uniform(1.6, 2.6)
        mm = poly_mask(s, [(x - b, y + 1.2), (x + b, y + 1.2), (x + u * 1.5, y - L)])
        paint(s, mm, np.where(s.xx < x, 0.82, 0.42) - 0.15 * abs(u), GREYBARK)
        s.rgb[min(int(y + 2), H - 1), int(x)] = GREYBARK[1]
    # lichens en plaques, mousse au pied
    lic = m & (fbm(H, W, 9, (6, 3)) > 0.88)
    s.rgb[lic] = (118, 124, 108) if healthy else (112, 109, 100)
    mossify(s, s.a & (s.yy > g - 70), healthy, 21, 1, 0.22)
    contact(s, g, 34, 0.62)
    litter(s, g, 4, W - 4, healthy, 12, 1.2)
    outline(s, SINK + 2)
    return s


def iroko(healthy):
    W, H = 240, 330
    s = Sprite(W, H)
    g = H - SINK
    def cx(y): return 118 - 5 * math.sin((g - y) / g * 2.2)   # un fût qui ondule à peine
    def half(y):
        t = y / g
        return 24 + 2.5 * math.sin(t * 7.0) + 30 * t ** 9
    tex = fbm(H, W, 6, (24, 12, 6))
    fiss = fbm(H, W, 8, (3,))
    # racines qui serpentent au sol (derrière)
    rr = random.Random(7)
    for side, L, th in ((-1, 104, 6), (-1, 70, 4), (1, 92, 5), (1, 58, 4), (1, 30, 3)):
        x0 = cx(g) + side * (half(g) - 4)
        pts_t, pts_b = [], []
        ph = rr.uniform(0, 6)
        for j in range(24):
            t = j / 23
            x = x0 + side * L * t
            y = g - 1 + 1.6 * math.sin(t * 7 + ph) * t
            w = th * (1 - t) ** 1.2 + 0.8
            pts_t.append((x, y - w)); pts_b.append((x, y + 1))
        m = poly_mask(s, pts_t + pts_b[::-1])
        paint(s, m, lit(relief(m, 3.0), m, 0.15) * (0.9 if side < 0 else 0.65), IROKO)
    # contreforts épais et arrondis (moins hauts que ceux du fromager)
    for side, spread, h, back in ((1, 46, 120, 2), (-1, 62, 140, 1), (1, 30, 90, 1), (-1, 26, 70, 0)):
        y0 = g - h
        edge = []
        for j in range(26, -1, -1):
            t = j / 26
            y = g - h * (1 - t) ** 1.8
            edge.append((cx(y) + side * (half(y) - 4 + spread * t ** 1.2 + 2 * math.sin(t * 7) * t), y))
        inner = [(cx(y0 + h * j / 10) + side * (half(y0 + h * j / 10) - 10), y0 + h * j / 10) for j in range(11)]
        m = poly_mask(s, inner + [(cx(g) + side * (half(g) - 10), H), (cx(g) + side * (half(g) + spread + 4), H)] + edge)
        hg = relief(m, 9.0) - np.where(m, 2.5 * (np.abs(np.sin((s.xx - cx(g)) * 0.35 + tex * 9)) < 0.2), 0)
        val = lit(hg, m, 0.16) * (0.9 - 0.1 * back) * (1 if side < 0 else 0.8)
        paint(s, m, val, IROKO)
    # le fût : écorce fissurée en longues plaques verticales
    trunk = [(cx(y) - half(y), y) for y in range(0, g + 1, 4)] + [(cx(g) - half(g), H), (cx(g) + half(g), H)] + \
            [(cx(y) + half(y), y) for y in range(g, -1, -4)]
    m = poly_mask(s, trunk)
    xs = (s.xx - np.array([cx(y) for y in range(H)])[:, None]) / np.maximum(np.array([half(y) for y in range(H)])[:, None], 1)
    plates = np.abs(np.sin(xs * 9.0 + 2.2 * tex + 0.8 * np.sin(s.yy * 0.035)))      # fissures verticales
    breaks = np.abs(np.sin(s.yy * 0.21 + fiss * 7 + xs * 3))                         # cassures entre plaques
    hg = relief(m, 30.0) - np.where(m, 3.5 * (plates < 0.22) + 1.5 * (breaks < 0.08), 0) + np.where(m, 1.2 * fiss, 0)
    val = lit(hg, m, 0.17) + 0.06 * (tex - 0.5)
    paint(s, m, val, IROKO)
    # quelques nœuds, une coulée de sève sombre
    for (x, y, r) in ((cx(120) - 9, 120, 4), (cx(64) + 10, 64, 3), (cx(214) - 2, 214, 3.5)):
        mm = s.mask(lambda d, x=x, y=y, r=r: d.ellipse((x - r, y - r * 1.5, x + r, y + r * 1.5), fill=255)) & m
        paint(s, mm, 0.15 + 0.5 * np.clip((x - s.xx) / r, 0, 1), IROKO)
    mossify(s, s.a & (s.yy > g - 120), healthy, 31, 1, 0.26)
    # lianes qui montent le long du fût
    for k, x0 in enumerate((cx(0) - 12, cx(0) + 15)):
        mm = s.mask(lambda d, x0=x0, k=k: d.line([(x0 + 4 * math.sin(y * 0.045 + k * 2), y) for y in range(0, 200 + 40 * k, 2)], fill=255, width=2))
        paint(s, mm, np.where(s.xx < x0, 0.55, 0.3), LEAF[healthy])
    contact(s, g, 28, 0.6)
    litter(s, g, 4, W - 4, healthy, 11, 1.2)
    outline(s, SINK + 2)
    return s


def raphia(healthy):
    W, H = 240, 250
    s = Sprite(W, H)
    g = H - SINK
    crown = 78
    def tx(y): return 116 + 7 * math.sin((g - y) / (g - crown) * 1.3)
    rr = random.Random(9)
    pal = LEAF[healthy]
    # palmes sèches qui pendent le long du tronc (derrière)
    for k in range(5):
        a = math.radians(rr.choice((-1, 1)) * rr.uniform(8, 25))
        x0, y0 = tx(crown + 4), crown + 6
        L = rr.uniform(50, 80)
        P = curve((x0, y0), (x0 + math.sin(a) * L * 0.4, y0 + L * 0.3), (x0 + math.sin(a) * L * 0.8, y0 + L * 0.7), (x0 + math.sin(a) * L * 0.9, y0 + L))
        for (px, py) in P[2:]:
            for sd in (-1, 1):
                ln = rr.uniform(4, 8)
                mm = s.mask(lambda d, px=px, py=py, ln=ln, sd=sd: d.line([(px, py), (px + sd * 2.5, py + ln)], fill=255))
                paint(s, mm, np.full(mm.shape, 0.35 + 0.35 * (sd < 0) + 0.1 * rr.random()), DRYFROND)
        mm = s.mask(lambda d, P=P: d.line([tuple(p) for p in P], fill=255, width=2))
        paint(s, mm, np.full(mm.shape, 0.5), DRYFROND)
    # le tronc : bases de palmes imbriquées en écailles, fibres
    trunk = [(tx(y) - 8 - 3 * (y > g - 16) * (y - g + 16) / 16, y) for y in range(crown, g + 1, 3)] + [(tx(g) - 12, H), (tx(g) + 12, H)] + \
            [(tx(y) + 8 + 3 * (y > g - 16) * (y - g + 16) / 16, y) for y in range(g, crown - 1, -3)]
    m = poly_mask(s, trunk)
    xs = s.xx - np.array([tx(y) for y in range(H)])[:, None]
    scale = ((s.yy + np.abs(xs) * 0.9) % 9) / 9.0                  # écailles en chevrons
    hg = relief(m, 7.0) + np.where(m, 2.4 * scale, 0)
    paint(s, m, lit(hg, m, 0.15) * 0.95, PALM)
    for _ in range(50):                                              # fibres qui pendent
        x = tx(crown + 6) + rr.uniform(-10, 10); y0 = crown + rr.uniform(0, 30); L = rr.uniform(6, 26)
        mm = s.mask(lambda d, x=x, y0=y0, L=L: d.line([(x, y0), (x + rr.uniform(-2, 2), y0 + L)], fill=255))
        paint(s, mm, np.full(mm.shape, 0.25 + 0.5 * rr.random()), PALM)
    outline(s, SINK + 2)
    # les palmes vertes : rachis en arc, folioles longues et souples qui retombent
    fronds = [(196, 104), (176, 110), (156, 100), (136, 92), (116, 86), (98, 80), (80, 88), (60, 96), (40, 104), (20, 108), (-6, 98), (108, 64), (84, 66)]
    order = sorted(range(len(fronds)), key=lambda i: -abs(fronds[i][0] - 90))     # les plus couchées d'abord
    for i in order:
        deg, L = fronds[i]
        a = math.radians(deg + rr.uniform(-5, 5)); L *= rr.uniform(0.9, 1.05)
        x0, y0 = tx(crown), crown
        up = math.sin(a)
        c1 = (x0 + math.cos(a) * L * 0.3, y0 - (0.35 + 0.45 * up) * L)
        c2 = (x0 + math.cos(a) * L * 0.8, y0 - (0.25 + 0.4 * up) * L)
        end = (x0 + math.cos(a) * L * 1.05, y0 + L * (0.25 - 0.25 * up))
        P = curve((x0, y0), c1, c2, end, 48)
        front = abs(deg - 90) < 40
        # la palme : une plume pleine, folioles en dents sur les bords, qui pendent du côté bas
        up_e, lo_e = [], []
        n_ = len(P)
        for j in range(n_):
            t = j / (n_ - 1)
            px, py = P[j]
            k2 = min(j + 1, n_ - 1); k1 = max(j - 1, 0)
            dx, dy = P[k2] - P[k1]
            nl = math.hypot(dx, dy) or 1
            nx, ny = -dy / nl, dx / nl
            if ny > 0: nx, ny = -nx, -ny                      # (nx, ny) : vers le haut
            w = (3 + 15 * math.sin(math.pi * min(1.0, t * 1.08) ** 0.8)) * (1 - 0.25 * t)
            tooth = 1.0 if j % 3 == 0 else 0.62               # pointes des folioles
            up_e.append((px + nx * w * 0.45 * tooth, py + ny * w * 0.45 * tooth - 0.0))
            lo_e.append((px - nx * w * 0.6 * tooth, py - ny * w * 0.6 * tooth + w * 0.55 * tooth))
        m = poly_mask(s, up_e + lo_e[::-1])
        # éclairage : dessus clair, dessous sombre, stries des folioles
        along = np.zeros((H, W))
        for j, (px, py) in enumerate(P):
            pass
        dist_up = ndimage.distance_transform_edt(m)
        stri = np.sin((s.xx * math.cos(a) - s.yy * math.sin(a)) * 1.6 + s.yy * 0.4)
        top_mask = m & ~np.roll(m, 2, 0)
        v = 0.34 + 0.18 * (stri > 0.3) + (0.1 if front else 0) + 0.25 * np.clip(1 - dist_up / 3.0, 0, 1) * top_mask.astype(float)
        under = m & ~np.roll(m, -2, 0)
        v = np.where(under, v - 0.18, v)
        paint(s, m, v + 0.05 * rr.random(), pal)
        # le rachis, clair
        mm = s.mask(lambda d, P=P: d.line([tuple(p) for p in P], fill=255, width=1))
        paint(s, mm, np.full(mm.shape, 0.78), pal)
        # le bord : un trait sombre sous la palme (la détache de celle de derrière)
        e = m & ~np.roll(m, -1, 0)
        s.rgb[e] = np.array(pal[0])
    contact(s, g, 16, 0.5)
    litter(s, g, 80, 160, healthy, 13, 1.0)
    return s


ALL = {"fromager": fromager, "iroko": iroko, "raphia": raphia}

if __name__ == "__main__":
    names = sys.argv[2:] or list(ALL)
    for n in names:
        for healthy, suf in ((False, ""), (True, "_green")):
            sp = ALL[n](healthy)
            im = np.zeros((sp.h, sp.w, 4), np.uint8); im[..., :3] = sp.rgb; im[..., 3] = sp.a * 255
            Image.fromarray(im, "RGBA").save(os.path.join(OUT, n + suf + ".png"))
    print("arbres :", ", ".join(names))
