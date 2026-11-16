"""Le décor sacré qui apparaît quand Xɛvioso reprend la forêt (fin de la partie 2).

  sacred_cloth.png (48 × 26)  le pagne blanc noué autour du tronc d'un arbre sacré :
                   bande enroulée (ombrée comme un cylindre), plis, bordure rouge,
                   le nœud et ses deux pans qui pendent
  offrandes.png    (48 × 18)  au pied de l'arbre : une calebasse ouverte, une jarre de terre,
                   des noix de cola, des cauris sur une feuille
  (Éléments culturels à faire valider par le conseiller.)

Utilisation : python3 sacred.py DOSSIER_SORTIE
"""
import math, os, sys
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
OUTL = (26, 18, 14, 255)


def cloth():
    W, H = 48, 26
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    band_top, band_bot = 3, 15
    for x in range(W):
        u = (x + 0.5) / W * 2 - 1                         # -1 … 1 sur la largeur du tronc
        shade = 0.55 + 0.45 * math.cos(u * math.pi / 2) ** 0.8 - 0.12 * u   # lumière à gauche
        # le bord du pagne ondule un peu (le tissu est serré, pas raide)
        t = band_top + round(0.6 * math.sin(x * 0.16))
        b = band_bot + round(0.6 * math.sin(x * 0.13 + 1.2))
        for y in range(t, b + 1):
            fold = 0.9 + 0.1 * math.sin((x * 0.9 + y * 2.2))   # plis obliques
            if (x + 2 * y) % 9 == 0: fold -= 0.12
            v = max(0.0, min(1.0, shade * fold))
            c = (int(150 + 105 * v), int(146 + 104 * v), int(136 + 100 * v), 255)
            if y in (t, b): c = (int(120 + 60 * v), int(26 + 20 * v), int(22 + 16 * v), 255)   # bordure rouge
            if y == t + 1 or y == b - 1: c = tuple(int(k * 0.92) for k in c[:3]) + (255,)
            px[x, y] = c
        px[x, max(t - 1, 0)] = OUTL
        if b + 1 < H: px[x, b + 1] = OUTL
    # le nœud, un peu à droite du milieu, et ses deux pans
    d = ImageDraw.Draw(im)
    kx, ky = 30, 9
    d.ellipse((kx - 3, ky - 3, kx + 3, ky + 3), fill=(232, 228, 216, 255), outline=OUTL)
    d.point((kx - 1, ky - 1), fill=(255, 255, 250, 255))
    for (dx, sway, ln) in ((-1, -2, 13), (2, 3, 11)):
        pts = []
        for k in range(ln):
            pts.append((kx + dx + sway * (k / ln) ** 1.5, ky + 3 + k))
        for i, (x, y) in enumerate(pts):
            w = 2 if i < ln - 2 else 1
            for j in range(-w, w + 1):
                v = 0.8 + 0.2 * (j < 0)
                im.putpixel((int(x) + j, int(y)), (int(240 * v), int(236 * v), int(224 * v), 255))
            im.putpixel((int(x) - w - 1, int(y)), OUTL)
            im.putpixel((int(x) + w + 1, int(y)), OUTL)
        ex, ey = pts[-1]
        im.putpixel((int(ex), int(ey) + 1), (140, 34, 28, 255))     # le bout rouge
    im.save(os.path.join(OUT, "sacred_cloth.png"))


def offerings():
    W, H = 48, 18
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # une feuille de bananier posée à plat
    d.polygon([(2, 16), (10, 12), (26, 11), (40, 13), (46, 16), (24, 17)], fill=(58, 104, 44, 255), outline=(22, 40, 18, 255))
    d.line([(6, 15), (42, 14)], fill=(92, 140, 64, 255))
    # la jarre de terre
    d.ellipse((6, 3, 18, 16), fill=(124, 66, 38, 255), outline=OUTL)
    d.rectangle((9, 1, 15, 4), fill=(110, 58, 34, 255), outline=OUTL)
    d.line([(8, 6), (9, 12)], fill=(160, 96, 60, 255))
    d.line([(7, 10), (17, 10)], fill=(92, 46, 26, 255))
    # la calebasse ouverte, avec de l'eau (ou du lait) qui luit
    d.chord((20, 6, 34, 18), 0, 180, fill=(196, 150, 70, 255), outline=OUTL)
    d.ellipse((20, 9, 34, 13), fill=(236, 232, 214, 255), outline=(120, 86, 40, 255))
    d.point((24, 10), fill=(255, 255, 255, 255))
    # noix de cola (rouges et blanches)
    for (x, y, c) in ((36, 13, (176, 58, 46)), (39, 14, (222, 196, 160)), (37, 15, (150, 44, 36))):
        d.ellipse((x - 2, y - 1, x + 2, y + 2), fill=c + (255,), outline=OUTL)
    # des cauris
    for (x, y) in ((42, 15), (44, 13), (30, 16)):
        d.ellipse((x - 1, y - 1, x + 2, y + 1), fill=(244, 238, 222, 255), outline=(120, 110, 96, 255))
    im.save(os.path.join(OUT, "offrandes.png"))


if __name__ == "__main__":
    cloth(); offerings()
    print("sacred_cloth.png, offrandes.png")
