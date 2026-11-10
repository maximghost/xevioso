"""Arrière-plans en parallaxe de la forêt des irokos (640 px de large, raccordables).

Ambiance : sous la canopée, en plein jour, mais la lumière arrive à peine. Une voûte de
feuilles presque noire en haut, des trouées par où tombe un jour vert pâle, de la brume
entre les troncs. Perspective atmosphérique : plus c'est loin, plus c'est clair et bleu-vert.
  bg_sky.png   (640 × 360) : la voûte et le jour qui filtre
  bg_far.png   (640 × 420) : troncs lointains noyés dans la brume
  bg_mid.png   (640 × 420) : grands troncs à contreforts, lianes
  bg_near.png  (640 × 420) : sous-bois : fougères, palmes, feuillages sombres
La forêt est malade (corrompue) au début : les couleurs vivantes reviennent à la fin du
niveau par la teinte générale du niveau ; ce fond reste neutre (vert éteint).
"""
import math, random, sys
import numpy as np
from PIL import Image, ImageDraw

W, H, HL = 640, 360, 420
OUT = sys.argv[1]
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def quant(val, pal, h=HL):
    """Valeurs 0..1 → indices de palette, tramés (Bayer 4×4)."""
    bay = BAYER[np.arange(h)[:, None] % 4, np.arange(W)[None, :] % 4]
    n = len(pal)
    return np.clip(np.floor(val * (n - 1) + bay), 0, n - 1).astype(int)


def paint(rgba, mask, val, pal):
    idx = quant(val, pal, rgba.shape[0])
    for i, c in enumerate(pal):
        sel = mask & (idx == i)
        rgba[sel, :3] = c
        rgba[sel, 3] = 255


def wrap_draw(draw_fn, h=HL):
    """Masque raccordable : on dessine trois fois (x − W, x, x + W)."""
    im = Image.new("L", (W, h), 0)
    d = ImageDraw.Draw(im)
    for off in (-W, 0, W):
        draw_fn(d, off)
    return np.array(im) > 127


def trunk_mask(x, w_top, w_base, y_top, y_base, flare=1.6, h=HL, sway=0.0):
    """Un tronc droit qui s'évase en contreforts au pied."""
    def fn(d, off):
        pts_l, pts_r = [], []
        for j in range(21):
            t = j / 20
            y = y_top + (y_base - y_top) * t
            w = w_top + (w_base - w_top) * t ** 7 * flare
            cx = x + off + sway * math.sin(t * 3)
            pts_l.append((cx - w, y)); pts_r.append((cx + w, y))
        d.polygon(pts_l + pts_r[::-1], fill=255)
    return wrap_draw(fn, h)


def across(mask):
    """Pour chaque pixel d'un masque, sa position 0..1 de gauche à droite dans sa rangée."""
    u = np.zeros(mask.shape)
    for y in range(mask.shape[0]):
        row = np.nonzero(mask[y])[0]
        if len(row) == 0:
            continue
        for run in np.split(row, np.nonzero(np.diff(row) > 1)[0] + 1):
            u[y, run] = (run - run[0]) / max(1, run[-1] - run[0])
    return u


R = random.Random(11)
yy, xx = np.mgrid[0:HL, 0:W]

# ------------------------------------------------------------------ 1. La voûte
sky = np.zeros((H, W, 4), np.uint8)
SKY = [hexc(c) for c in ("0b1512", "10201a", "173024", "21412f", "2f5640", "466e55", "6a8f72", "9cb898")]
v = np.clip((np.arange(H)[:, None] / H) ** 0.9 * 0.85 + 0.0 * xx[:H], 0, 1)
# des trouées de jour, hautes et diffuses (périodiques sur 640 px)
for k, (cx, cy, rx, ry, s) in enumerate([(90, 70, 70, 40, 0.5), (300, 40, 50, 30, 0.6), (470, 90, 80, 45, 0.45),
                                         (600, 30, 40, 25, 0.4)]):
    for off in (-W, 0, W):
        d2 = ((xx[:H] - cx - off) / rx) ** 2 + ((yy[:H] - cy) / ry) ** 2
        v = v + s * np.exp(-d2 * 1.5)
v = np.clip(v, 0, 1)
paint(sky, np.ones((H, W), bool), v, SKY)
# la voûte de feuilles devant le jour : touffes sombres en haut, découpées
LEAVES = [hexc(c) for c in ("08100d", "0d1913", "13241b")]
for i in range(700):
    x = R.uniform(0, W)
    y = R.uniform(-10, 110)
    if y > 50 and R.random() < 0.85:
        continue
    r = R.uniform(4, 10) * (1.4 - y / 150)
    ang = np.arctan2(yy[:H] - y, xx[:H] - x)
    jag = 0.22 * np.sin(ang * R.choice((5, 6, 7)) + R.uniform(0, 6))
    m = np.zeros((H, W), bool)
    for off in (-W, 0, W):
        m |= np.hypot((xx[:H] - x - off) / r, (yy[:H] - y) / (r * 0.8)) < 1 + jag
    lit = np.clip(-((xx[:H] - x) + (yy[:H] - y)) / (2 * r), -1, 1) * 0.45 + 0.35
    paint(sky, m, lit, LEAVES)
Image.fromarray(sky, "RGBA").save(f"{OUT}/bg_sky.png")

# ------------------------------------------------------------------ 2. Troncs lointains
far = np.zeros((HL, W, 4), np.uint8)
FAR = [hexc(c) for c in ("38584c", "3f6053", "476a5b", "507464")]
fog_base = 300
FAR2 = [hexc(c) for c in ("4d7062", "557868", "5d806f")]
for i in range(12):                       # les plus lointains : fins, presque fondus
    x = i * 53 + R.uniform(-15, 15)
    w = R.uniform(3, 6)
    m = trunk_mask(x, w, w * 2.0, -10, fog_base, flare=1.0)
    paint(far, m, 0.3 + 0.4 * (1 - across(m)), FAR2)
for i in range(9):                        # puis des troncs plus proches, plus sombres
    x = i * 71 + 30 + R.uniform(-18, 18)
    w = R.uniform(6, 12)
    m = trunk_mask(x, w, w * 2.6, -10, fog_base + R.uniform(-10, 10), flare=1.0)
    u = across(m)
    val = 0.15 + 0.45 * (1 - u) + (yy / HL) * 0.25
    paint(far, m, val, FAR)
# la brume monte du sol : un voile clair tramé sur le bas des troncs
FOG = hexc("5f8274")
fog = np.clip((yy - 200) / 120.0, 0, 1)
bay = BAYER[yy % 4, xx % 4]
sel = (fog > bay) & (yy > 200)
far[sel, :3] = FOG
far[sel, 3] = 255
# des sous-bois lointains au pied (masse ondulée)
crest = 282 + 6 * np.sin(2 * np.pi * xx / W * 5) + 4 * np.sin(2 * np.pi * xx / W * 13 + 1)
m = yy > crest
paint(far, m, 0.6 + 0.1 * np.sin(xx * 0.3), [hexc("4a6e5e"), hexc("547a69")])
Image.fromarray(far, "RGBA").save(f"{OUT}/bg_far.png")

# ------------------------------------------------------------------ 3. Grands troncs
mid = np.zeros((HL, W, 4), np.uint8)
BARK = [hexc(c) for c in ("101a16", "17241e", "1f3027", "2a3d31", "374c3d", "4a5f4c")]
base_y = 330
for x, w in ((60, 17), (250, 11), (400, 20), (560, 13)):
    m = trunk_mask(x, w, w * 3.2, -20, base_y, flare=1.0)
    u = across(m)
    ridges = np.sin((xx - x) * 0.55 + np.sin(yy * 0.04) * 1.5)
    val = 0.1 + 0.5 * (1 - u) ** 1.4 + 0.1 * ridges - 0.1 * (yy < 40)
    val[ridges < -0.85] = 0.02
    paint(mid, m, val, BARK)
# lianes qui pendent de la voûte
VINE = [hexc(c) for c in ("13241a", "1d3524", "2b4a31")]
for k in range(14):
    x0 = R.uniform(0, W); L = R.uniform(120, 300); ph = R.uniform(0, 6)
    def fn(d, off, x0=x0, L=L, ph=ph):
        pts = [(x0 + off + 6 * math.sin(y * 0.02 + ph), y) for y in range(-5, int(L), 3)]
        d.line(pts, fill=255, width=2)
        for y in range(10, int(L), 14):          # petites feuilles le long de la liane
            x = x0 + off + 6 * math.sin(y * 0.02 + ph)
            d.ellipse((x - 3 if (y // 14) % 2 else x, y, x + (0 if (y // 14) % 2 else 3), y + 2), fill=255)
    m = wrap_draw(fn)
    paint(mid, m & (mid[..., 3] == 0) | m, np.full((HL, W), 0.5), VINE)
Image.fromarray(mid, "RGBA").save(f"{OUT}/bg_mid.png")

# ------------------------------------------------------------------ 4. Sous-bois proche
near = np.zeros((HL, W, 4), np.uint8)
UNDER = [hexc(c) for c in ("070c0a", "0c1511", "121f18", "1a2c21")]
def frond(d, off, x, y, ang, length, side):
    """Une palme de fougère : une tige courbe et des folioles de part et d'autre."""
    pts = []
    for j in range(16):
        t = j / 15
        a = ang + side * t * 0.9
        px = x + off + math.cos(a) * length * t
        py = y - math.sin(a) * length * t + t * t * length * 0.35
        pts.append((px, py))
    d.line(pts, fill=255, width=2)
    for j in range(2, 15):
        px, py = pts[j]
        leaf = (1 - j / 16) * 9 + 2
        for s in (-1, 1):
            d.polygon([(px, py), (px + s * leaf * 0.3, py + leaf), (px + s * 2, py + 1)], fill=255)

for i in range(24):
    x = R.uniform(0, W); y = R.uniform(300, 330)
    for k in range(5):
        ang = math.radians(R.uniform(40, 140))
        side = 1 if ang < math.pi / 2 else -1
        m = wrap_draw(lambda d, off, x=x, y=y, ang=ang, side=side: frond(d, off, x, y, ang, R.uniform(30, 60), side))
        val = 0.2 + 0.5 * np.clip(1 - (yy - 250) / 110, 0, 1)
        paint(near, m, val, UNDER)
# masse sombre du sous-bois au pied
crest = 318 + 8 * np.sin(2 * np.pi * xx / W * 7) + 5 * np.sin(2 * np.pi * xx / W * 17 + 2)
paint(near, yy > crest, np.full((HL, W), 0.1), UNDER)
Image.fromarray(near, "RGBA").save(f"{OUT}/bg_near.png")

# ------------------------------------------------------------------ Aperçu
prev = Image.fromarray(sky, "RGBA").copy()
for layer, dy in ((far, -26), (mid, -34), (near, -44)):
    im = Image.fromarray(layer, "RGBA")
    prev.alpha_composite(im.crop((0, -dy, W, -dy + H)) if dy < 0 else im)
prev.save(f"{OUT}/bg_prev.png")
