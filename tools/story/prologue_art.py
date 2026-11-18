"""Décors peints du prologue de Xɛvioso : le village du sanctuaire, en couches à parallaxe.

Deux éclairages, peints séparément (la lumière change tout : liserés, ombres, couleurs) :
  « or »   le soir d'avant le vol : soleil bas derrière le sanctuaire, à droite ; liserés d'or,
           longues ombres vers la gauche, brume chaude dans les lointains, champs de mil mûrs
  « nuit » nuit d'orage sec : ciel lourd, lumière froide et faible, rien n'accroche la lumière
           (les éclairs sont ajoutés par le jeu, en flash)

Couches (largeur = 640 + profondeur × 960 : la caméra parcourt 960 px du village) :
  ciel 736 · collines 928 · arbres 1216 · village 1600 · premier plan 2080, toutes de 360 de haut.
Le sol du village est à y = 286 (le bandeau du conteur couvre le bas de l'écran).

Utilisation : python3 prologue_art.py DOSSIER_SORTIE
"""
import math, os, random, sys
import numpy as np
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from painter import (Canvas, C, mix, smooth, fbm, relief, light, edge_toward, shadow_cast, save,
                     stroke, bezier)

H = 360
PAN = 960
GROUND = 286
SANCT_X = 1390          # centre du sanctuaire, dans la couche du village


def width(depth): return int(640 + depth * PAN)


LIGHTS = {
    "or": dict(
        sky_top=C("1c1838"), sky_mid=C("6b3a5a"), sky_low=C("e07a48"), horizon=C("ffc56e"),
        sun=C("fff2c8"), sun_x=600, sun_y=196, haze=C("e8946a"), rim=C("ffd27e"),
        ldir=(0.9, -0.3, 0.32), ambient=0.22, shade=C("2a1830"), cool=C("4a3a6a"),
        laterite=C("b4572e"), grass=C("8a7a36"), millet=C("d8a84a"), mud=C("b8774a"),
        thatch=C("c99a4a"), wood=C("5a3420"), leaf=C("4a5a2a"), cloud=C("f6a070")),
    "nuit": dict(
        sky_top=C("07070e"), sky_mid=C("151527"), sky_low=C("252438"), horizon=C("34324a"),
        sun=None, sun_x=0, sun_y=0, haze=C("2a2a40"), rim=None,
        ldir=(-0.2, -0.6, 0.6), ambient=0.42, shade=C("0a0a14"), cool=C("1a1a30"),
        laterite=C("3e2a2c"), grass=C("2c2c2c"), millet=C("4a4236"), mud=C("43383a"),
        thatch=C("4a4234"), wood=C("201a1c"), leaf=C("1e2422"), cloud=C("2a2a3e")),
}


def shaded(cv, m, base, L, cap, tex=None, rim_w=1, shadow_side=0.0, gain=1.0):
    """Peint un volume : relief (plafonné à « cap »), lumière, texture, liseré côté lumière."""
    hg = relief(m, cap)
    if tex is not None:
        hg = hg + tex
    v = light(hg, m, L["ldir"], L["ambient"]) * gain
    lit_col = base[None, None, :] * (0.75 + 0.55 * v[..., None])
    if L["rim"] is not None:
        lit_col = mix(lit_col, L["rim"][None, None, :] * np.ones_like(lit_col), 0.18 * v)
    dark = mix(base * 0.42, L["cool"], 0.38)
    col = mix(dark[None, None, :] * np.ones_like(lit_col), lit_col, smooth(v, 0.28, 0.62))
    cv.fill(m, col)
    if L["rim"] is not None and rim_w:
        e = edge_toward(m, 1, 0, rim_w) | edge_toward(m, 0, -1, 1)
        cv.fill(e & m, mix(base, L["rim"], 0.75), 0.9)


def haze(cv, m, L, amount):
    cv.fill(m, L["haze"], amount)


# ================================================================ ciel
def sky(L, seed=1):
    W = width(0.1)
    cv = Canvas(W, H)
    y = cv.yy / H
    col = np.zeros((H, W, 3))
    # dégradé : haut → milieu → bas → horizon
    stops = [(0.0, L["sky_top"]), (0.38, L["sky_mid"]), (0.62, L["sky_low"]), (0.72, L["horizon"]), (1.0, L["horizon"])]
    for (y0, c0), (y1, c1) in zip(stops, stops[1:]):
        sel = (y >= y0) & (y <= y1)
        t = (y - y0) / (y1 - y0)
        col[sel] = mix(c0, c1, t)[sel] if np.ndim(t) else col[sel]
    cv.fill(np.ones((H, W), bool), col)
    if L["sun"] is not None:
        d = np.sqrt((cv.xx - L["sun_x"]) ** 2 + ((cv.yy - L["sun_y"]) * 1.15) ** 2)
        cv.fill(np.ones((H, W), bool), L["horizon"], np.clip(1 - d / 230, 0, 1) ** 2 * 0.7)
        cv.fill(np.ones((H, W), bool), L["sun"], np.clip(1 - d / 70, 0, 1) ** 2.2 * 0.9)
        cv.fill(d < 13, L["sun"])
    # nuages en strates : bruit étiré à l'horizontale, bords nets, dessous éclairé par le soleil bas
    from scipy import ndimage as _nd
    small = fbm(H, W // 5 + 4, seed, (40, 20, 10, 5))
    n = _nd.zoom(small, (1, 5), order=1)[:, :W]
    fine = fbm(H, W, seed + 7, (12, 6, 3))
    for i, (yc, thick, thr, amt) in enumerate(((58, 26, 0.56, 0.95), (118, 18, 0.6, 0.9), (166, 12, 0.62, 0.8))):
        # des bancs de nuages séparés, d'épaisseur variable (pas des rubans continus)
        clusters = smooth(fbm(H, W, seed + 20 + i, (180, 90, 45)), 0.4, 0.62)
        vary = 0.55 + 0.9 * fbm(H, W, seed + 30 + i, (120, 60))
        band = np.exp(-((cv.yy - yc - 14 * (n - 0.5)) / (thick * vary)) ** 2)
        k = smooth(n * 0.7 + fine * 0.3 + band * 0.55, thr + 0.18, thr + 0.24) * amt * clusters
        if L["sun"] is not None:
            top = np.clip((k - np.roll(k, 2, 0)), 0, 1)            # dessus : ombre violette
            under = np.clip((k - np.roll(k, -2, 0)), 0, 1)         # dessous : liseré de feu
            dsun = np.sqrt((cv.xx - L["sun_x"]) ** 2 + ((cv.yy - L["sun_y"]) * 1.6) ** 2)
            near = np.clip(1 - dsun / 330, 0, 1)
            body = mix(mix(L["sky_mid"], L["cool"], 0.35), L["cloud"], 0.25 + 0.55 * near)
            cv.fill(k > 0.02, body, k)
            cv.fill(k > 0.25, mix(L["cloud"], L["sun"], near), np.clip(under * 2.2, 0, 1) * (0.35 + 0.55 * near))
            cv.fill(k > 0.02, L["cool"] * 0.8, np.clip(top * 2, 0, 1) * 0.45)
        else:
            body = mix(L["sky_low"], L["sky_top"], 0.4)
            cv.fill(k > 0.02, body, k)
            cv.fill(k > 0.02, L["sky_top"] * 0.6, np.clip((k - np.roll(k, -2, 0)) * 2, 0, 1) * 0.6)
    # quelques oiseaux rentrant (soir seulement)
    if L["sun"] is not None:
        r = random.Random(4)
        for _ in range(9):
            x, yb = r.uniform(220, 520), r.uniform(150, 210)
            for dx, dy in ((-2, 0), (-1, -1), (0, 0), (1, -1), (2, 0)):
                cv.rgb[int(yb + dy), int(x + dx)] = L["shade"]
    cv.a[:] = 1
    return cv


# ================================================================ collines
def hills(L, seed=2):
    W = width(0.3)
    cv = Canvas(W, H)
    x = np.arange(W)
    for k, (base_y, amp, freq, aerial) in enumerate(((214, 24, 0.006, 0.82), (232, 20, 0.011, 0.66), (250, 15, 0.017, 0.5))):
        r = np.random.default_rng(seed + k)
        prof = np.zeros(W)
        for f, a in ((freq, amp), (freq * 2.3, amp * 0.4), (freq * 5.1, amp * 0.15)):
            prof += a * np.sin(x * f + r.uniform(0, 6.28))
        top = base_y - prof
        m = cv.yy >= top[None, :]
        hg = (cv.yy - top[None, :]) * 0 + fbm(H, W, seed + 10 + k, (40, 20, 10)) * 6
        # relief des pentes : l'inclinaison du profil donne la lumière (pentes face au soleil)
        slope = np.gradient(top)[None, :] * np.ones((H, 1))
        base = mix(mix(L["laterite"] * 0.7, L["cool"], 0.35), L["leaf"], 0.2 + 0.1 * k)
        v = np.clip(0.5 - slope * 0.25 + 0.15 * (hg / 6 - 0.5), 0, 1)
        col = mix(mix(L["shade"], base, 0.5)[None, None, :] * np.ones((H, W, 3)), base[None, None, :] * 1.1, v[..., None].squeeze(-1)) if False else \
            (mix(L["shade"], base, 0.5)[None, None, :] * (1 - v[..., None]) + base[None, None, :] * 1.1 * v[..., None])
        cv.fill(m, col)
        cv.fill(m, mix(L["haze"], L["sky_low"], 0.4), aerial)
        if L["rim"] is not None:
            e = edge_toward(m, 0, -1, 1)
            cv.fill(e, mix(L["haze"], L["rim"], 0.6), 0.7)
    return cv


# ================================================================ arbres lointains
def baobab(cv, x, base, s, m_out):
    """Silhouette de baobab : tronc en bouteille, branches tordues comme des racines."""
    trunk = []
    for j in range(31):
        t = j / 30
        y = base - t * 70 * s
        w = (15 + 10 * math.sin(t * 2.6) - 6 * t) * s
        trunk.append((x - w + 2 * math.sin(t * 5) * s, y))
    right = [(2 * x - px + 1.5 * s * math.sin(i), py) for i, (px, py) in enumerate(trunk)]
    m = cv.poly(trunk + right[::-1])
    top = base - 70 * s
    r = random.Random(int(x))
    for k in range(9):
        a = math.radians(-160 + k * 18 + r.uniform(-6, 6))
        L = r.uniform(22, 42) * s
        ex, ey = x + math.cos(a) * L, top + math.sin(a) * L * 0.75
        mx_, my_ = x + math.cos(a) * L * 0.5 + r.uniform(-6, 6) * s, top + math.sin(a) * L * 0.25
        m |= stroke(cv, [(x + math.cos(a) * 6 * s, top + 4 * s), (mx_, my_), (ex, ey)], 4.5 * s, 1.0)
        for kk in range(2):
            b = a + r.uniform(-0.7, 0.7)
            m |= stroke(cv, [(ex, ey), (ex + math.cos(b) * 10 * s, ey + math.sin(b) * 8 * s - 4 * s)], 1.6 * s, 0.6)
    m_out |= m
    return m


def borassus(cv, x, base, s, m_out, lean=0.0):
    """Rônier (Borassus) : tronc droit renflé au milieu, couronne de palmes en éventail."""
    pts_l, pts_r = [], []
    for j in range(41):
        t = j / 40
        y = base - t * 120 * s
        w = (3.4 + 1.6 * math.exp(-((t - 0.62) / 0.12) ** 2) - 0.8 * t) * s
        cx = x + lean * t * 40 * s
        pts_l.append((cx - w, y)); pts_r.append((cx + w, y))
    m = cv.poly(pts_l + pts_r[::-1])
    cx, cy = x + lean * 40 * s, base - 120 * s
    r = random.Random(int(x * 3))
    for k in range(14):
        a = math.radians(-180 + k * 13 + r.uniform(-5, 5))
        L = r.uniform(14, 20) * s
        fx, fy = cx + math.cos(a) * L * 0.55, cy + math.sin(a) * L * 0.45
        m |= stroke(cv, [(cx, cy), (fx, fy)], 0.9 * s, 0.6 * s)
        # l'éventail : un secteur hérissé
        fan = [(fx, fy)]
        for j in range(9):
            b = a + (j - 4) * 0.13
            rr = L * (0.55 if j % 2 else 0.75)
            fan.append((fx + math.cos(b) * rr, fy + math.sin(b) * rr * 0.8))
        m |= cv.poly(fan)
    m_out |= m
    return m


def trees_layer(L, seed=3):
    W = width(0.6)
    cv = Canvas(W, H)
    base = 272
    allm = np.zeros((H, W), bool)
    ground = cv.yy >= base + 2 * np.sin(cv.xx * 0.02)
    allm |= ground
    r = random.Random(seed)
    # bosquet lointain (petites formes) puis arbres marquants
    for x in range(0, W, 7):
        if r.random() < 0.6:
            h = r.uniform(4, 11)
            for k in range(r.randint(2, 4)):
                ox, oy, rr_ = r.uniform(-h, h), r.uniform(-h * 0.6, 0), h * r.uniform(0.4, 0.75)
                allm |= cv.ellipse(x + ox - rr_, base - h + oy - rr_, x + ox + rr_, base - h + oy + rr_)
            allm |= cv.poly([(x - h, base + 3), (x - h * 0.7, base - h * 0.8), (x + h * 0.7, base - h * 0.8), (x + h, base + 3)])
    for (kind, x, s, extra) in (("baobab", 110, 1.0, 0), ("palm", 205, 0.85, 0.05), ("palm", 236, 0.95, -0.04),
                                ("baobab", 420, 1.25, 0), ("palm", 560, 1.0, 0.03), ("palm", 590, 0.8, -0.05),
                                ("baobab", 760, 0.9, 0), ("palm", 880, 1.05, 0.02), ("palm", 940, 0.9, -0.03),
                                ("baobab", 1080, 1.1, 0), ("palm", 1170, 0.9, 0.04)):
        if kind == "baobab":
            baobab(cv, x, base + 2, s, allm)
        else:
            borassus(cv, x, base + 2, s, allm, extra)
    # couleur : silhouettes chaudes, liseré d'or côté soleil, brume
    tex = fbm(H, W, seed + 5, (12, 6, 3))
    base_c = mix(L["shade"], L["cool"], 0.35)
    col = base_c[None, None, :] * (0.85 + 0.3 * tex[..., None])
    cv.fill(allm, col)
    haze(cv, allm, L, 0.14 if L["sun"] is not None else 0.2)
    if L["rim"] is not None:
        e1 = edge_toward(allm, 1, 0, 1) | edge_toward(allm, 0, -1, 1)
        e2 = edge_toward(allm, 1, 0, 2) & ~e1
        cv.fill(e1 & ~ground, L["rim"], 0.85)
        cv.fill(e2 & ~ground, mix(L["haze"], L["rim"], 0.5), 0.5)
    # la masse des arbres : grain de feuillage (pas d'aplat)
    leafy = allm & (fbm(H, W, seed + 9, (3, 2)) > 0.62)
    cv.fill(leafy, base_c * 0.75, 0.6)
    return cv


# ================================================================ le village
def hut(cv, x, base, r, L, door=True, roof_h=None, finial=True):
    """Case ronde en banco : mur crépi à la main (cylindre), soubassement éclaboussé, porte à
    cadre de bois ; toit de chaume conique monté en couronnes, frange qui pend, faîte."""
    wall_h = r * 0.92
    roof_h = roof_h or r * 1.3
    seed = int(x * 7) % 997
    wall = cv.poly([(x - r, base - wall_h), (x + r, base - wall_h), (x + r, base), (x - r, base)])
    xs = np.clip((cv.xx - x) / r, -1, 1)
    cyl = np.sqrt(np.clip(1 - xs ** 2, 0, 1)) * r * 1.1
    plaster = fbm(cv.h, cv.w, seed, (5, 3, 2))
    strokes = np.sin((cv.xx - x) * 0.7 + plaster * 6 + cv.yy * 0.15) * 0.6       # traces de la main
    hg = cyl + strokes + plaster * 1.4
    v = light(hg, wall, L["ldir"], L["ambient"])
    base_c = L["mud"]
    lit_c = base_c[None, None, :] * (0.78 + 0.5 * v[..., None])
    if L["rim"] is not None:
        lit_c = mix(lit_c, np.ones_like(lit_c) * L["rim"], 0.2 * v)
    dark = mix(base_c * 0.4, L["cool"], 0.4)
    cv.fill(wall, mix(np.ones_like(lit_c) * dark, lit_c, smooth(v, 0.3, 0.6)))
    # fissures fines et soubassement assombri par les éclaboussures de pluie
    cracks = wall & (np.abs(fbm(cv.h, cv.w, seed + 1, (6, 3)) - 0.5) < 0.012)
    cv.fill(cracks, base_c * 0.45, 0.7)
    cv.fill(wall & (cv.yy > base - 4), L["shade"], 0.3)
    cv.fill(wall & (cv.yy > base - 2), L["shade"], 0.25)
    if door:
        dx0, dx1 = x + r * 0.08, x + r * 0.5
        dtop = base - wall_h * 0.74
        dm = cv.poly([(dx0, dtop), (dx1, dtop), (dx1, base), (dx0, base)]) & wall
        cv.fill(dm, L["shade"] * 0.45)
        frame = (cv.poly([(dx0 - 1.5, dtop - 1.5), (dx1 + 1.5, dtop - 1.5), (dx1 + 1.5, base), (dx0 - 1.5, base)]) & wall) & ~dm
        cv.fill(frame, L["wood"] * 1.4)
        if L["rim"] is not None:
            cv.fill(frame & (cv.xx > dx1), L["rim"] * 0.8, 0.6)
        # une natte roulée au-dessus de la porte
        mat = cv.poly([(dx0 - 1, dtop - 1), (dx1 + 1, dtop - 1), (dx1 + 1, dtop + 2), (dx0 - 1, dtop + 2)])
        cv.fill(mat, L["thatch"] * 0.8)
    over = r * 1.2
    apex_y = base - wall_h - roof_h
    roof = cv.poly([(x, apex_y), (x + over, base - wall_h + 3), (x - over, base - wall_h + 3)])
    # le chaume : brins orientés depuis le faîte, montés en couronnes qui se chevauchent
    ang = np.arctan2(cv.xx - x, cv.yy - apex_y + 1e-3)
    dist = np.sqrt((cv.xx - x) ** 2 + (cv.yy - apex_y) ** 2)
    straw = np.sin(ang * 90 + fbm(cv.h, cv.w, seed + 2, (4, 2)) * 5) * 0.5 + 0.5
    tiers = (dist % 7) / 7.0
    rx = (cv.xx - x) / np.maximum(1, (cv.yy - apex_y) * over / roof_h)
    cone = np.sqrt(np.clip(1 - rx ** 2, 0, 1)) * r * 1.2
    hg = cone + 1.3 * straw + 2.0 * tiers
    v = light(hg, roof, L["ldir"], L["ambient"])
    lit_c = L["thatch"][None, None, :] * (0.7 + 0.6 * v[..., None])
    if L["rim"] is not None:
        lit_c = mix(lit_c, np.ones_like(lit_c) * L["rim"], 0.25 * v)
    dark = mix(L["thatch"] * 0.38, L["cool"], 0.42)
    cv.fill(roof, mix(np.ones_like(lit_c) * dark, lit_c, smooth(v, 0.28, 0.6)))
    cv.fill(roof & (tiers < 0.14), L["shade"], 0.35)                       # bas de chaque couronne
    if L["rim"] is not None:
        cv.fill(edge_toward(roof, 1, 0, 1) | edge_toward(roof, 0, -1, 1), L["rim"], 0.85)
    # frange qui pend sous le bord du toit
    rr = random.Random(seed)
    fringe = np.zeros((cv.h, cv.w), bool)
    for k in range(int(over * 2.4)):
        px = x - over + k / 1.2 + rr.uniform(-0.4, 0.4)
        L_ = rr.choice((1, 2, 2, 3, 3, 4))
        for j in range(L_):
            yi, xi = int(base - wall_h + 3 + j), int(px)
            if 0 <= yi < cv.h and 0 <= xi < cv.w:
                fringe[yi, xi] = True
    cv.fill(fringe, mix(L["thatch"] * 0.55, L["cool"], 0.25))
    # ombre portée du toit sur le haut du mur
    cv.fill(wall & (cv.yy < base - wall_h + 5), L["shade"], 0.5)
    cv.fill(wall & (cv.yy < base - wall_h + 8), L["shade"], 0.2)
    m = wall | roof | fringe
    if finial:                                                         # un petit pot renversé au faîte
        pot = cv.ellipse(x - 2.5, apex_y - 4, x + 2.5, apex_y + 1)
        cv.fill(pot, C("8a4a2c") * (0.5 if L["sun"] is None else 1.0))
        m |= pot
    return m


def granary(cv, x, base, r, L):
    """Grenier sur pilotis : panier de terre et de fibres, chapeau de chaume."""
    for dx in (-r * 0.6, r * 0.6):
        leg = cv.poly([(x + dx - 1, base - 9), (x + dx + 1, base - 9), (x + dx + 1, base), (x + dx - 1, base)])
        cv.fill(leg, L["wood"])
    body = cv.ellipse(x - r, base - 9 - r * 2.0, x + r, base - 7)
    shaded(cv, body, L["mud"] * 0.95, L, r, rim_w=1)
    cap = cv.poly([(x, base - 9 - r * 3.1), (x + r * 1.25, base - 9 - r * 1.55), (x - r * 1.25, base - 9 - r * 1.55)])
    shaded(cv, cap, L["thatch"], L, r * 0.7, rim_w=1)
    return body | cap


def fence(cv, x0, x1, base, L, h=11):
    """Palissade de tiges de mil tressées."""
    m = np.zeros((cv.h, cv.w), bool)
    for x in range(int(x0), int(x1), 2):
        hh = h + (x * 7 % 3)
        m |= cv.poly([(x, base - hh), (x + 1, base - hh - 1), (x + 1, base), (x, base)])
    for yb in (base - h * 0.35, base - h * 0.75):
        m |= cv.poly([(x0, yb), (x1, yb - 1), (x1, yb + 1), (x0, yb + 2)])
    v = 0.55 + 0.35 * ((cv.xx.astype(int) % 2) == 0)
    cv.fill(m, L["thatch"][None, None, :] * v[..., None] * 0.8)
    return m


def village(L, seed=5):
    W = width(1.0)
    cv = Canvas(W, H)
    # le sol : latérite rouge, herbe sèche, un sentier clair qui mène au sanctuaire
    g = cv.yy >= GROUND - 1.2 * np.sin(cv.xx * 0.013) - 0.8 * np.sin(cv.xx * 0.05)
    tex = fbm(H, W, seed, (24, 12, 6, 3))
    soil = mix(L["laterite"] * 0.75, L["laterite"], tex[..., None].squeeze(-1)) if False else \
        L["laterite"][None, None, :] * (0.75 + 0.45 * tex[..., None])
    cv.fill(g, soil)
    grass = g & (fbm(H, W, seed + 1, (14, 7, 3)) > 0.6) & (cv.yy < GROUND + 18)
    cv.fill(grass, mix(L["grass"], L["laterite"], 0.35)[None, None, :] * (0.75 + 0.4 * tex[..., None]), 0.75)
    path = g & (np.abs(cv.yy - (GROUND + 10 + 6 * np.sin(cv.xx * 0.004))) < 4 + 2 * tex)
    cv.fill(path, mix(L["laterite"], L["haze"] if L["sun"] is not None else L["laterite"], 0.35), 0.8)
    # le sol s'assombrit en approchant de nous (le premier plan est à contre-jour)
    cv.fill(g, mix(L["shade"], L["cool"], 0.3), smooth(cv.yy, GROUND + 6, H) * 0.55)
    # touffes d'herbe sèche, cailloux, une termitière : le sol vit
    rr = random.Random(seed + 9)
    tufts = np.zeros((H, W), bool)
    for _ in range(260):
        cx_ = rr.uniform(0, W); x = cx_; y = rr.uniform(GROUND + 2, H - 4)
        sc = 0.5 + (y - GROUND) / (H - GROUND)
        for k in range(rr.randint(3, 6)):
            b = rr.uniform(-4, 4) * sc; hh = rr.uniform(3, 8) * sc
            tufts |= stroke(cv, [(x + k * 0.8, y), (x + k * 0.8 + b * 0.4, y - hh * 0.6), (x + k * 0.8 + b, y - hh)], 0.6, 0.25)
    tc = mix(L["grass"], L["millet"], 0.35)[None, None, :] * (0.7 + 0.45 * tex[..., None])
    cv.fill(tufts, mix(tc, L["shade"] * np.ones_like(tc), smooth(cv.yy, GROUND + 10, H) * 0.6))
    if L["rim"] is not None:
        cv.fill(edge_toward(tufts, 1, 0, 1), L["rim"], 0.55)
    stones = np.zeros((H, W), bool)
    for _ in range(90):
        x = rr.uniform(0, W); y = rr.uniform(GROUND + 3, H - 2); r0 = rr.uniform(0.8, 2.6) * (0.6 + (y - GROUND) / 70)
        stones |= cv.ellipse(x - r0, y - r0 * 0.7, x + r0, y + r0 * 0.4)
    shaded(cv, stones, mix(L["laterite"], C("8a8278"), 0.5), L, 1.5)
    mound = cv.poly([(250, GROUND + 2), (256, GROUND - 20), (259, GROUND - 26), (263, GROUND - 18), (268, GROUND - 22), (275, GROUND + 2)])
    shaded(cv, mound, L["laterite"] * 1.05, L, 5, tex=fbm(H, W, 41, (3, 2)) * 1.2)
    shapes = np.zeros((H, W), bool)
    # le champ de mil, à gauche (épis mûrs, dorés)
    r = random.Random(seed)
    field = np.zeros((H, W), bool)
    for x in range(20, 330, 3):
        hh = r.uniform(26, 38)
        lean = r.uniform(-3, 3)
        field |= stroke(cv, [(x, GROUND + 1), (x + lean * 0.4, GROUND - hh * 0.5), (x + lean, GROUND - hh)], 0.8, 0.4)
        field |= cv.ellipse(x + lean - 1.6, GROUND - hh - 6, x + lean + 1.6, GROUND - hh + 1)
    shaded(cv, field, L["millet"], L, 1.5, rim_w=1)
    shapes |= field
    # les cases, greniers et palissades
    # (type, x, taille, recul) : recul > 0 = plus loin (plus haut, plus petit, plus voilé)
    elems = [("hut", 430, 16, 7), ("hut", 520, 15, 8), ("granary", 560, 6, 7), ("hut", 760, 15, 7), ("hut", 880, 16, 8),
             ("granary", 1000, 6, 8), ("hut", 1090, 15, 7),
             ("hut", 395, 22, 0), ("granary", 452, 8, 0), ("hut", 486, 18, 1), ("fence", (505, 560), 0, 0),
             ("hut", 610, 25, 0), ("granary", 660, 9, 0), ("hut", 705, 19, 1), ("hut", 800, 23, 0), ("fence", (822, 880), 0, 0),
             ("granary", 912, 8, 0), ("hut", 960, 20, 1), ("hut", 1050, 24, 0), ("granary", 1102, 9, 0), ("fence", (1132, 1250), 0, 0)]
    for kind, x, sz, back in elems:
        b = GROUND + 1 - back
        before = cv.rgb.copy()
        if kind == "hut":
            m = hut(cv, x, b, sz, L)
        elif kind == "granary":
            m = granary(cv, x, b, sz, L)
        else:
            m = fence(cv, x[0], x[1], b, L)
        if back:
            cv.fill(m, mix(L["haze"], L["sky_low"], 0.5), 0.18 + 0.02 * back)
        shapes |= m
    # le sanctuaire de Xɛvioso, avec sa personnalité : l'éclair en zigzag rouge et blanc peint
    # partout, les cornes de bélier, l'arbre sacré ceint de pagnes, les bannières, l'entrée
    sx = SANCT_X
    shapes |= sanctuary(cv, sx, L)
    # ombres portées : chaque point d'une silhouette se projette au sol, loin vers la gauche
    # (soleil bas à droite) ; l'ombre s'écrase un peu en profondeur
    if L["sun"] is not None:
        ys, xs = np.nonzero(shapes & (cv.yy < GROUND + 1))
        hh = GROUND - ys
        gx = (xs - hh * 2.6).astype(int)
        gy = (GROUND + 1 + hh * 0.06).astype(int)
        ok = (gx >= 0) & (gx < W) & (gy < H)
        sh = np.zeros((H, W), bool)
        sh[gy[ok], gx[ok]] = True
        sh = ndimage.binary_closing(ndimage.binary_dilation(sh, iterations=1), iterations=2)
        sh &= g & ~shapes
        cv.fill(sh, mix(L["shade"], L["cool"], 0.5), 0.5)
    cv.a = np.maximum(cv.a, g.astype(float))
    return cv


def zigzag_band(cv, m, y0, h, period, colors, L):
    """Une frise d'éclairs en zigzag (rouge sur blanc) peinte sur une surface."""
    t = ((cv.xx % period) / period)
    tri = np.abs(t - 0.5) * 2                       # 0..1..0
    zig = y0 + tri * h
    band = m & (cv.yy >= y0 - 1) & (cv.yy <= y0 + h + 1)
    red = band & (np.abs(cv.yy - zig) < 1.3)
    k = 0.55 if L["sun"] is None else 1.0
    cv.fill(band, colors[0] * k, 0.85)
    cv.fill(red, colors[1] * k)


def horns(cv, x, y, s, L, flip=1):
    """Un crâne de bélier et ses cornes enroulées en spirale (l'animal de Xɛvioso)."""
    m = np.zeros((cv.h, cv.w), bool)
    ivory = C("ece2c8") * (0.55 if L["sun"] is None else 1.0)
    for side in (-1, 1):
        cx0, cy0 = x + side * 4.2 * s, y - 1.0 * s          # centre de la spirale
        pts = []
        for j in range(40):
            t = j / 39
            a = math.pi * 0.95 - t * math.pi * 1.75           # part du crâne, monte, s'enroule vers le bas
            rr = 4.6 * s * (1 - 0.6 * t)
            pts.append((cx0 + side * math.cos(a) * rr * -1 * -1 if False else cx0 - side * math.cos(a) * rr,
                        cy0 - math.sin(a) * rr))
        m |= stroke(cv, pts, 1.7 * s, 0.55 * s)
    skull = cv.poly([(x - 2.2 * s, y - 2.5 * s), (x + 2.2 * s, y - 2.5 * s), (x + 1.4 * s, y + 3.5 * s), (x - 1.4 * s, y + 3.5 * s)])
    shaded(cv, m | skull, ivory, L, 1.4 * s)
    ridges = m & (np.sin((cv.xx + cv.yy) * 1.7) > 0.75)
    cv.fill(ridges, ivory * 0.68, 0.7)
    for side in (-1, 1):                                      # les orbites
        e = cv.ellipse(x + side * 1.1 * s - 0.6, y - 0.8 * s - 0.6, x + side * 1.1 * s + 0.6, y - 0.8 * s + 0.6)
        cv.fill(e, L["shade"])
    return m | skull


def banner(cv, x, top, h, color, L, sway=0.0):
    """Un mât et sa bannière (tissu qui ondule, plis éclairés)."""
    pole = cv.poly([(x - 1, top), (x + 1, top), (x + 1, GROUND), (x - 1, GROUND)])
    shaded(cv, pole, L["wood"] * 1.4, L, 1)
    pts_t, pts_b = [], []
    for j in range(15):
        t = j / 14
        px = x + 1 + t * 16
        w = 2.4 * math.sin(t * 6 + sway) * t
        pts_t.append((px, top + 2 + w)); pts_b.append((px, top + 2 + h * (1 - 0.35 * t) + w))
    cloth = cv.poly(pts_t + pts_b[::-1])
    folds = np.sin((cv.xx - x) * 0.35 + sway) * 1.0
    shaded(cv, cloth, color * (0.55 if L["sun"] is None else 1.0), L, 2, tex=folds)
    return pole | cloth


def sanctuary(cv, sx, L):
    m = np.zeros((cv.h, cv.w), bool)
    k = 0.55 if L["sun"] is None else 1.0
    WHITE, RED = C("efe8d6"), C("a8261a")
    # l'arbre sacré, au fond à droite de l'enclos : tronc ceint de pagnes rouge et blanc
    tx = sx + 98
    trunk = stroke(cv, [(tx, GROUND - 12), (tx - 2, GROUND - 60), (tx + 3, GROUND - 104)], 7, 4)
    for (a0, a1, w) in ((-2.4, -1.6, 3), (-1.2, -0.5, 3), (-0.7, 0.1, 2.5)):
        for t0 in (0.0,):
            pass
    for ang, L_ in ((-2.5, 34), (-1.9, 28), (-1.2, 30), (-0.6, 32), (-0.1, 26)):
        trunk |= stroke(cv, [(tx + 2, GROUND - 98), (tx + math.cos(ang) * L_ * 0.5, GROUND - 104 + math.sin(ang) * L_ * 0.4),
                             (tx + math.cos(ang) * L_, GROUND - 106 + math.sin(ang) * L_ * 0.7)], 2.6, 0.8)
    shaded(cv, trunk, L["wood"] * 1.6, L, 4, tex=np.sin(cv.yy * 0.9 + cv.xx * 0.2) * 0.8)
    rr = random.Random(77)
    crown = np.zeros((cv.h, cv.w), bool)
    for _ in range(26):
        cx_, cy_ = tx + rr.uniform(-38, 38), GROUND - 118 + rr.uniform(-18, 14)
        r0 = rr.uniform(7, 14)
        crown |= cv.ellipse(cx_ - r0, cy_ - r0 * 0.8, cx_ + r0, cy_ + r0 * 0.8)
    shaded(cv, crown, mix(L["leaf"], L["laterite"], 0.15) * 1.05, L, 9, tex=fbm(cv.h, cv.w, 78, (4, 2)) * 3)
    cv.fill(crown & (fbm(cv.h, cv.w, 79, (3, 2)) > 0.66), L["shade"], 0.35)
    for i, (y0, col) in enumerate(((GROUND - 44, WHITE), (GROUND - 39, RED), (GROUND - 34, WHITE))):
        band = trunk & (cv.yy >= y0) & (cv.yy < y0 + 5) & (np.abs(cv.xx - tx) < 9)
        shaded(cv, band, col * k, L, 3)
    knot = cv.poly([(tx + 6, GROUND - 40), (tx + 11, GROUND - 38), (tx + 10, GROUND - 26), (tx + 7, GROUND - 28)])
    cv.fill(knot, WHITE * k * 0.9)
    m |= trunk | crown | knot
    # bannières rouges et blanches de part et d'autre de la case
    m |= banner(cv, sx - 92, GROUND - 98, 12, RED, L, 0.0)
    m |= banner(cv, sx - 18, GROUND - 104, 12, WHITE, L, 1.7)
    # le mât central de la hache double (la hache est un sprite animé)
    post = cv.poly([(sx + 38, GROUND - 100), (sx + 42, GROUND - 100), (sx + 42, GROUND - 38), (sx + 38, GROUND - 38)])
    shaded(cv, post, L["wood"] * 1.3, L, 2)
    m |= post
    # la case sacrée : plus haute, murs peints de l'éclair, cornes de bélier au faîte
    hx = sx - 55
    hm = hut(cv, hx, GROUND - 13, 30, L, door=True, roof_h=54, finial=False)
    wall = hm & (cv.yy > GROUND - 13 - 30 * 0.92 + 4) & (cv.yy < GROUND - 13)
    zigzag_band(cv, wall & (np.abs(cv.xx - hx) < 30), GROUND - 34, 7, 10, (WHITE, RED), L)
    dots = wall & ((cv.xx.astype(int) % 6) == 0) & ((cv.yy.astype(int) % 5) == 0) & (cv.yy > GROUND - 24)
    cv.fill(dots, WHITE * k)
    curtain = cv.poly([(hx + 2.5, GROUND - 13 - 20), (hx + 15, GROUND - 13 - 20), (hx + 14, GROUND - 14), (hx + 3, GROUND - 14)])
    shaded(cv, curtain, RED * k, L, 2, tex=np.sin(cv.xx * 1.4) * 0.8)
    m |= hm | curtain | horns(cv, hx, GROUND - 13 - 30 * 0.92 - 54 + 3, 1.6, L)
    # l'enclos : muret de banco, dessus éclairé, face peinte d'une frise d'éclairs ; entrée à gauche
    for (x0, x1) in ((sx - 128, sx - 104), (sx - 82, sx + 128)):
        front = cv.poly([(x0, GROUND - 13), (x1, GROUND - 13), (x1, GROUND + 1), (x0, GROUND + 1)])
        top = cv.poly([(x0, GROUND - 15), (x1, GROUND - 15), (x1, GROUND - 13), (x0, GROUND - 13)])
        shaded(cv, front, L["mud"] * 1.02, L, 3, tex=fbm(cv.h, cv.w, 31, (5, 3)) * 1.5)
        cv.fill(top, mix(L["mud"], L["rim"] if L["rim"] is not None else L["mud"], 0.4) * (1.15 if L["sun"] is not None else 0.6))
        zigzag_band(cv, front, GROUND - 10, 6, 12, (WHITE, RED), L)
        m |= front | top
    # l'entrée : deux poteaux sculptés, un linteau, un pagne blanc qui pend
    for gx in (sx - 104, sx - 82):
        p = cv.poly([(gx - 2.5, GROUND - 46), (gx + 2.5, GROUND - 46), (gx + 2.5, GROUND + 1), (gx - 2.5, GROUND + 1)])
        notch = p & ((cv.yy.astype(int) % 7) < 1)
        shaded(cv, p, L["wood"] * 1.5, L, 2)
        cv.fill(notch, L["shade"], 0.5)
        m |= p
    lint = cv.poly([(sx - 109, GROUND - 49), (sx - 77, GROUND - 49), (sx - 77, GROUND - 45), (sx - 109, GROUND - 45)])
    shaded(cv, lint, L["wood"] * 1.5, L, 2)
    drape = cv.poly([(sx - 102, GROUND - 45), (sx - 84, GROUND - 45), (sx - 86, GROUND - 38), (sx - 93, GROUND - 35), (sx - 100, GROUND - 38)])
    shaded(cv, drape, WHITE * k, L, 2, tex=np.sin(cv.xx * 1.2) * 0.7)
    m |= lint | drape | horns(cv, sx - 93, GROUND - 52, 1.1, L)
    # l'autel d'argile, à degrés, et son tabouret sculpté (la Pierre de foudre s'y pose)
    altar = cv.ellipse(sx + 6, GROUND - 42, sx + 74, GROUND - 8) & (cv.yy < GROUND - 13)
    altar |= cv.poly([(sx + 10, GROUND - 26), (sx + 70, GROUND - 26), (sx + 74, GROUND - 13), (sx + 6, GROUND - 13)])
    shaded(cv, altar, L["mud"] * 0.92, L, 9, tex=fbm(cv.h, cv.w, 33, (4, 2)) * 1.2)
    zigzag_band(cv, altar & (cv.yy > GROUND - 24), GROUND - 22, 5, 9, (WHITE, RED), L)
    stool = cv.poly([(sx + 30, GROUND - 46), (sx + 50, GROUND - 46), (sx + 47, GROUND - 42), (sx + 45, GROUND - 38),
                     (sx + 35, GROUND - 38), (sx + 33, GROUND - 42)])
    shaded(cv, stool, L["wood"] * 1.6, L, 2)
    m |= altar | stool | horns(cv, sx + 15, GROUND - 31, 1.0, L) | horns(cv, sx + 65, GROUND - 31, 1.0, L)
    # jarres d'offrandes
    for (jx, jr) in ((sx + 82, 6), (sx + 93, 4.5), (sx - 6, 5), (sx + 2, 3.5)):
        jar = cv.ellipse(jx - jr, GROUND - 13 - jr * 2.2, jx + jr, GROUND - 13)
        shaded(cv, jar, C("8a4a2c") * k, L, jr)
        m |= jar
    return m


# ================================================================ premier plan
def foreground(L, seed=7):
    W = width(1.45)
    cv = Canvas(W, H)
    r = random.Random(seed)
    m = np.zeros((H, W), bool)
    heads = np.zeros((H, W), bool)
    x = 0.0
    while x < W:
        cx = x + r.uniform(0, 30)
        n = r.randint(10, 22)
        tall = r.uniform(12, 28)
        for k in range(n):
            bx = cx + r.uniform(-9, 9)
            hh = tall * r.uniform(0.5, 1.0)
            bend = r.uniform(-10, 10) * (hh / 34)
            m |= stroke(cv, [(bx, H + 2), (bx + bend * 0.3, H - hh * 0.6), (bx + bend, H - hh)], 0.75, 0.2)
        if r.random() < 0.35:                              # un épi de mil penché
            hx = cx + r.uniform(-4, 4); hh = tall + r.uniform(10, 26); b = r.uniform(4, 10)
            m |= stroke(cv, [(hx, H + 2), (hx + b * 0.3, H - hh * 0.6), (hx + b, H - hh)], 1.1, 0.5)
            heads |= cv.ellipse(hx + b - 2.2, H - hh - 9, hx + b + 2.2, H - hh + 1)
        x += r.uniform(22, 48)
    col = mix(L["shade"], L["cool"], 0.25)
    cv.fill(m | heads, col * 0.9)
    if L["rim"] is not None:
        cv.fill(edge_toward(m | heads, 1, 0, 1), mix(col, L["rim"], 0.7), 0.8)
        cv.fill(heads & ~edge_toward(heads, -1, 0, 1), mix(col, L["millet"], 0.35), 0.7)
    return cv


def darken_night(cv, L, k=0.5):
    """La nuit, rien n'est vif : on assombrit et refroidit les couches proches."""
    if L["sun"] is None:
        cv.rgb = mix(cv.rgb * k, np.ones_like(cv.rgb) * L["cool"] * 0.6, 0.25)


def render_all(out):
    os.makedirs(out, exist_ok=True)
    for mode in ("or", "nuit"):
        L = LIGHTS[mode]
        for name, fn in (("ciel", sky), ("collines", hills), ("arbres", trees_layer), ("village", village), ("premier_plan", foreground)):
            cv = fn(L)
            if name in ("village", "arbres", "premier_plan"):
                darken_night(cv, L, {"village": 0.5, "arbres": 0.7, "premier_plan": 0.6}[name])
            save(cv.rgb, cv.a, os.path.join(out, f"{name}_{mode}.png"), levels=26)
            print(" ", name, mode, cv.w, "×", cv.h)


if __name__ == "__main__":
    render_all(sys.argv[1] if len(sys.argv) > 1 else ".")
