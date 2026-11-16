"""Bêtes de la forêt : le serpent (nouvel ennemi) et la chauve-souris (redessinée).

  snake.png      (48 × 20 par image)  python royal assombri par la poussière d'Adaka :
                 ligne 0 : il ondule (4 images) ; ligne 1 : il se love, tête dressée (2) ;
                 ligne 2 : il se détend et mord (2). Dessin tourné vers la gauche.
  bat.png        (32 × 22 par image, 6 images)  chauve-souris : membranes tendues sur les
                 doigts, corps velu, grandes oreilles ; battement complet (haut, milieu, bas…)
  bat_eyes.png   les mêmes images, rien que les yeux (ils luisent dans le noir)

Utilisation : python3 fauna.py DOSSIER_ENNEMIS   (écrit snake/snake.png, bat/bat.png, bat/bat_eyes.png)
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
OUTL = np.array([16, 11, 9])
BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def hexc(h): return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)])


SKIN_DARK = [hexc(c) for c in ("1a130e", "2a1e15", "3b2b1e")]
SKIN_TAN = [hexc(c) for c in ("4e3d2b", "6b5539", "86704c", "a08a62")]
BELLY = [hexc(c) for c in ("8c826a", "b0a684", "cfc6a2")]


def outline(rgb, a):
    o = np.zeros_like(a)
    o[1:] |= a[:-1]; o[:-1] |= a[1:]; o[:, 1:] |= a[:, :-1]; o[:, :-1] |= a[:, 1:]
    o &= ~a
    rgb[o] = OUTL; a |= o


def snake_frame(kind, k):
    W, H = 48, 20
    rgb = np.zeros((H, W, 3), np.uint8); a = np.zeros((H, W), bool)
    yy, xx = np.mgrid[0:H, 0:W]
    n = 60
    pts = []
    for i in range(n):
        s = i / (n - 1)                      # 0 = tête, 1 = queue
        if kind == "slither":
            x = 6 + s * 38
            y = 14.5 - 3.0 * math.sin(s * 9.0 - k * math.pi / 2) * (0.3 + 0.7 * s) - 1.5 * (1 - s) ** 6
        elif kind == "coil":
            if s < 0.3:                          # le cou dressé en S
                t = s / 0.3
                x = 8 + 10 * t + 2 * math.sin(t * 6)
                y = 5 + 10 * t ** 1.4 - (1 - t) * (k * 1.0)
            else:                                # le corps lové en boucles
                t = (s - 0.3) / 0.7
                x = 18 + 20 * t + 4 * math.cos(t * 13)
                y = 15.5 - 2.5 * (math.sin(t * 13) * 0.5 + 0.5)
        else:                                    # strike
            ext = 1.0 if k == 1 else 0.6
            if s < 0.45:
                t = s / 0.45
                x = 2 + 18 * t * (1.2 - 0.2 * ext) + (1 - ext) * 6
                y = 9 + 6 * t ** 1.5
            else:
                t = (s - 0.45) / 0.55
                x = 22 + 20 * t + 3 * math.cos(t * 9)
                y = 15.5 - 1.5 * (math.sin(t * 9) * 0.5 + 0.5)
        pts.append((x, y, s))
    # du bout de la queue vers la tête : chaque disque recouvre le précédent
    for (x, y, s) in reversed(pts):
        r = 0.8 + 2.6 * math.sin(math.pi * min(1.0, (s + 0.08) * 0.95)) ** 0.6 * (1 - 0.55 * s)
        d = np.sqrt((xx - x) ** 2 + (yy - y) ** 2)
        m = d <= r + 0.3
        dy = (yy - y) / max(r, 0.5)
        blotch = math.sin(s * 34.0) > 0.25          # les taches du python, sur le dos
        val = np.clip(0.55 - 0.45 * dy + BAY[yy % 4, xx % 4] * 0.5 - 0.25, 0, 0.999)
        top = m & (dy < 0.35)
        bel = m & (dy >= 0.35)
        pal = SKIN_DARK if blotch else SKIN_TAN
        idx = (val * len(pal)).astype(int).clip(0, len(pal) - 1)
        for i, c in enumerate(pal):
            rgb[top & (idx == i)] = c
        bi = ((1 - (dy - 0.35)) * 2).astype(int).clip(0, 2)
        for i, c in enumerate(BELLY):
            rgb[bel & (bi == i)] = c
        a |= m
    # la tête : un peu plus large, aplatie, l'œil, la langue
    hx, hy, _ = pts[0]
    head = ((xx - hx) / 3.6) ** 2 + ((yy - hy) / 2.6) ** 2 <= 1
    rgb[head] = SKIN_TAN[1]; rgb[head & (yy < hy)] = SKIN_TAN[2]
    rgb[head & (yy < hy - 1)] = SKIN_DARK[2]
    a |= head
    ex, ey = int(round(hx - 0.5)), int(round(hy - 1))
    if 0 <= ey < H and 0 <= ex < W:
        rgb[ey, ex] = (210, 170, 60)                  # l'œil, jaune
    if kind == "strike" or (kind == "coil" and k == 1):
        for j, (tx, ty) in enumerate(((hx - 4, hy + 0.5), (hx - 5, hy + 0.5), (hx - 6, hy), (hx - 6, hy + 1.2))):
            xi, yi = int(round(tx)), int(round(ty))
            if 0 <= xi < W and 0 <= yi < H:
                rgb[yi, xi] = (190, 40, 50); a[yi, xi] = True
    outline(rgb, a)
    return rgb, a


def bat_frame(k):
    """k : 0..5, battement : ailes hautes → à plat → basses → à plat."""
    W, H = 32, 22
    im = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(im)
    eyes = Image.new("RGBA", (W, H)); de = ImageDraw.Draw(eyes)
    lift = [-8, -4, 1, 6, 2, -3][k]           # hauteur du bout des ailes
    bob = [0, 0, 1, 1, 1, 0][k]
    cx, cy = 16, 10 + bob
    MEM = [(38, 30, 32), (56, 44, 46), (74, 60, 60)]
    BONE = (98, 82, 78)
    FUR = [(30, 24, 22), (48, 38, 34), (66, 54, 46)]
    for side in (-1, 1):
        tip = (cx + side * 15, cy + lift)
        elbow = (cx + side * 7, cy - 2 + lift * 0.5)
        f1 = (cx + side * 12, cy + 3 + lift * 0.6)
        f2 = (cx + side * 8, cy + 5 + lift * 0.3)
        # la membrane, festonnée entre les doigts
        poly = [(cx + side * 2, cy - 1), elbow, tip, (tip[0] - side * 1, tip[1] + 3), f1, (f1[0] - side * 2, f1[1] + 1), f2,
                (f2[0] - side * 2, f2[1] + 1), (cx + side * 2, cy + 4)]
        d.polygon(poly, fill=MEM[1] + (255,), outline=(16, 11, 9, 255))
        # le dessus de l'aile plus clair près du bras
        d.polygon([(cx + side * 2, cy - 1), elbow, tip, (elbow[0] + side * 2, elbow[1] + 3)], fill=MEM[2] + (255,))
        for f in (tip, f1, f2):
            d.line([elbow, f], fill=BONE + (255,))
        d.line([(cx + side * 2, cy), elbow], fill=BONE + (255,), width=1)
        d.point(elbow, fill=(140, 120, 110, 255))     # le pouce
    # le corps velu et la tête
    d.ellipse((cx - 3, cy - 2, cx + 3, cy + 6), fill=FUR[1] + (255,), outline=(16, 11, 9, 255))
    d.line([(cx - 1, cy), (cx - 1, cy + 4)], fill=FUR[2] + (255,))
    d.ellipse((cx - 3, cy - 5, cx + 3, cy), fill=FUR[1] + (255,), outline=(16, 11, 9, 255))
    d.polygon([(cx - 3, cy - 4), (cx - 3, cy - 8), (cx - 1, cy - 5)], fill=FUR[0] + (255,), outline=(16, 11, 9, 255))
    d.polygon([(cx + 3, cy - 4), (cx + 3, cy - 8), (cx + 1, cy - 5)], fill=FUR[0] + (255,), outline=(16, 11, 9, 255))
    d.point((cx, cy - 1), fill=(200, 170, 160, 255))     # le museau, les crocs
    # les pattes repliées
    d.point((cx - 1, cy + 7), fill=FUR[0] + (255,)); d.point((cx + 1, cy + 7), fill=FUR[0] + (255,))
    for e in (cx - 2, cx + 1):
        d.point((e, cy - 3), fill=(30, 20, 18, 255))
        de.point((e, cy - 3), fill=(255, 70, 50, 255))
    return im, eyes


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "snake"), exist_ok=True)
    sheet = Image.new("RGBA", (48 * 4, 20 * 3))
    for row, (kind, count) in enumerate((("slither", 4), ("coil", 2), ("strike", 2))):
        for k in range(count):
            rgb, a = snake_frame(kind, k)
            im = np.zeros((20, 48, 4), np.uint8); im[..., :3] = rgb; im[..., 3] = a * 255
            sheet.paste(Image.fromarray(im, "RGBA"), (k * 48, row * 20))
    sheet.save(os.path.join(OUT, "snake", "snake.png"))
    bats = Image.new("RGBA", (32 * 6, 22)); eyes = Image.new("RGBA", (32 * 6, 22))
    for k in range(6):
        b, e = bat_frame(k)
        bats.paste(b, (k * 32, 0)); eyes.paste(e, (k * 32, 0))
    bats.save(os.path.join(OUT, "bat", "bat.png")); eyes.save(os.path.join(OUT, "bat", "bat_eyes.png"))
    print("snake.png, bat.png, bat_eyes.png")
