"""Petits détails semés sur le sol de la forêt (le niveau les répartit tout seul) et la
feuille qui tombe des arbres.

  sol_cailloux  (22 × 10)  deux ou trois pierres à demi enterrées, mousse au pied
  sol_touffe    (18 × 12)  une touffe d'herbe souple, brins courbés
  sol_feuilles  (24 × 6)   un tapis de feuilles mortes
  sol_racine    (40 × 8)   une racine qui affleure et replonge dans la terre
  sol_pousse    (14 × 14)  une jeune pousse à deux feuilles
  sol_brindilles (26 × 6)  des brindilles et une coque de fruit
  feuille       (6 × 4)    la feuille qui tombe (teintée par le niveau)
Chaque détail existe en version sèche (<nom>.png) et guérie (<nom>_green.png).

Utilisation : python3 ground_bits.py DOSSIER_DECOR DOSSIER_PROPS
"""
import math, os, random, sys
from PIL import Image, ImageDraw

DEC = sys.argv[1] if len(sys.argv) > 1 else "."
PROPS = sys.argv[2] if len(sys.argv) > 2 else "."
OUTL = (14, 10, 8, 255)


def pal(healthy):
    if healthy:
        return dict(grass=[(24, 52, 28), (40, 82, 40), (64, 116, 56), (98, 150, 78)],
                    leaf=[(92, 58, 26), (122, 80, 34), (150, 104, 48), (80, 96, 40)],
                    stone=[(54, 52, 48), (78, 76, 70), (104, 100, 92), (130, 126, 116)],
                    moss=[(36, 74, 34), (56, 102, 46)],
                    wood=[(44, 30, 20), (66, 46, 30), (90, 66, 44), (112, 86, 60)])
    return dict(grass=[(52, 50, 46), (72, 69, 63), (94, 90, 82), (118, 113, 103)],
                leaf=[(70, 62, 52), (88, 80, 68), (108, 99, 85), (78, 72, 64)],
                stone=[(50, 49, 46), (72, 70, 66), (96, 93, 87), (120, 116, 108)],
                moss=[(62, 60, 54), (80, 77, 70)],
                wood=[(40, 34, 30), (58, 50, 44), (78, 70, 62), (98, 90, 80)])


def rgba(c): return tuple(c) + (255,)


def cailloux(h):
    p = pal(h); im = Image.new("RGBA", (22, 10)); d = ImageDraw.Draw(im)
    for (x0, y0, x1, y1) in ((1, 3, 11, 10), (9, 5, 17, 10), (15, 7, 21, 10)):
        d.ellipse((x0, y0, x1, y1 + 3), fill=rgba(p["stone"][1]), outline=OUTL)
        d.arc((x0 + 1, y0 + 1, x1 - 1, y1 + 2), 190, 290, fill=rgba(p["stone"][3]))
        d.point((x0 + 3, y0 + 2), fill=rgba(p["stone"][3]))
        d.line((x0 + 2, y1 - 1, x1 - 2, y1 - 1), fill=rgba(p["stone"][0]))
    for x in range(0, 22, 2):
        d.point((x, 9), fill=rgba(p["moss"][x % 2]))
    return im


def touffe(h):
    p = pal(h); im = Image.new("RGBA", (18, 12)); d = ImageDraw.Draw(im)
    r = random.Random(4)
    for k in range(11):
        x0 = 4 + k * 1.0 + r.uniform(-1, 1); L = r.uniform(5, 11); bend = r.uniform(-5, 5)
        pts = [(x0 + bend * (t / 6) ** 2, 11 - L * t / 6) for t in range(7)]
        d.line(pts, fill=rgba(p["grass"][1 + (k % 3)]))
    return im


def feuilles(h):
    p = pal(h); im = Image.new("RGBA", (24, 6)); d = ImageDraw.Draw(im)
    r = random.Random(2)
    for k in range(14):
        x = r.uniform(0, 21); y = r.uniform(2, 5)
        c = p["leaf"][r.randrange(4)]
        d.ellipse((x, y, x + r.choice((2, 3)), y + 1), fill=rgba(c))
    return im


def racine(h):
    p = pal(h); im = Image.new("RGBA", (40, 8)); d = ImageDraw.Draw(im)
    top = [(x, 7 - 4.5 * math.sin(math.pi * x / 39) - 0.8 * math.sin(x * 0.5)) for x in range(40)]
    d.polygon(top + [(39, 8), (0, 8)], fill=rgba(p["wood"][1]))
    d.line(top, fill=OUTL)
    d.line([(x, y + 1) for x, y in top[3:-3]], fill=rgba(p["wood"][3]))
    d.line([(x, y + 3) for x, y in top[8:-8]], fill=rgba(p["wood"][0]))
    return im


def pousse(h):
    p = pal(h); im = Image.new("RGBA", (14, 14)); d = ImageDraw.Draw(im)
    d.line([(7, 13), (7, 6), (8, 4)], fill=rgba(p["grass"][1]))
    d.polygon([(7, 7), (2, 4), (1, 6), (5, 8)], fill=rgba(p["grass"][2]), outline=rgba(p["grass"][0]))
    d.polygon([(8, 5), (12, 1), (13, 3), (10, 6)], fill=rgba(p["grass"][3]), outline=rgba(p["grass"][0]))
    return im


def brindilles(h):
    p = pal(h); im = Image.new("RGBA", (26, 6)); d = ImageDraw.Draw(im)
    d.line([(1, 5), (12, 3), (18, 4)], fill=rgba(p["wood"][2]))
    d.line([(8, 4), (11, 1)], fill=rgba(p["wood"][2]))
    d.line([(14, 5), (24, 5)], fill=rgba(p["wood"][1]))
    d.ellipse((19, 1, 24, 5), fill=rgba(p["wood"][1]), outline=OUTL)          # une coque
    d.point((20, 2), fill=rgba(p["wood"][3]))
    return im


def feuille():
    im = Image.new("RGBA", (6, 4)); d = ImageDraw.Draw(im)
    d.polygon([(0, 2), (2, 0), (5, 1), (3, 3)], fill=(235, 235, 235, 255))
    d.line([(1, 2), (5, 1)], fill=(190, 190, 190, 255))
    return im


BITS = {"sol_cailloux": cailloux, "sol_touffe": touffe, "sol_feuilles": feuilles, "sol_racine": racine,
        "sol_pousse": pousse, "sol_brindilles": brindilles}

if __name__ == "__main__":
    for n, fn in BITS.items():
        fn(False).save(os.path.join(DEC, n + ".png"))
        fn(True).save(os.path.join(DEC, n + "_green.png"))
    feuille().save(os.path.join(PROPS, "feuille.png"))
    print("détails du sol :", ", ".join(BITS), "+ feuille")


def flaque(h):
    """flaque.png (64 × 8) : l'eau d'une flaque posée dans un creux du sol, qui reflète le jour."""
    W, H = 64, 8
    im = Image.new("RGBA", (W, H)); px = im.load()
    for x in range(W):
        u = (x - W / 2) / (W / 2 - 1)
        depth = int(round(6.5 * max(0.0, 1 - u * u) ** 0.5))
        for y in range(1, 1 + max(depth, 1)):
            t = (y - 1) / 6
            if h:
                c = (int(120 + 70 * (1 - t) - 20 * abs(u)), int(160 + 60 * (1 - t) - 20 * abs(u)), int(170 + 50 * (1 - t)))
            else:
                c = (int(96 + 40 * (1 - t) - 14 * abs(u)), int(104 + 40 * (1 - t) - 14 * abs(u)), int(104 + 36 * (1 - t)))
            px[x, y] = c + (235,)
        if depth >= 1:
            px[x, min(depth + 1, H - 1)] = (44, 34, 26, 255) if h else (52, 50, 46, 255)    # la boue du bord
        px[x, 0] = (180, 210, 214, 200) if (h and abs(u) < 0.85) else (150, 156, 152, 160) if abs(u) < 0.85 else (0, 0, 0, 0)
    for gx in (14, 15, 38, 46):                                    # reflets
        px[gx, 2] = (240, 250, 255, 255)
    px[27, 3] = (120, 80, 34, 255) if h else (100, 94, 82, 255)   # une feuille qui flotte
    px[28, 3] = (150, 104, 48, 255) if h else (118, 110, 96, 255)
    return im


if __name__ == "__main__":
    flaque(False).save(os.path.join(DEC, "flaque.png"))
    flaque(True).save(os.path.join(DEC, "flaque_green.png"))
