"""Habillages détaillés de la forêt (deuxième passe) : ce qui doit se lire comme du vivant
et non comme des blocs de terre.

  tunnel_back.png  (32 × 32, raccordable)  paroi du fond d'un tunnel creusé sous les racines :
                   terre sombre, radicelles, cailloux, une humidité qui luit à peine
  root_ceiling.png (32 × 32, raccordable)  voûte de grosses racines entrelacées, en relief
                   (ombre portée sous chaque racine, reflets sur le dessus)
  root_fringe.png  (32 × 14, raccord horizontal) radicelles et mousse qui pendent sous la voûte
  root_arch.png    (56 × 96) l'embouchure du tunnel : de grosses racines qui plongent de la
                   voûte jusqu'au sol en arc (retournée pour l'autre bout)
  porch_log.png    (208 × 80) le tronc couché du porche du sous-bois : écorce en relief,
                   bout cassé hérissé d'échardes, autre bout scié, mousse, fougères et lianes
  trunk_col.png    (48 × 64, raccord vertical) fût d'un arbre géant : volume cylindrique,
                   côtes d'écorce, coulures de mousse, lichens
  trunk_wide.png   (80 × 64, raccord vertical) le même, plus large
  branch_h.png     (32 × 20, raccord horizontal) grosse branche qui sert d'appui : ronde,
                   écorce, mousse sur le dessus, quelques feuilles qui pendent
  branch_cap_l.png / branch_cap_r.png (12 × 20) les bouts de la branche (cassés)
"""
import math, random, sys
import numpy as np
from PIL import Image, ImageDraw

OUT = sys.argv[1]
BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def C(h): return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.uint8)


BARK = [C(c) for c in ("0f0b09", "1b1410", "281e17", "362920", "45352a", "564336", "6a5444", "806852")]
EARTH = [C(c) for c in ("0c0907", "15100c", "1e1711", "281f17", "33281e")]
ROOT = [C(c) for c in ("140e0a", "22180f", "332417", "463220", "5c432c", "755838", "8e6e48")]
MOSS = [C(c) for c in ("1a3019", "264524", "35602f", "4a7a3e", "65984e")]
LICHEN = [C(c) for c in ("6f7562", "8c917c", "a8ad96")]
OUTL = C("0a0706")


def q(val, pal, h, w, x0=0, y0=0):
    yy, xx = np.mgrid[0:h, 0:w]
    return np.clip(np.floor(val * (len(pal) - 1) + BAY[(yy + y0) % 4, (xx + x0) % 4]), 0, len(pal) - 1).astype(int)


def canvas(w, h):
    return np.zeros((h, w, 4), np.uint8)


def put(img, mask, val, pal):
    idx = q(val, pal, img.shape[0], img.shape[1])
    for i, c in enumerate(pal):
        sel = mask & (idx == i)
        img[sel, :3] = c
        img[sel, 3] = 255


def save(img, name):
    Image.fromarray(img, "RGBA").save(f"{OUT}/{name}.png")


def wrap_noise(h, w, scale, seed):
    """Bruit lisse raccordable (somme de sinus à périodes entières)."""
    r = random.Random(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    v = np.zeros((h, w))
    for k in range(6):
        fx, fy = r.randint(1, 3) * scale, r.randint(1, 3) * scale
        v += np.sin(2 * np.pi * (xx * fx / w + yy * fy / h) + r.uniform(0, 6)) / (k + 1)
    return v / 2.5


# ------------------------------------------------------------------ paroi du fond du tunnel
def tunnel_back():
    h = w = 32
    img = canvas(w, h)
    n = wrap_noise(h, w, 1, 4)
    put(img, np.ones((h, w), bool), np.clip(0.45 + 0.35 * n, 0, 1), EARTH)
    r = random.Random(8)
    yy, xx = np.mgrid[0:h, 0:w]
    for k in range(5):                                 # radicelles qui traversent la terre
        x, y = r.uniform(0, w), r.uniform(0, h)
        for j in range(20):
            xi, yi = int(x) % w, int(y) % h
            img[yi, xi, :3] = ROOT[2] if j % 3 else ROOT[3]
            x += r.uniform(-0.6, 1.2); y += r.uniform(0.3, 1.0)
    for k in range(6):                                 # cailloux pris dans la paroi
        x, y = r.randrange(w), r.randrange(h)
        img[y, x, :3] = C("3d3329"); img[(y + 1) % h, x, :3] = EARTH[0]
        img[y, (x + 1) % w, :3] = C("4e4337")
    for k in range(3):                                 # gouttes d'humidité qui luisent à peine
        x, y = r.randrange(w), r.randrange(h)
        img[y, x, :3] = C("4a5a5a")
    save(img, "tunnel_back")


# ------------------------------------------------------------------ voûte de racines
def root_ceiling():
    """Voûte de racines (64 × 32, raccordable) : des racines de toutes épaisseurs, qui
    plongent et remontent en se croisant, avec de la terre sombre entre elles. Chaque racine
    est un cylindre éclairé par le dessus, qui projette une ombre sur celles de derrière."""
    w, h = 64, 32
    img = canvas(w, h)
    put(img, np.ones((h, w), bool), np.clip(0.3 + 0.3 * wrap_noise(h, w, 1, 9), 0, 1), EARTH)
    yy, xx = np.mgrid[0:h, 0:w]
    r = random.Random(13)
    for k in range(9):
        th = r.choice((1.6, 2.2, 2.8, 3.4, 4.2))
        y0 = r.uniform(0, h)
        # une courbe raccordable : somme de deux sinus à périodes entières sur la largeur
        a1, a2 = r.uniform(2, 7), r.uniform(1, 3)
        p1, p2 = r.uniform(0, 6), r.uniform(0, 6)
        f1 = r.choice((1, 1, 2))
        cy = y0 + a1 * np.sin(2 * np.pi * f1 * xx / w + p1) + a2 * np.sin(2 * np.pi * 3 * xx / w + p2)
        d = (yy - cy + h / 2) % h - h / 2
        body = np.abs(d) < th
        shadow = (d >= th) & (d < th + 2.5)
        sel = shadow & ~body
        img[sel, :3] = (img[sel, :3] * 0.5).astype(np.uint8)
        val = 0.55 - 0.4 * d / th + 0.07 * np.sin(xx * 0.9 + k * 2)
        put(img, body, np.clip(val, 0, 1), ROOT)
        rim = body & (d < -th + 0.9)
        img[rim, :3] = ROOT[6]
    for k in range(20):
        x, y = r.randrange(w), r.randrange(h)
        img[y, x, :3] = MOSS[r.randrange(1, 4)] if r.random() < 0.6 else ROOT[1]
    save(img, "root_ceiling")


def root_fringe():
    w, h = 32, 14
    img = canvas(w, h)
    r = random.Random(5)
    for x in range(w):
        img[0, x] = (*ROOT[3], 255)
        img[1, x] = (*(MOSS[2] if x % 5 else MOSS[1]), 255)
    for k in range(16):                                 # radicelles qui pendent, de longueurs variées
        x = r.randrange(w); L = r.randint(3, 13)
        for j in range(L):
            xi = (x + (1 if j > L * 0.6 and k % 3 == 0 else 0)) % w
            img[1 + j, xi] = (*(ROOT[4] if j < L - 2 else ROOT[2]), 255)
        if r.random() < 0.4:
            img[min(h - 1, L), x] = (*C("6a7a6a"), 255)       # une gouttelette au bout
    for k in range(6):                                  # touffes de mousse qui pendent
        x = r.randrange(w)
        for j in range(r.randint(2, 4)):
            img[1 + j, x] = (*MOSS[3 - min(j, 2)], 255)
            img[1 + j, (x + 1) % w] = (*MOSS[2], 255)
    save(img, "root_fringe")


def root_arch():
    """L'embouchure : trois grosses racines qui descendent de la voûte et se plantent au sol."""
    w, h = 56, 96
    img = canvas(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    r = random.Random(11)
    for k, (x_top, x_bot, th) in enumerate(((30, 6, 6.0), (40, 18, 5.0), (50, 30, 4.0), (22, 2, 4.5))):
        pts = []
        for j in range(30):
            t = j / 29
            x = x_top + (x_bot - x_top) * (t ** 1.6) + 2 * math.sin(t * 7 + k)
            pts.append((x, t * (h - 1)))
        im = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(im)
        for j in range(29):
            wj = th * (0.7 + 0.5 * (j / 29))           # elles s'épaississent vers le sol
            d.line([pts[j], pts[j + 1]], fill=255, width=int(wj * 2))
        m = np.array(im) > 127
        # volume : lumière à gauche
        cx = np.interp(yy, [p[1] for p in pts], [p[0] for p in pts])
        u = np.clip((xx - cx) / (th * 1.4), -1, 1)
        val = 0.5 - 0.35 * u + 0.08 * np.sin(yy * 0.8 + k)
        put(img, m, np.clip(val, 0, 1), ROOT)
    for k in range(40):                                  # mousse
        x, y = r.randrange(w), r.randrange(h)
        if img[y, x, 3]:
            img[y, x, :3] = MOSS[r.randrange(1, 4)]
    a = img[..., 3] > 0
    o = np.zeros_like(a)
    o[1:] |= a[:-1]; o[:-1] |= a[1:]; o[:, 1:] |= a[:, :-1]; o[:, :-1] |= a[:, 1:]
    o &= ~a; o[-2:] = False
    img[o] = (*OUTL, 255)
    save(img, "root_arch")


# ------------------------------------------------------------------ le tronc couché du porche
def porch_log():
    w, h = 208, 80
    img = canvas(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    cy, R = 40, 30
    x0, x1 = 10, 196
    # le fût : un cylindre couché
    body = (np.abs(yy - cy) < R) & (xx > x0) & (xx < x1)
    # bout gauche cassé : dents d'échardes ; bout droit scié net (ellipse des cernes)
    jag = x0 + 6 * np.abs(np.sin(yy * 0.5)) + 3 * np.abs(np.sin(yy * 1.3))
    body &= xx > jag
    v = 1 - np.abs(yy - (cy - 8)) / (R + 8)              # la lumière tombe d'en haut
    ridge = np.sin(2 * np.pi * (yy / 7.0 + 0.1 * np.sin(xx / 13.0)))
    val = 0.12 + 0.62 * np.clip(v, 0, 1) + 0.12 * ridge
    val[ridge < -0.82] = 0.0
    put(img, body, np.clip(val, 0, 1), BARK)
    # la coupe sciée (à droite) : cernes concentriques, cœur sombre
    cut = ((xx - x1) / 8.0) ** 2 + ((yy - cy) / R) ** 2 < 1
    rings = np.sin(np.hypot((xx - x1) * 3.5, yy - cy) * 0.9)
    put(img, cut, np.clip(0.55 + 0.25 * rings, 0, 1), [C("3a2a1c"), C("5a442e"), C("7a5e40"), C("94784f")])
    core = ((xx - x1) / 2.5) ** 2 + ((yy - cy) / 8) ** 2 < 1
    img[core, :3] = C("2a1e14")
    # échardes claires au bout cassé
    r = random.Random(7)
    for k in range(10):
        y = r.randint(cy - R + 3, cy + R - 3); L = r.randint(4, 10)
        for j in range(L):
            xi = int(jag[y, 0]) - j // 2
            if 0 <= xi < w: img[y, xi] = (*C("8a7050"), 255)
    # mousse épaisse sur le dessus, avec des touffes qui débordent
    for x in range(x0 + 6, x1):
        top = None
        for y in range(h):
            if img[y, x, 3]:
                top = y; break
        if top is None: continue
        thick = 2 + int(2 * (0.5 + 0.5 * math.sin(x * 0.21)) + (1 if x % 7 == 0 else 0))
        for j in range(thick):
            img[top - 1 + j, x] = (*MOSS[min(4, 3 - j + (1 if x % 3 == 0 else 0))], 255)
        if r.random() < 0.08:                            # une pousse de fougère sur le tronc
            for j in range(r.randint(3, 6)):
                img[top - 2 - j, x + (j % 2)] = (*MOSS[3], 255)
    # lianes qui pendent du tronc
    for k in range(5):
        x = r.randint(x0 + 15, x1 - 10); L = r.randint(12, 34)
        for j in range(L):
            yi = cy + R - 2 + j
            if yi < h:
                img[yi, x + int(1.5 * math.sin(j * 0.3))] = (*MOSS[1 if j % 4 else 2], 255)
                if j % 6 == 3 and yi < h:
                    img[yi, x + 2] = (*MOSS[3], 255)
    # champignons-consoles sur le flanc
    for (x, y) in ((70, cy + 12), (78, cy + 16), (140, cy + 8)):
        for dx in range(-4, 5):
            for dy in range(0, 3):
                if dx * dx / 16 + dy * dy / 4 <= 1:
                    img[y + dy, x + dx] = (*C("b08a5a" if dy == 0 else "7a5a3a"), 255)
    a = img[..., 3] > 0
    o = np.zeros_like(a)
    o[1:] |= a[:-1]; o[:-1] |= a[1:]; o[:, 1:] |= a[:, :-1]; o[:, :-1] |= a[:, 1:]
    o &= ~a
    img[o] = (*OUTL, 255)
    save(img, "porch_log")


# ------------------------------------------------------------------ fûts d'arbres géants
def trunk(w, name, seed):
    h = 64
    img = canvas(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx + 0.5) / w                                   # 0 à gauche, 1 à droite
    cyl = np.sin(np.pi * u) ** 0.6 * (1 - 0.55 * u)      # volume : lumière venue de la gauche
    per = max(3, w // 8)
    ridge = np.sin(2 * np.pi * (xx / (w / per) + 0.18 * np.sin(2 * np.pi * yy / h)))
    val = 0.08 + 0.7 * cyl + 0.13 * ridge
    val[ridge < -0.8] = 0.0
    put(img, np.ones((h, w), bool), np.clip(val, 0, 1), BARK)
    r = random.Random(seed)
    # coulures de mousse côté ombre, lichens côté lumière (raccord vertical : on boucle)
    for k in range(w // 6):
        x = int(w * r.uniform(0.55, 0.95)); y = r.randrange(h); L = r.randint(8, 30)
        for j in range(L):
            yi = (y + j) % h
            img[yi, x] = (*MOSS[2 if j % 3 else 1], 255)
            if j % 4 == 0 and x + 1 < w: img[yi, x + 1] = (*MOSS[1], 255)
    for k in range(w // 3):
        x = int(w * r.uniform(0.08, 0.5)); y = r.randrange(h)
        img[y, x] = (*LICHEN[r.randrange(3)], 255)
        if x + 1 < w: img[y, x + 1] = (*LICHEN[0], 255)
    # bords : une ligne sombre (le fût se détache du fond)
    img[:, 0] = (*OUTL, 255); img[:, w - 1] = (*OUTL, 255)
    img[:, w - 2, :3] = (img[:, w - 2, :3] * 0.6).astype(np.uint8)
    save(img, name)


# ------------------------------------------------------------------ grosse branche d'appui
def branch():
    w, h = 32, 20
    img = canvas(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    body = (yy >= 2) & (yy <= 13)
    v = 1 - np.abs(yy - 5) / 9.0
    ridge = np.sin(2 * np.pi * (yy / 4.0 + 0.12 * np.sin(2 * np.pi * xx / w)))
    val = 0.15 + 0.6 * np.clip(v, 0, 1) + 0.1 * ridge
    put(img, body, np.clip(val, 0, 1), BARK)
    img[14, :] = (*OUTL, 255)
    r = random.Random(4)
    for x in range(w):                                  # mousse sur le dessus (l'appui)
        img[1, x] = (*MOSS[2 if x % 4 else 3], 255)
        img[2, x] = (*MOSS[1 if x % 3 else 2], 255)
        if x % 5 == 2: img[0, x] = (*MOSS[3], 255)
    for k in range(4):                                  # feuilles et lianes qui pendent dessous
        x = r.randrange(w); L = r.randint(2, 5)
        for j in range(L):
            img[15 + j if 15 + j < h else h - 1, x] = (*MOSS[2 if j < L - 1 else 3], 255)
    for x in (7, 23):                                    # nœuds
        img[7, x] = (*BARK[1], 255); img[8, x + 1] = (*BARK[0], 255)
    save(img, "branch_h")
    for side, name in ((-1, "branch_cap_l"), (1, "branch_cap_r")):
        cw = 12
        cap = canvas(cw, h)
        for y in range(2, 14):
            L = int(5 + 3 * abs(math.sin(y * 1.3)) + (3 if y in (5, 9) else 0))   # bout cassé, échardes
            for j in range(L):
                x = j if side > 0 else cw - 1 - j
                if side > 0:
                    x = j
                else:
                    x = cw - 1 - j
                vv = 0.15 + 0.6 * max(0, 1 - abs(y - 5) / 9.0)
                cap[y, x] = (*BARK[int(vv * 7)], 255)
            xe = (L if side > 0 else cw - 1 - L)
            if 0 <= xe < cw: cap[y, xe] = (*OUTL, 255)
        for x in range(cw):
            if cap[2, x, 3]: cap[1, x] = (*MOSS[2], 255)
        cap[14, :] = np.where(cap[13, :, 3:4] > 0, np.array([*OUTL, 255]), cap[14, :])
        save(cap, name)


if __name__ == "__main__":
    tunnel_back(); root_ceiling(); root_fringe(); root_arch(); porch_log()
    trunk(48, "trunk_col", 1); trunk(80, "trunk_wide", 2); branch()
    names = ["tunnel_back", "root_ceiling", "root_fringe", "root_arch", "porch_log", "trunk_col", "trunk_wide", "branch_h", "branch_cap_l", "branch_cap_r"]
    prev = Image.new("RGBA", (700, 260), (40, 58, 52, 255)); x = 4
    for n in names:
        im = Image.open(f"{OUT}/{n}.png"); prev.alpha_composite(im, (x, 4)); x += im.width + 6
    prev.resize((1400, 520), Image.NEAREST).save(f"{OUT}/details_prev.png")
