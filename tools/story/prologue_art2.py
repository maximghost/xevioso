"""Tableaux du prologue (suite) : l'orage, le ciel d'Adaka, la terre craquelée, le Fa, le bélier.

  orage.png / orage_eclair.png   (800 × 360)  cumulonimbus de nuit ; la même vue éclairée de
                                 l'intérieur par la foudre (le jeu passe de l'une à l'autre)
  couvercle.png                  (800 × 360)  le ciel d'Adaka : un couvercle noir de nuages
                                 avalés, veiné de rouge (les veines pulsent dans le jeu)
  veines.png                     (800 × 360)  les veines seules (calque additif)
  terre_craquelee.png            (640 × 360)  gros plan : la terre de Sakpata craquelée,
                                 un épi de mil mort, un caillou (la sécheresse)
  fa.png                         (640 × 360)  gros plan : la natte du devin, le chapelet du Fa
                                 (huit demi-coques sur une chaîne), noix de cola, lampe à huile
  belier_nuage.png               (420 × 260)  le bélier de Xɛvioso dessiné dans les nuages,
                                 éclairé par la foudre (il paraît au moment de l'appel)
  belier.png                     (24 × 20 × 4)  bélier qui broute (deux poses) et qui relève la tête
(Éléments culturels à faire valider : le Fa, le bélier, les signes.)

Utilisation : python3 prologue_art2.py DOSSIER_SORTIE
"""
import math, os, random, sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from painter import Canvas, C, mix, smooth, fbm, relief, light, edge_toward, save, stroke, bezier

H = 360


def cumulus_field(W, seed, base_y=250, top=20):
    """Un champ de cumulonimbus : bosses arrondies empilées (hauteur → relief)."""
    r = random.Random(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    hgt = np.zeros((H, W))
    for _ in range(70):
        cx = r.uniform(-40, W + 40)
        cy = r.uniform(top + 30, base_y)
        rad = r.uniform(30, 90) * (1.2 - (cy - top) / (base_y - top) * 0.5)
        d = np.sqrt((xx - cx) ** 2 + ((yy - cy) * 1.25) ** 2)
        hgt = np.maximum(hgt, np.sqrt(np.clip(1 - (d / rad) ** 2, 0, 1)) * rad)
    hgt += fbm(H, W, seed + 1, (24, 12, 6, 3)) * 14
    return hgt


def storm(lit):
    W = 800
    cv = Canvas(W, H)
    sky = mix(C("04040a"), C("10101c"), smooth(cv.yy, 0, H))
    cv.fill(np.ones((H, W), bool), sky)
    hgt = ndimage.gaussian_filter(cumulus_field(W, 11), 6)
    n = fbm(H, W, 12, (20, 10, 5, 2))
    dens = smooth(hgt + n * 18 * smooth(hgt, 2, 12), 8, 26)  # densité : bords vaporeux, ciel net
    v = light(hgt + n * 6, dens > 0.01, (0.25, -0.8, 0.55), 0.12)
    if not lit:
        col = mix(C("0a0a14"), C("343450"), v * 0.9)
        cv.fill(dens > 0.01, col, dens)
    else:
        inner = smooth(hgt, 15, 80)
        glow = np.clip(v * 0.55 + inner * 0.65 - n * 0.15, 0, 1)
        col = mix(C("1a2040"), C("dce6ff"), glow)
        cv.fill(dens > 0.01, col, dens)
        cv.fill(dens > 0.01, C("f4f8ff"), np.clip((dens - np.roll(dens, 2, 0)) * 3, 0, 1) * 0.8)
    cv.a[:] = 1
    return cv


def lid():
    """Le couvercle d'Adaka : nuages noirs écrasés, tordus, veinés de rouge."""
    W = 800
    cv = Canvas(W, H)
    n = fbm(H, W, 21, (90, 45, 22, 11))
    swirl = fbm(H, W, 22, (40, 20, 10))
    base = mix(C("050304"), C("1e1012"), n)
    cv.fill(np.ones((H, W), bool), base)
    hgt = (n * 30 + swirl * 12) * (1 - smooth(cv.yy, 210, 300))
    v = light(hgt, np.ones((H, W), bool), (0.0, 1.0, 0.6), 0.1)       # éclairé par en dessous (rougeoiement)
    cv.fill(np.ones((H, W), bool), C("5a1810"), v * 0.45 * (1 - smooth(cv.yy, 250, 330)))
    # sous le couvercle, une bande de ciel malade, couleur de cendre et de braise
    cv.fill(cv.yy > 250, mix(C("3a2018"), C("8a4a2a"), smooth(cv.yy, 250, 330)), smooth(cv.yy, 240, 300))
    cv.a[:] = 1
    veins = Canvas(W, H)
    big = fbm(H, W, 23, (120, 60, 30))
    vv = (np.abs(big - 0.5) < 0.006) & (fbm(H, W, 25, (90, 45)) > 0.5)
    vv |= (np.abs(fbm(H, W, 24, (70, 35, 18)) - 0.5) < 0.004) & (fbm(H, W, 26, (80, 40)) > 0.6)
    vv &= cv.yy < 245
    glow = ndimage.gaussian_filter(vv.astype(float), 2.0)
    veins.fill(np.ones((H, W), bool), C("ff3a1a"), np.clip(glow * 3, 0, 1))
    veins.fill(vv, C("ffb070"))
    veins.a = np.clip(glow * 3 + vv, 0, 1)
    return cv, veins


def cracked_earth():
    W = 640
    cv = Canvas(W, H)
    # perspective : le sol fuit vers un horizon brûlé en haut
    horizon = 70
    sky = mix(C("d8a060"), C("f0c888"), smooth(cv.yy, 0, horizon))
    cv.fill(cv.yy < horizon, sky)
    g = cv.yy >= horizon
    depth = np.clip((cv.yy - horizon) / (H - horizon), 0.02, 1)
    # les plaques : un diagramme de Voronoï écrasé par la perspective
    r = np.random.default_rng(31)
    pts = []
    for _ in range(900):
        y = horizon + (r.random() ** 1.6) * (H - horizon)
        pts.append((r.uniform(-20, W + 20), y))
    pts = np.array(pts)
    from scipy.spatial import cKDTree
    t = cKDTree(np.c_[pts[:, 0], (pts[:, 1] - horizon) * 3.0])
    q = np.c_[cv.xx.ravel(), ((cv.yy - horizon) * 3.0 / np.maximum(depth, 0.05) ** 0.0).ravel()]
    d, idx = t.query(q, k=2)
    gap = (d[:, 1] - d[:, 0]).reshape(H, W)
    crack_w = 1.2 + 6 * depth
    crack = g & (gap < crack_w)
    plate_id = idx[:, 0].reshape(H, W)
    tone = (np.sin(plate_id * 12.9898) * 0.5 + 0.5)
    tex = fbm(H, W, 32, (12, 6, 3))
    soil = mix(C("8a5030"), C("c8885a"), (0.5 * tone + 0.5 * tex))
    # chaque plaque se gondole : ses bords se relèvent, éclairés côté soleil
    edge_up = smooth(-gap, -crack_w * 2.5, -crack_w)
    cv.fill(g, soil)
    cv.fill(g & ~crack, C("f4d0a0"), edge_up * 0.35 * depth)
    cv.fill(crack, C("1a0c08"))
    cv.fill(g, C("e8b070"), (1 - depth) * 0.45)                         # brume de chaleur au loin
    # un épi de mil mort couché, un caillou (premier plan)
    stalk = stroke(cv, [(120, 330), (220, 300), (330, 288)], 3.5, 1.5)
    head = stroke(cv, [(320, 290), (350, 284), (372, 282)], 6, 3)
    for k in range(18):
        x = 322 + k * 2.6
        head |= cv.ellipse(x - 2, 280 + (k % 3) - 3, x + 2, 288 + (k % 3))
    lv = light(relief(stalk | head, 3), stalk | head, (0.6, -0.6, 0.5), 0.3)
    cv.fill(stalk | head, mix(C("5a4026"), C("c8a870"), lv))
    stone = cv.ellipse(470, 300, 540, 340)
    sv = light(relief(stone, 14), stone, (0.6, -0.6, 0.5), 0.25)
    cv.fill(stone, mix(C("3a3028"), C("a89880"), sv))
    cv.fill(cv.ellipse(468, 332, 548, 348) & ~stone, C("2a160c"), 0.5)
    cv.a[:] = 1
    return cv


def fa_closeup():
    """La natte du devin, éclairée par une lampe à huile ; le chapelet du Fa ; la cola."""
    W = 640
    cv = Canvas(W, H)
    lamp = (520, 120)
    d = np.sqrt((cv.xx - lamp[0]) ** 2 + ((cv.yy - lamp[1]) * 1.2) ** 2)
    glow = np.clip(1 - d / 520, 0, 1) ** 1.6
    # la natte tressée, en perspective
    rows = (cv.yy * 0.5).astype(int)
    weave = ((np.sin(cv.xx * 0.9 + (rows % 2) * math.pi) > 0) ^ ((cv.yy.astype(int) % 2) == 0)) * 1.0
    fib = fbm(H, W, 61, (4, 2))
    straw = mix(C("4a3014"), C("d0a058"), 0.3 + 0.3 * weave + 0.25 * fib)
    cv.fill(np.ones((H, W), bool), straw * (0.15 + 0.95 * glow[..., None]))
    border = (cv.yy > 300) & (cv.yy < 312)
    cv.fill(border, C("8a1a12") * (0.2 + 0.9 * glow[..., None]))
    # le chapelet (agumaga) : deux branches de quatre demi-coques reliées par une chaîne
    chain = np.zeros((H, W), bool)
    shells = np.zeros((H, W), bool)
    up = [True, False, True, True, False, True, False, False]       # le signe tiré (à valider)
    for branch, (x0, y0, x1, y1) in enumerate(((210, 120, 150, 300), (300, 115, 360, 300))):
        P = bezier([(255, 95), (x0, y0), (x1, y1)], 60)
        for j in range(len(P) - 1):
            chain |= stroke(cv, [tuple(P[j]), tuple(P[j + 1])], 1.0, 1.0)
        for k in range(4):
            px, py = P[12 + k * 12]
            sh = cv.ellipse(px - 12, py - 8, px + 12, py + 8)
            shells |= sh
            face_up = up[branch * 4 + k]
            hv = light(relief(sh, 6), sh, (0.6, -0.5, 0.6), 0.25)
            col = mix(C("4a2a14"), C("c8925a"), hv) if face_up else mix(C("2a160a"), C("7a4a28"), hv)
            cv.fill(sh, col * (0.35 + 0.8 * glow[..., None]))
            if face_up:
                inside = cv.ellipse(px - 7, py - 4, px + 7, py + 4)
                cv.fill(inside, C("e8d0a0") * (0.3 + 0.8 * glow[..., None]))
    cv.fill(chain & ~shells, C("b08a40") * (0.3 + 0.9 * glow[..., None]))
    # noix de cola (rouges et blanches), cauris
    for (x, y, col) in ((420, 250, C("b03a2a")), (446, 262, C("e8d8b8")), (432, 276, C("9a2a20"))):
        k = cv.ellipse(x - 12, y - 9, x + 12, y + 9)
        kv = light(relief(k, 7), k, (0.6, -0.5, 0.6), 0.3)
        cv.fill(k, col * (0.4 + 0.9 * kv[..., None]) * (0.35 + 0.8 * glow[..., None]))
    for (x, y) in ((470, 210), (490, 232), (404, 214)):
        k = cv.ellipse(x - 7, y - 4, x + 7, y + 4)
        cv.fill(k, C("f0e8d8") * (0.4 + 0.8 * glow[..., None]))
        cv.fill(cv.poly([(x - 5, y), (x + 5, y), (x + 5, y + 1), (x - 5, y + 1)]), C("6a5a48"))
    # la lampe à huile en terre et sa flamme (la flamme danse dans le jeu)
    body = cv.ellipse(lamp[0] - 26, lamp[1] + 10, lamp[0] + 26, lamp[1] + 34)
    lv = light(relief(body, 10), body, (-0.4, -0.7, 0.6), 0.25)
    cv.fill(body, mix(C("3a1a0c"), C("b8602e"), lv))
    # le bec et la flamme de la lampe (la flamme danse dans le jeu : ici, la braise du bec)
    spout = cv.poly([(lamp[0] + 20, lamp[1] + 14), (lamp[0] + 40, lamp[1] + 8), (lamp[0] + 40, lamp[1] + 14), (lamp[0] + 22, lamp[1] + 22)])
    cv.fill(spout, C("9a4a22"))
    cv.fill(cv.ellipse(lamp[0] + 34, lamp[1] + 4, lamp[0] + 42, lamp[1] + 12), C("ffd890"))
    cv.fill(cv.ellipse(lamp[0] - 18, lamp[1] + 12, lamp[0] + 14, lamp[1] + 18), C("1a0a04"))    # l'huile
    # le bord du pagne blanc du devin, à gauche, et l'ombre de son bras
    robe = cv.poly([(0, 0), (90, 0), (70, 120), (40, 200), (0, 230)])
    rv = light(relief(robe, 30) + np.sin(cv.yy * 0.12 + cv.xx * 0.05) * 4, robe, (0.8, -0.3, 0.5), 0.25)
    cv.fill(robe, mix(C("3a3430"), C("efe6d4"), rv) * (0.4 + 0.7 * glow[..., None]))
    redband = robe & (np.abs(cv.xx - (70 - cv.yy * 0.2)) < 4)
    cv.fill(redband, C("8a1a12") * (0.4 + 0.7 * glow[..., None]))
    cv.a[:] = 1
    return cv


def ram_cloud():
    """Le bélier de Xɛvioso dans les nuages, tête basse comme pour charger, la grande corne
    enroulée bien visible, éclairé par la foudre."""
    W, Hc = 420, 260
    cv = Canvas(W, Hc)
    body = cv.ellipse(60, 80, 300, 190)
    neck = cv.poly([(250, 90), (320, 110), (330, 160), (270, 175)])
    head = cv.poly([(300, 105), (360, 120), (395, 175), (380, 192), (330, 182), (305, 150)])
    legs = np.zeros((Hc, W), bool)
    for x0, lean in ((90, -10), (140, 6), (220, -8), (262, 10)):
        legs |= cv.poly([(x0, 175), (x0 + 24, 175), (x0 + 22 + lean, 250), (x0 + 6 + lean, 250)])
    tail = cv.ellipse(45, 95, 80, 130)
    sil = body | neck | head | legs | tail
    horn = []
    for j in range(80):
        t = j / 79
        a = -math.pi * 0.35 - t * math.pi * 2.0
        rr = 46 * (1 - 0.62 * t)
        horn.append((318 + math.cos(a) * rr, 122 + math.sin(a) * rr * 0.95))
    hm = stroke(cv, horn, 16, 4)
    d = ndimage.distance_transform_edt(~sil)
    n = fbm(Hc, W, 41, (18, 9, 5))
    cloud = (d < 4 + 12 * n) | sil
    hgt = ndimage.gaussian_filter(relief(cloud, 40), 3) + n * 10
    v = light(hgt, cloud, (0.2, -0.7, 0.6), 0.1)
    inner = smooth(relief(cloud, 60), 5, 50)
    cv.fill(cloud, mix(C("1a2242"), C("aac0f4"), np.clip(v * 0.5 + inner * 0.5, 0, 1)))
    cv.fill(edge_toward(cloud, 0, -1, 2), C("e8f0ff"), 0.8)
    # la corne : plus dense, plus claire, cerclée de stries ; elle accroche l'éclair
    hv = light(relief(hm, 9) + np.sin(np.arange(W)[None, :] * 0.0 + cv.yy * 0.0) * 0, hm, (0.3, -0.7, 0.6), 0.2)
    ridges = hm & (np.sin((cv.xx - 318) * 0.6 + (cv.yy - 122) * 0.6) > 0.6)
    cv.fill(hm, mix(C("5a6aa0"), C("f6f8ff"), hv))
    cv.fill(ridges, C("8090c8"), 0.55)
    cv.fill(edge_toward(hm, 0, -1, 1) | edge_toward(hm, 1, 0, 1), C("ffffff"), 0.9)
    eye = cv.ellipse(352, 140, 362, 148)
    cv.fill(eye, C("ffffff"))
    cv.a = (cloud | hm).astype(float)
    return cv


def ram_sprite():
    """Bélier (24 × 20) : 0, 1 broute ; 2 relève la tête ; 3 regarde."""
    frames = []
    for f in range(4):
        cv = Canvas(24, 20)
        head_down = f in (0, 1)
        body = cv.ellipse(3, 6, 18, 15)
        legs = np.zeros((20, 24), bool)
        for lx in (5, 8, 13, 16):
            legs |= cv.poly([(lx, 13), (lx + 1.6, 13), (lx + 1.6, 19), (lx, 19)])
        if head_down:
            head = cv.ellipse(16, 10 + (f == 1), 23, 16 + (f == 1))
            hx, hy = 19, 11 + (f == 1)
        else:
            head = cv.ellipse(16, 3, 23, 10)
            hx, hy = 19, 4
        wool = fbm(20, 24, 50 + f, (3, 2))
        bv = light(relief(body, 4) + wool * 1.5, body, (0.7, -0.5, 0.5), 0.3)
        cv.fill(legs, C("3a2a20"))
        cv.fill(body, mix(C("6a5a48"), C("e8dcc0"), bv))
        hv = light(relief(head, 3), head, (0.7, -0.5, 0.5), 0.3)
        cv.fill(head, mix(C("3a2a20"), C("8a6a50"), hv))
        horn = np.zeros((20, 24), bool)
        for j in range(12):
            a = j / 11 * math.pi * 1.6
            x, y = hx - 1 + math.cos(a) * 2.6, hy + 1 - math.sin(a) * 2.6 + j * 0.15
            horn[int(round(y)) % 20, int(round(x)) % 24] = True
        cv.fill(horn, C("d8c8a0"))
        cv.rgb[int(hy + 2) % 20, (hx + 2) % 24] = C("100808")
        al = body | legs | head | horn
        o = ndimage.binary_dilation(al) & ~al
        cv.fill(o, C("140c08"))
        cv.a = (al | o).astype(float)
        frames.append(cv)
    sheet = Canvas(24 * 4, 20)
    for i, f in enumerate(frames):
        sheet.rgb[:, i * 24:(i + 1) * 24] = f.rgb
        sheet.a[:, i * 24:(i + 1) * 24] = f.a
    return sheet


def pretre(villagers_png):
    """Le prêtre de Xɛvioso : l'ancien du village (planche villagers.png, lignes 15 à 17), sa
    calotte violette devenue rouge (la couleur de Xɛvioso), un collier de cauris blanc."""
    im = np.asarray(Image.open(villagers_png).convert("RGBA")).copy()
    rows = im[15 * 60:18 * 60, :160].copy()
    rgb = rows[..., :3].astype(int)
    purple = (rgb[..., 2] > rgb[..., 1] + 25) & (rgb[..., 0] > rgb[..., 1]) & (rows[..., 3] > 0)
    lum = rgb[purple].mean(axis=1)
    rows[purple, 0] = np.clip(lum * 1.55 + 40, 0, 255)
    rows[purple, 1] = np.clip(lum * 0.35, 0, 255)
    rows[purple, 2] = np.clip(lum * 0.3, 0, 255)
    return Image.fromarray(rows, "RGBA")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    for name, cv in (("orage", storm(False)), ("orage_eclair", storm(True))):
        save(cv.rgb, cv.a, os.path.join(out, name + ".png"), levels=30)
    c, v = lid()
    save(c.rgb, c.a, os.path.join(out, "couvercle.png"), levels=30)
    save(v.rgb, v.a, os.path.join(out, "veines.png"), levels=30, dither=0.5)
    for name, fn in (("terre_craquelee", cracked_earth), ("fa", fa_closeup), ("belier_nuage", ram_cloud), ("belier", ram_sprite)):
        cv = fn()
        save(cv.rgb, cv.a, os.path.join(out, name + ".png"), levels=30)
    if len(sys.argv) > 2:
        pretre(sys.argv[2]).save(os.path.join(out, "pretre.png"))
    print("tableaux : orage, couvercle, veines, terre craquelée, Fa, bélier")
