"""Le cœur du vieil iroko (fin de la partie 2) et le tabernacle de Xɛvioso.

  grand_iroko.png  (496 × 672)  le plus vieil iroko, vu en coupe : écorce fissurée dehors,
                   creux intérieur (bois de cœur rouge sombre, fil du bois, veines de colère
                   qui luisent), passage d'entrée à gauche, de sortie à droite, sol de racines.
                   _green : les veines deviennent d'or, la mousse revient.
  roue_coeur.png   (64 × 64)  une roue de bois sculptée, dentée (elles s'engrènent)
  canal_coude.png / canal_droit.png (64 × 64)  le sillon de sève creusé dans la roue :
                   coude (du haut vers la droite) ou droit (de gauche à droite)
  racines_colere.png (56 × 60) les racines rouges de la colère, serrées autour de l'éclat
  eclat_foudre.png (14 × 20)  l'éclat de la Pierre de foudre
  tabernacle.png   (128 × 112) le tabernacle de Xɛvioso : case ronde de terre au toit de
                   chaume, autel d'argile où est plantée la hache double, cornes de bélier,
                   pagnes rouge et blanc, jarres. (_green : fleurs, offrandes fraîches)
  (Formes et symboles à faire valider par le conseiller culturel.)

Utilisation : python3 heart.py DOSSIER_DECOR DOSSIER_PROPS
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dlib import Sprite, hexc
from trees3 import fbm, relief, lit, paint, IROKO

DEC = sys.argv[1] if len(sys.argv) > 1 else "."
PROPS = sys.argv[2] if len(sys.argv) > 2 else "."
HEART = [hexc(c) for c in ("12080a", "1f0e0e", "2e1512", "3f1e16", "52291b", "673522", "7c442b")]
OUTL = (14, 9, 8)


def save(sp, path):
    im = np.zeros((sp.h, sp.w, 4), np.uint8); im[..., :3] = sp.rgb; im[..., 3] = sp.a * 255
    Image.fromarray(im, "RGBA").save(path)


# ------------------------------------------------------------------ le grand iroko en coupe
# repères (en pixels de l'image ; l'image commence colonne 598, ligne 0)
IW, IH = 496, 672
IN_X0, IN_X1, IN_Y0, FLOOR = 48, 448, 416, 640     # le creux intérieur
DOOR_H = 64                                          # hauteur des passages (4 cases)


def grand_iroko(healthy):
    s = Sprite(IW, IH)
    tex = fbm(IH, IW, 101, (24, 12, 6)); fiss = fbm(IH, IW, 102, (3,))
    # --- l'écorce, sur toute la largeur (le fût est immense), qui s'évase au pied
    m = np.ones((IH, IW), bool)
    xs = (s.xx - IW / 2) / (IW / 2)
    plates = np.abs(np.sin(xs * 22 + 4.0 * tex + 1.4 * fbm(IH, IW, 106, (40, 20)) * 3 + 0.5 * np.sin(s.yy * 0.021)))
    breaks = np.abs(np.sin(s.yy * 0.17 + fiss * 7 + xs * 4))
    hg = 0.0 * s.xx + 90 * np.sqrt(np.clip(1 - (xs * 0.98) ** 2, 0, 1)) - 4 * (plates < 0.2) - 1.6 * (breaks < 0.07) + 1.2 * fiss
    paint(s, m, lit(hg, m, 0.15) + 0.06 * (tex - 0.5), IROKO)
    # --- le creux : une ouverture organique (voûte arrondie, bord irrégulier, écorce retroussée)
    hole = np.zeros((IH, IW), bool)
    u = np.clip((s.xx - IN_X0) / (IN_X1 - IN_X0), 0, 1)
    top = IN_Y0 - 70 * np.sin(np.pi * u) ** 0.8                 # une voûte, plus haute au milieu
    bulge = 10 * np.sin(np.pi * np.clip((s.yy - top) / (FLOOR - top), 0, 1))
    hole = (s.yy >= top) & (s.yy < FLOOR + 8) & (s.xx >= IN_X0 - bulge) & (s.xx < IN_X1 + bulge)
    hole = ndimage.gaussian_filter(hole.astype(float), 8) > 0.5
    n = fbm(IH, IW, 103, (20, 10, 5))
    hole &= ~((ndimage.distance_transform_edt(hole) < 6 * n) & (s.yy < FLOOR - 4))
    hole[FLOOR - 40:FLOOR + 8, IN_X0 + 4:IN_X1 - 4] = True          # le bas du creux reste droit (le sol)
    # les passages d'entrée (gauche) et de sortie (droite), arrondis en haut
    for x0, x1 in ((0, IN_X0 + 10), (IN_X1 - 10, IW)):
        door = np.zeros((IH, IW), bool)
        door[FLOOR - DOOR_H:FLOOR + 8, x0:x1] = True
        door = ndimage.gaussian_filter(door.astype(float), 6) > 0.45
        door[FLOOR - DOOR_H + 10:FLOOR + 8, x0:x1] = True
        hole |= door
    # bord : l'écorce coupée laisse voir l'aubier clair, puis le bois de cœur
    d_in = ndimage.distance_transform_edt(hole)
    rim = hole & (d_in < 5)
    sap = [hexc(c) for c in ("4a3424", "6b4e34", "8c6c4a", "a8875e")]
    paint(s, rim, 0.4 + 0.5 * (1 - d_in / 5) * (s.yy < FLOOR - 2), sap)
    # --- le bois de cœur, à l'intérieur : fil du bois qui ondule, ombre portée sous la voûte
    inner = hole & ~rim
    grain = np.sin((s.xx - IW / 2) * 0.22 + 6 * np.sin(s.yy * 0.012 + tex * 3) + tex * 5)
    depth = np.clip(d_in / 50, 0, 1)
    v = 0.18 + 0.32 * depth + 0.08 * grain + 0.06 * (tex - 0.5) - 0.18 * np.clip((IN_Y0 + 70 - s.yy) / 70, 0, 1)
    paint(s, inner, v, HEART)
    # les veines : rouges (la colère d'Adan) ou d'or (après la victoire)
    vn = fbm(IH // 4 + 4, IW, 104, (14, 7))
    vein_n = ndimage.zoom(vn, (4, 1), order=1)[:IH, :IW]        # étirées dans le fil du bois
    veins = inner & (np.abs(vein_n - 0.5) < 0.007) & (s.yy < FLOOR - 6) & (fbm(IH, IW, 107, (30,)) > 0.45)
    s.rgb[veins] = (200, 160, 60) if healthy else (150, 34, 26)
    glow = ndimage.binary_dilation(veins, iterations=1) & inner & ~veins
    s.rgb[glow] = ((s.rgb[glow] * 0.6) + np.array((90, 70, 20) if healthy else (70, 12, 8)) * 0.4).astype(np.uint8)
    # --- le sol : des racines entrelacées, dessus net à la ligne du sol
    floor = (s.yy >= FLOOR) & (s.yy < IH) & hole
    rootsh = np.abs(np.sin(s.xx * 0.12 + 3 * np.sin(s.yy * 0.4) + tex * 6))
    paint(s, floor, 0.3 + 0.4 * (rootsh > 0.5) - 0.25 * ((s.yy - FLOOR) / 32), IROKO)
    s.rgb[(s.yy == FLOOR) & hole] = IROKO[6]
    # --- dehors : mousse au pied, lichens ; le pied s'assombrit (contact)
    if healthy:
        moss = m & ~hole & (fbm(IH, IW, 105, (10, 5)) > 0.7) & (s.yy > IH - 260)
        s.rgb[moss] = np.array([(40, 74, 34), (56, 102, 46), (34, 60, 30)])[(s.xx[moss] + s.yy[moss]) % 3]
    k = np.clip((s.yy - (IH - 60)) / 60, 0, 1) * 0.45
    sel = ~hole & (k > 0)
    s.rgb[sel] = (s.rgb[sel] * (1 - k[sel, None])).astype(np.uint8)
    # ombre portée dans le creux, sous la voûte et contre les parois
    sh = inner & (ndimage.distance_transform_edt(~(~hole)) < 0)
    return s


def wheel():
    s = Sprite(64, 64)
    c = 31.5
    r = np.sqrt((s.xx - c) ** 2 + (s.yy - c) ** 2)
    ang = np.arctan2(s.yy - c, s.xx - c)
    teeth = (r < 31) & (np.cos(ang * 12) > 0.15)
    disc = r < 27.5
    m = disc | teeth
    tex = fbm(64, 64, 111, (8, 4))
    rings = np.sin(r * 1.3 + tex * 3)
    hg = relief(m, 4.0) + 1.0 * rings + 2.5 * teeth
    paint(s, m, lit(hg, m, 0.2) + 0.05 * (tex - 0.5), IROKO)
    # le moyeu de bronze, et la hache double gravée tout autour
    hub = r < 7
    bronze = [hexc(cc) for cc in ("3a2410", "6a4a1c", "a07a34", "d4ac58")]
    paint(s, hub, lit(relief(hub, 7.0), hub, 0.25), bronze)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        x, y = c + math.cos(a) * 18, c + math.sin(a) * 18
        mm = s.mask(lambda d, x=x, y=y: d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=255))
        s.rgb[mm & m] = IROKO[1]
    o = np.zeros_like(s.a)
    o[1:] |= s.a[:-1]; o[:-1] |= s.a[1:]; o[:, 1:] |= s.a[:, :-1]; o[:, :-1] |= s.a[:, 1:]
    o &= ~s.a; s.rgb[o] = OUTL; s.a |= o
    return s


def channel(kind):
    """Le sillon : sombre et creusé (la lueur bleue est ajoutée par le jeu, en modulant)."""
    im = Image.new("RGBA", (64, 64)); d = ImageDraw.Draw(im)
    c = 31.5
    if kind == "droit":
        d.line([(3, c), (60, c)], fill=(10, 6, 6, 255), width=6)
        d.line([(3, c - 1), (60, c - 1)], fill=(235, 245, 255, 255), width=2)
    else:
        # du haut (31.5, 3) vers la droite (60, 31.5) : un quart de cercle autour du coin
        for w, col in ((6, (10, 6, 6, 255)), (2, (235, 245, 255, 255))):
            d.arc((c - 28.5, -28.5 + c - c, c + 28.5, 28.5 + c - c), 0, 90, fill=col, width=w) if False else None
        pts = [(c + 28.5 - 28.5 * math.cos(t), 3 + 28.5 * math.sin(t)) for t in np.linspace(0, math.pi / 2, 24)]
        pts = [(c + (28.5 - 28.5 * math.cos(t)), 3 + 28.5 * math.sin(t)) for t in np.linspace(0, math.pi / 2, 24)]
        d.line(pts, fill=(10, 6, 6, 255), width=6, joint="curve")
        d.line(pts, fill=(235, 245, 255, 255), width=2, joint="curve")
    return im


def angry_roots():
    s = Sprite(56, 60)
    rr = random.Random(121)
    for k in range(9):
        a0 = rr.uniform(0, 2 * math.pi)
        pts = []
        for j in range(30):
            t = j / 29
            a = a0 + t * rr.choice((-1, 1)) * 2.4
            rad = 26 - 18 * t + 3 * math.sin(t * 9 + k)
            pts.append((28 + math.cos(a) * rad, 30 + math.sin(a) * rad * 1.1))
        for j in range(len(pts) - 1):
            w = 3.2 * (1 - j / 30) + 1
            mm = s.mask(lambda d, p=pts[j], q=pts[j + 1], w=w: d.line([p, q], fill=255, width=int(round(w * 2))))
            red = [hexc(c) for c in ("2a0806", "4e100c", "7a1c12", "a82e1a", "d4502c")]
            paint(s, mm, lit(relief(mm, 2.0), mm, 0.2) * 0.9, red)
    o = np.zeros_like(s.a)
    o[1:] |= s.a[:-1]; o[:-1] |= s.a[1:]; o[:, 1:] |= s.a[:, :-1]; o[:, :-1] |= s.a[:, 1:]
    o &= ~s.a; s.rgb[o] = OUTL; s.a |= o
    s.a[22:38, 21:35] = False                                    # le creux où loge l'éclat
    return s


def shard():
    im = Image.new("RGBA", (14, 20)); d = ImageDraw.Draw(im)
    d.polygon([(7, 0), (12, 6), (11, 14), (7, 19), (2, 13), (3, 5)], fill=(150, 200, 240, 255), outline=(30, 40, 70, 255))
    d.polygon([(7, 1), (11, 6), (7, 9), (4, 5)], fill=(230, 245, 255, 255))
    d.line([(7, 9), (7, 18)], fill=(90, 140, 210, 255))
    d.polygon([(7, 9), (10, 13), (7, 17)], fill=(110, 160, 220, 255))
    return im


def tabernacle(healthy):
    """Le tabernacle de Xɛvioso : une case ronde ouverte devant, toit de chaume conique."""
    W, H = 128, 112
    s = Sprite(W, H)
    g = H - 4
    tex = fbm(H, W, 131, (8, 4, 2))
    MUD = [hexc(c) for c in ("2a1810", "45281a", "613a24", "7e4e30", "9a643e", "b47c50")]
    THATCH = [hexc(c) for c in ("2c2210", "4a3a1a", "6c5628", "8e7438", "b0924c", "cdb06a")] if healthy else \
        [hexc(c) for c in ("2a2620", "433d33", "5e5648", "7a705e", "938872", "a99e86")]
    # le mur de terre (cylindre)
    wall = s.mask(lambda d: d.rectangle((22, 52, 106, g), fill=255))
    xs = (s.xx - 64) / 42
    hg = 30 * np.sqrt(np.clip(1 - xs ** 2, 0, 1)) + 2.0 * (tex > 0.7)
    paint(s, wall, lit(hg, wall, 0.18), MUD)
    # bandes peintes rouge et blanc sur le mur (couleurs de Xɛvioso)
    for y0, col in ((g - 22, (200, 196, 182)), (g - 18, (150, 32, 24)), (g - 14, (200, 196, 182))):
        band = wall & (s.yy >= y0) & (s.yy < y0 + 3)
        shade = (0.65 + 0.35 * np.sqrt(np.clip(1 - xs ** 2, 0, 1)))
        s.rgb[band] = (np.array(col)[None, :] * shade[band][:, None]).astype(np.uint8)
    # l'ouverture : on voit l'autel dedans, dans l'ombre
    door = s.mask(lambda d: d.chord((44, 54, 84, 106), 180, 360, fill=255) or d.rectangle((44, 74, 84, g), fill=255))
    s.rgb[door] = (22, 14, 10)
    # l'autel d'argile, et la hache double plantée dedans
    altar = s.mask(lambda d: d.ellipse((50, g - 18, 78, g + 4), fill=255)) & door
    paint(s, altar, lit(relief(altar, 6.0), altar, 0.2) * 0.8, MUD)
    d = ImageDraw.Draw(Image.new("L", (1, 1)))
    axe = s.mask(lambda d: (d.line([(64, g - 14), (64, g - 40)], fill=255, width=2),
                            d.polygon([(64, g - 40), (55, g - 46), (54, g - 32), (64, g - 36)], fill=255),
                            d.polygon([(64, g - 40), (73, g - 46), (74, g - 32), (64, g - 36)], fill=255)))
    bronze = [hexc(c) for c in ("4a2c10", "7a5420", "b0863a", "e8c060")]
    paint(s, axe, np.where(s.xx < 64, 0.85, 0.55), bronze)
    # le toit de chaume, conique, débordant, mèches qui pendent
    roof = s.mask(lambda d: d.polygon([(64, 4), (118, 58), (112, 62), (64, 56), (16, 62), (10, 58)], fill=255))
    straw = np.sin((s.xx - 64) * 1.1 + (s.yy * 0.15)) * 0.5 + 0.5
    rx = (s.xx - 64) / np.maximum(1, (s.yy - 4) * 0.96 + 1)
    hg = 14 * np.sqrt(np.clip(1 - rx ** 2, 0, 1)) + 1.5 * straw
    paint(s, roof, lit(hg, roof, 0.16), THATCH)
    rr = random.Random(132)
    for k in range(40):                                         # le bord effiloché
        x = rr.uniform(12, 116); y = 58 + 4 * (1 - abs(x - 64) / 54)
        L = rr.uniform(2, 6)
        mm = s.mask(lambda d, x=x, y=y, L=L: d.line([(x, y), (x + rr.uniform(-1, 1), y + L)], fill=255))
        paint(s, mm, np.full(mm.shape, 0.3 + 0.3 * rr.random()), THATCH)
    # le faîte : des cornes de bélier (l'animal de Xɛvioso) et un petit pot renversé
    horns = s.mask(lambda d: (d.arc((52, 0, 64, 12), 90, 330, fill=255, width=2), d.arc((64, 0, 76, 12), 210, 90, fill=255, width=2)))
    s.rgb[horns] = (226, 214, 186); s.a |= horns
    # les pagnes rouge et blanc noués de chaque côté de l'entrée
    for x0, col in ((38, (226, 222, 210)), (86, (168, 36, 28))):
        cl = s.mask(lambda d, x0=x0: d.polygon([(x0, 60), (x0 + 6, 60), (x0 + 7, 86), (x0 + 3, 90), (x0 - 1, 86)], fill=255))
        shade = np.where(s.xx < x0 + 3, 1.0, 0.78)
        s.rgb[cl] = (np.array(col)[None, :] * shade[cl][:, None]).astype(np.uint8); s.a |= cl
    # les jarres au pied
    for (x, w, h) in ((14, 10, 14), (110, 9, 12), (100, 7, 9)):
        jar = s.mask(lambda d, x=x, w=w, h=h: (d.ellipse((x - w, g - h, x + w, g + 1), fill=255), d.rectangle((x - w * 0.4, g - h - 3, x + w * 0.4, g - h + 2), fill=255)))
        paint(s, jar, lit(relief(jar, 4.0), jar, 0.2), [hexc(c) for c in ("3a1c10", "6a3420", "8e4a2c", "b06a40")])
    if healthy:
        for k in range(14):                                     # des fleurs au pied
            x = rr.uniform(4, 124); y = g - rr.choice((0, 1, 2))
            s.rgb[int(y), int(x)] = rr.choice([(230, 200, 60), (220, 80, 60), (240, 240, 230)]); s.a[int(y), int(x)] = True
    o = np.zeros_like(s.a)
    o[1:] |= s.a[:-1]; o[:-1] |= s.a[1:]; o[:, 1:] |= s.a[:, :-1]; o[:, :-1] |= s.a[:, 1:]
    o &= ~s.a; o[H - 4:] = False; s.rgb[o] = OUTL; s.a |= o
    return s


if __name__ == "__main__":
    save(grand_iroko(False), os.path.join(DEC, "grand_iroko.png"))
    save(grand_iroko(True), os.path.join(DEC, "grand_iroko_green.png"))
    save(tabernacle(False), os.path.join(PROPS, "tabernacle.png"))
    save(tabernacle(True), os.path.join(PROPS, "tabernacle_green.png"))
    save(wheel(), os.path.join(PROPS, "roue_coeur.png"))
    channel("coude").save(os.path.join(PROPS, "canal_coude.png"))
    channel("droit").save(os.path.join(PROPS, "canal_droit.png"))
    save(angry_roots(), os.path.join(PROPS, "racines_colere.png"))
    shard().save(os.path.join(PROPS, "eclat_foudre.png"))
    print("cœur de l'iroko : grand_iroko, roue, canaux, racines, éclat, tabernacle")
