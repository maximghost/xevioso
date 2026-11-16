"""Peint le souterrain de la forêt d'un seul tenant (souterrain.png, souterrain_green.png).

Les galeries sont creusées dans la grille de tuiles (layout_foret.py) : des rectangles.
Cette peinture les habille comme une vraie galerie creusée sous les racines : parois aux
contours irréguliers et arrondis, voûte bosselée d'où pendent des radicelles, strates de
terre, cailloux pris dans la terre, grosses racines qui traversent, ombre portée au fond
des galeries. Le sol reste exactement sur la ligne des tuiles (les pieds ne flottent pas).

Utilisation : python3 cave_paint.py DOSSIER_SORTIE
"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout_foret as L

T = 16
rng = np.random.default_rng(7)


def value_noise(h, w, cell, seed):
    r = np.random.default_rng(seed)
    gh, gw = h // cell + 3, w // cell + 3
    g = r.random((gh, gw))
    big = ndimage.zoom(g, cell, order=3)[:h, :w]
    return (big - big.min()) / (np.ptp(big) + 1e-9)


def fbm(h, w, seed, cells=(48, 24, 12, 6)):
    out = np.zeros((h, w)); amp = 1.0; tot = 0
    for i, c in enumerate(cells):
        out += amp * value_noise(h, w, c, seed + i); tot += amp; amp *= 0.5
    return out / tot


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def paint(green=False):
    c0, c1, r0, r1 = L.CAVE_REGION
    W, H = (c1 - c0 + 1) * T, (r1 - r0 + 1) * T
    # masque exact des galeries, au pixel
    cave = np.zeros((H, W), bool)
    for (a, b, ra, rb) in L.CAVE:
        cave[(ra - r0) * T:(rb - r0 + 1) * T, (a - c0) * T:(b - c0 + 1) * T] = True
    solid = np.zeros((H, W), bool)
    for r in range(r0, r1 + 1):
        for c in range(c0, c1 + 1):
            if L.solid[r][c]:
                solid[(r - r0) * T:(r - r0 + 1) * T, (c - c0) * T:(c - c0 + 1) * T] = True
    earth = solid.copy()                               # ce qu'on peint en terre
    paintable = earth | cave
    # lignes de sol : un pixel de galerie posé sur de la terre
    below = np.zeros_like(solid); below[:-1] = solid[1:]
    floor_px = cave & below
    # 1) contour organique : arrondi + bosses (jamais sur le sol)
    n1 = fbm(H, W, 11, (40, 20, 10, 5))
    n1 = (n1 - n1.min()) / (np.ptp(n1) + 1e-9)
    # le sol ne doit pas « attirer » la terre : on prolonge le vide sous chaque galerie
    cave_dn = cave.copy()
    for k in range(1, 24):
        cave_dn[k:] |= cave[:-k]
    rounded = ndimage.gaussian_filter(cave_dn.astype(float), 6.0) > 0.5
    d_in = ndimage.distance_transform_edt(cave_dn)
    # combien la terre peut déborder ici : beaucoup dans les grandes salles, peu dans les
    # boyaux où l'on rampe (la silhouette accroupie doit rester libre)
    vh = np.zeros((H, W)); vw = np.zeros((H, W))
    for x in range(W):
        col_ = cave[:, x]; y = 0
        while y < H:
            if col_[y]:
                y1 = y
                while y1 < H and col_[y1]: y1 += 1
                vh[y:y1, x] = y1 - y; y = y1
            else: y += 1
    for y in range(H):
        row_ = cave[y]; x = 0
        while x < W:
            if row_[x]:
                x1 = x
                while x1 < W and row_[x1]: x1 += 1
                vw[y, x:x1] = x1 - x; x = x1
            else: x += 1
    allowed = np.clip(np.minimum(vh - 27, (vw - 12) / 2), 1.5, 14)
    amp = allowed * np.clip(1.6 * n1 - 0.25, 0.08, 1.0)
    vis = rounded & (d_in > amp)
    # le sol : exact (on rétablit les 6 px au-dessus de chaque ligne de sol)
    fl = np.zeros_like(cave)
    ys, xs = np.nonzero(floor_px)
    for k in range(1, 7):
        yy = np.clip(ys - k + 1, 0, H - 1)
        fl[yy, xs] = True
    # mais on garde l'arrondi des coins sol/paroi (un petit congé de terre)
    corner = cave & ~ndimage.binary_erosion(cave, iterations=1, border_value=1)
    vis = vis & cave
    soil = paintable & ~vis
    # 2) champs utiles
    d_soil = ndimage.distance_transform_edt(~soil)     # dans la galerie : distance à la paroi
    d_air = ndimage.distance_transform_edt(soil)       # dans la terre : distance au vide
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    n2 = fbm(H, W, 23)
    n3 = fbm(H, W, 37, (8, 4, 2))
    img = np.zeros((H, W, 4))
    # 3) la terre : strates ondulées, grain, plus sombre en profondeur
    strata = np.sin((yy + 18 * n2) / 5.5) * 0.5 + 0.5
    depth = yy / H
    base = np.array([0.30, 0.21, 0.14])
    band = np.array([0.38, 0.27, 0.17])
    clay = np.array([0.44, 0.30, 0.18])
    col = base[None, None] * (1 - strata[..., None] * 0.6) + band[None, None] * (strata[..., None] * 0.6)
    col = col * (1 - 0.25 * depth[..., None]) + (clay - base)[None, None] * (smooth(n2, 0.6, 0.8)[..., None] * 0.5)
    col *= (0.80 + 0.40 * n3)[..., None]
    blot = smooth(fbm(H, W, 51, (32, 16, 8)), 0.55, 0.75)
    col = col * (1 - 0.35 * blot[..., None])
    vein = smooth(0.06 - np.abs(np.sin((yy * 0.7 + 40 * n1 + xx * 0.08) / 9.0)) * 0.5, 0, 0.06)
    col = col + np.array([0.08, 0.06, 0.03]) * vein[..., None]
    col = col * 0.85
    # liseré : la terre éclairée en bord de galerie, plus sombre juste derrière
    rim = smooth(3.5 - d_air, 0, 3.5)
    col = col * (1 + 0.35 * rim[..., None])
    col *= (0.75 + 0.25 * smooth(d_air, 0, 10))[..., None] * (1 - 0.0 * rim[..., None]) + 0.25 * rim[..., None] * 0
    # sol de galerie : un liseré plus clair (terre tassée), un peu de mousse sur la version verte
    top = np.zeros_like(soil); top[1:] = soil[1:] & vis[:-1]
    lip = ndimage.binary_dilation(top, structure=np.array([[0], [1], [1]]), iterations=1) & soil
    col[lip] = col[lip] * 1.25 + np.array([0.03, 0.02, 0.0])
    if green:
        moss = (lip | (rim > 0.6)) & (n3 > 0.45)
        col[moss] = col[moss] * 0.55 + np.array([0.10, 0.24, 0.07])
    img[..., :3] = np.where(soil[..., None], col, 0)
    # 4) le fond des galeries : terre plus sombre, ombre près des parois, maillage de racines
    back = np.array([0.20, 0.14, 0.10]) * (0.8 + 0.4 * n2[..., None]) * (0.9 + 0.2 * n3[..., None])
    ao = 0.30 + 0.70 * smooth(d_soil, 0, 30)
    back = back * ao[..., None] * 0.75
    fib = np.abs(np.sin((xx + 9 * np.sin(yy / 13.0 + 6 * n2)) / 5.0 + 20 * n3))
    back *= (1 - 0.22 * smooth(0.15 - fib, 0, 0.15) * smooth(n2, 0.4, 0.6))[..., None]
    back *= (1 - 0.3 * smooth(fbm(H, W, 61, (24, 12)), 0.55, 0.8))[..., None]
    img[..., :3] = np.where(vis[..., None], back, img[..., :3])
    img[..., 3] = np.where(paintable, 1.0, 0.0)
    out = img.copy()

    def blend(y, x, rgb, a=1.0):
        if 0 <= y < H and 0 <= x < W and paintable[y, x]:
            out[y, x, :3] = out[y, x, :3] * (1 - a) + np.array(rgb) * a

    # 5) cailloux pris dans la terre
    for _ in range(int(W * H / 700)):
        cx, cy = rng.integers(0, W), rng.integers(0, H)
        if not soil[cy, cx] or d_air[cy, cx] > 48: continue
        if strata[cy, cx] < 0.55 and rng.random() < 0.8: continue     # les cailloux suivent les lits
        rx = int(rng.choice([1, 2, 3, 4, 6, 8], p=[.3, .3, .18, .12, .06, .04])); ry = max(1, int(rx * rng.uniform(0.5, 0.8)))
        g = rng.uniform(0.26, 0.42)
        tint = np.array([g, g * 0.93, g * 0.85]) if rng.random() < 0.7 else np.array([g * 1.1, g * 0.8, g * 0.55])
        for dy in range(-ry, ry + 1):
            for dx in range(-rx, rx + 1):
                q = (dx / rx) ** 2 + (dy / ry) ** 2
                if q <= 1 and 0 <= cy + dy < H and 0 <= cx + dx < W and soil[cy + dy, cx + dx]:
                    light = 1.15 - 0.35 * (dy / ry) - 0.15 * (dx / rx)
                    blend(cy + dy, cx + dx, tint * light * (0.9 if q > 0.7 else 1.0))
        blend(cy + ry + 1, cx, (0.12, 0.08, 0.05), 0.6)
    # 6) grosses racines qui traversent la terre (courbes de Bézier, écorce claire dessus)
    def bezier(p0, p1, p2, p3, n=200):
        t = np.linspace(0, 1, n)[:, None]
        return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3
    def root(pts, w0, w1, dark=(0.17, 0.11, 0.07), lite=(0.42, 0.30, 0.20), only_soil=True):
        P = bezier(*[np.array(p, float) for p in pts])
        for i, (px, py) in enumerate(P):
            w = w0 + (w1 - w0) * i / len(P)
            for dy in range(-int(w) - 1, int(w) + 2):
                for dx in (-1, 0, 1):
                    y, x = int(py + dy), int(px + dx)
                    if not (0 <= y < H and 0 <= x < W): continue
                    if only_soil and not soil[y, x]: continue
                    if abs(dy) <= w:
                        f = (dy + w) / (2 * w + 1e-6)
                        c = np.array(lite) * (1 - f) + np.array(dark) * f
                        blend(y, x, c * (0.9 + 0.2 * n3[y, x]))
    for _ in range(int(W / 70)):
        x0 = rng.uniform(-40, W); y0 = rng.uniform(4, H * 0.6)
        L_ = rng.uniform(80, 220)
        pts = [(x0, y0), (x0 + L_ * 0.3, y0 + rng.uniform(-14, 22)), (x0 + L_ * 0.7, y0 + rng.uniform(-10, 30)), (x0 + L_, y0 + rng.uniform(0, 40))]
        root(pts, rng.uniform(2, 4), rng.uniform(0.6, 1.5))
    # 7) radicelles qui pendent de la voûte (dans le vide, fines, ondulées)
    ceil = np.zeros_like(vis); ceil[1:] = vis[1:] & soil[:-1]
    ys, xs = np.nonzero(ceil)
    order = rng.permutation(len(xs))
    for i in order[: len(xs) // 3]:
        x, y = xs[i], ys[i]
        length = int(rng.choice([3, 4, 5, 6, 8, 12, 18, 26], p=[.2, .2, .16, .14, .12, .1, .05, .03]))
        ph, fq = rng.uniform(0, 6.28), rng.uniform(0.15, 0.35)
        shade = rng.uniform(0.75, 1.15)
        for k in range(length):
            px = int(round(x + 1.3 * np.sin(ph + k * fq) * (k / max(length, 1))))
            py = y + k
            if py >= H or not vis[py, min(max(px, 0), W - 1)]: break
            a = 1.0 - 0.6 * k / length
            blend(py, px, (0.36 * shade, 0.26 * shade, 0.17 * shade), a)
        if green and length >= 8 and rng.random() < 0.5:
            blend(min(y + length - 1, H - 1), x, (0.30, 0.55, 0.20), 0.9)
    # 8) petits cailloux et brindilles sur le sol des galeries
    top_y, top_x = np.nonzero(floor_px & vis)
    for i in rng.permutation(len(top_x))[: len(top_x) // 9]:
        x, y = top_x[i], top_y[i]
        if rng.random() < 0.6:
            g = rng.uniform(0.3, 0.5)
            blend(y, x, (g, g * 0.95, g * 0.85)); blend(y, x + 1, (g * 0.8, g * 0.75, g * 0.7))
            if rng.random() < 0.4: blend(y - 1, x, (g * 1.1, g * 1.05, g * 0.95))
        else:
            for k in range(rng.integers(3, 7)):
                blend(y - (k // 3), x + k, (0.38, 0.27, 0.16), 0.9)
    # fondu vers la terre des tuiles, aux bords droit et bas de la région
    edge = np.minimum(W - 1 - xx, H - 1 - yy)
    fade = np.where(soil, smooth(edge, 0, 28), 1.0)
    fade = fade * np.where(cave, 1.0, smooth(yy, 4, 9))          # l'herbe des tuiles du dessus reste visible
    out[..., 3] = out[..., 3] * fade
    # 9) un grain fin, pour ôter l'aspect lisse
    grain = (rng.random((H, W)) - 0.5) * 0.05
    out[..., :3] = np.clip(out[..., :3] + grain[..., None], 0, 1)
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    dest = sys.argv[1] if len(sys.argv) > 1 else "."
    paint(False).save(os.path.join(dest, "souterrain.png"))
    paint(True).save(os.path.join(dest, "souterrain_green.png"))
    print("souterrain.png", L.CAVE_REGION)
