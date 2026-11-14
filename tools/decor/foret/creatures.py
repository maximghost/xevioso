"""Créatures et objets animés de la forêt des irokos (planches d'images, une ligne par animation).

  bat.png        chauve-souris de poussière, 24 × 16, 4 images de vol (yeux dessinés à part)
  bat_eyes.png   les yeux seuls (même grille) : affichés sans éclairage, ils luisent dans le noir
  rat.png        rat gris, 16 × 10, 2 images de course
  golem.png      le Poussiéreux, 34 × 38 : marche (4), dort (2) ; ligne 0 marche, ligne 1 sommeil
  bird.png       oiseau messager (touraco), 14 × 12, 2 images de vol + 1 posé
  drum_tree.png  tambour-arbre (3 voix : étoffe blanche, rouge, indigo), 26 × 34 chacun ; ligne 1 = frappé
  root_gate.png  porte de racines, 24 × 80
  root_tile.png  racine sacrée raccordable (16 × 16) pour les ponts et les piliers
  spear.png      lance de braise, 22 × 6
  flame.png      flammes du sol (16 × 16, 4 images)
"""
import math, random, sys
import numpy as np
from PIL import Image, ImageDraw

OUT = sys.argv[1]
O = (16, 12, 10, 255)


def C(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def sheet(frames, w, h, rows=1):
    im = Image.new("RGBA", (w * max(len(r) for r in frames), h * len(frames)), (0, 0, 0, 0))
    for j, row in enumerate(frames):
        for i, f in enumerate(row):
            im.paste(f, (i * w, j * h))
    return im


def outline(im):
    a = np.array(im)
    m = a[..., 3] > 0
    o = np.zeros_like(m)
    o[1:] |= m[:-1]; o[:-1] |= m[1:]; o[:, 1:] |= m[:, :-1]; o[:, :-1] |= m[:, 1:]
    o &= ~m
    a[o] = O
    return Image.fromarray(a)


# ---------------------------------------------------------------- chauve-souris
def bat_frame(i, eyes_only=False):
    im = Image.new("RGBA", (24, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if not eyes_only:
        wing = [0.0, -5.0, -1.0, 4.0][i]        # battement : haut, très haut, milieu, bas
        body, dark, membrane = C("4a4540"), C("2c2825"), C("5e5750")
        for s_ in (-1, 1):
            tip = (12 + s_ * 11, 7 + wing)
            elbow = (12 + s_ * 6, 5 + wing * 0.6)
            d.polygon([(12 + s_ * 2, 7), elbow, tip, (12 + s_ * 8, 10 + wing * 0.3), (12 + s_ * 4, 10)], fill=membrane)
            d.line([(12 + s_ * 2, 7), elbow, tip], fill=dark)
            d.line([elbow, (12 + s_ * 8, 10 + wing * 0.3)], fill=dark)
        d.ellipse((9, 5, 15, 12), fill=body)
        d.polygon([(10, 6), (9, 2), (11, 5)], fill=body); d.polygon([(14, 6), (15, 2), (13, 5)], fill=body)   # oreilles
        d.point((12, 11), fill=C("8a8378"))
        im = outline(im)
    else:
        pass
    d = ImageDraw.Draw(im)
    eye = C("ff7a2a")
    d.point((11, 8), fill=eye); d.point((13, 8), fill=eye)
    return im


# ---------------------------------------------------------------- rat
def rat_frame(i):
    im = Image.new("RGBA", (16, 10), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    body, light = C("5a554e"), C("7a746a")
    d.ellipse((3, 3, 12, 8), fill=body)
    d.ellipse((0, 4, 5, 8), fill=body)                       # tête (à gauche)
    d.point((1, 5), fill=C("ff9a5a"))
    d.point((3, 3), fill=light); d.point((4, 3), fill=light)
    d.line([(12, 6), (15, 4 + i)], fill=C("8a6a5a"))         # queue
    for k, x in enumerate((4, 9)):
        dx = (1 if (k + i) % 2 else -1)
        d.line([(x, 8), (x + dx, 9)], fill=O)
    d.line([(4, 3), (10, 3)], fill=light)
    return outline(im)


# ---------------------------------------------------------------- le Poussiéreux
def golem_frame(i, sleeping=False):
    W, H = 34, 38
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    P = [C("3e3832"), C("564e45"), C("6e655a"), C("8a8070"), C("a69b88")]
    sway = [0, 1, 0, -1][i] if not sleeping else 0
    sink = 3 if sleeping else 0
    # jambes massives
    if not sleeping:
        for s_, ph in ((-1, i), (1, i + 2)):
            lift = 2 if ph % 4 == 1 else 0
            x = 17 + s_ * 6
            d.rectangle((x - 4, 26 - lift, x + 3, 37 - lift), fill=P[1])
            d.rectangle((x - 5, 34 - lift, x + 4, 37 - lift), fill=P[0])
    else:
        d.rectangle((7, 32, 27, 37), fill=P[0])
    # corps : un bloc de terre et de poussière agglomérées, penché
    by = 10 + sink
    d.polygon([(6 + sway, by + 4), (12 + sway, by - 2), (24 + sway, by - 2), (29 + sway, by + 6), (28, by + 18), (6, by + 18)], fill=P[2])
    d.polygon([(8 + sway, by + 6), (14 + sway, by + 1), (22 + sway, by + 1), (26 + sway, by + 8), (25, by + 15), (9, by + 15)], fill=P[3])
    for (x, y) in ((12, 14), (20, 12), (24, 18), (14, 22), (19, 20)):      # cailloux pris dans la masse
        d.ellipse((x - 2 + sway, y - 1 + sink, x + 1 + sway, y + 1 + sink), fill=P[1])
    # tête basse, enfoncée
    hx = 17 + sway
    d.ellipse((hx - 6, by - 9, hx + 6, by + 2), fill=P[2])
    d.line([(hx - 4, by - 7), (hx + 3, by - 8)], fill=P[4])
    if sleeping:
        d.line([(hx - 4, by - 3), (hx - 1, by - 3)], fill=O); d.line([(hx + 1, by - 3), (hx + 4, by - 3)], fill=O)
    else:
        d.rectangle((hx - 4, by - 4, hx - 2, by - 3), fill=C("ffb040")); d.rectangle((hx + 2, by - 4, hx + 4, by - 3), fill=C("ffb040"))
    # bras qui pendent
    for s_ in (-1, 1):
        x = 17 + s_ * 13 + sway
        d.rectangle((x - 3, by + 2, x + 2, by + 16 + (0 if sleeping else abs(sway))), fill=P[1])
        d.rectangle((x - 4, by + 14, x + 3, by + 19), fill=P[0])
    return outline(im)


# ---------------------------------------------------------------- oiseau messager (touraco)
def bird_frame(i):
    im = Image.new("RGBA", (14, 12), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    green, red, blue = C("2e8a4a"), C("d0302a"), C("2a4a9a")
    if i < 2:
        up = i == 0
        d.polygon([(6, 6), (2, 1 if up else 9), (9, 6)], fill=red)          # aile (le rouge du touraco)
        d.polygon([(6, 6), (11, 0 if up else 10), (8, 6)], fill=red)
    d.ellipse((4, 4, 10, 9), fill=green)
    d.ellipse((8, 2, 12, 6), fill=green)
    d.polygon([(9, 2), (10, 0), (11, 2)], fill=green)                         # huppe
    d.point((11, 4), fill=C("ffffff"))
    d.polygon([(12, 4), (13, 5), (12, 5)], fill=C("e8a020"))
    d.line([(4, 7), (1, 9)], fill=blue)                                        # queue
    if i == 2:
        d.polygon([(5, 5), (9, 5), (8, 8)], fill=C("1f6a36"))
        d.line([(6, 9), (6, 11)], fill=O); d.line([(8, 9), (8, 11)], fill=O)
    return outline(im)


# ---------------------------------------------------------------- tambour-arbre
def drum_frame(voice, hit):
    """Un tronçon d'arbre creusé en tambour à fente, posé sur deux pieds, ceint d'une étoffe."""
    W, H = 26, 34
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    wood = [C("3a2618"), C("54382a"), C("70503a"), C("8e6a4c"), C("a8845e")]
    cloth = [(C("e8e4d8"), C("bcb6a6")), (C("c03028"), C("8a1e1a")), (C("2e3e8a"), C("1e2860"))][voice]
    sq = 2 if hit else 0
    d.rectangle((5, 26, 7, 33), fill=wood[1]); d.rectangle((18, 26, 20, 33), fill=wood[1])     # pieds
    d.rounded_rectangle((2, 6 + sq, 23, 27), radius=7, fill=wood[2])
    d.rounded_rectangle((4, 8 + sq, 21, 25), radius=6, fill=wood[3])
    d.line([(6, 10 + sq), (6, 23)], fill=wood[4])
    d.rectangle((11, 9 + sq, 14, 24), fill=wood[0])                                  # la fente
    d.rectangle((2, 15, 23, 18), fill=cloth[0]); d.line([(2, 18), (23, 18)], fill=cloth[1])
    d.polygon([(19, 15), (24, 21), (21, 22), (19, 18)], fill=cloth[0])               # le nœud qui pend
    n = (voice + 1)
    for k in range(n):                                                               # entailles : 1, 2 ou 3
        d.line([(6 + k * 3, 4 + sq), (6 + k * 3, 6 + sq)], fill=wood[1])
    if hit:
        d.arc((0, 2, 25, 30), 200, 340, fill=C("ffe8a0"))
    return outline(im)


# ---------------------------------------------------------------- porte de racines et racine sacrée
def root_gate():
    W, H = 24, 80
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    pal = [C("2a1c12"), C("3e2a1c"), C("5a3e2a"), C("76563c"), C("94704e")]
    r = random.Random(4)
    for k in range(6):
        x = 3 + k * 3.6
        pts = [(x + 2.5 * math.sin(y * 0.18 + k * 1.7), y) for y in range(0, H + 1, 4)]
        d.line(pts, fill=pal[1 + k % 3], width=4)
    for y in range(6, H, 11):
        d.line([(2, y + r.randint(-2, 2)), (21, y + r.randint(-2, 2))], fill=pal[3], width=2)
    for k in range(18):
        x, y = r.randint(2, 21), r.randint(2, H - 3)
        d.point((x, y), fill=pal[4])
    for k in range(10):                                     # quelques épines grises
        x, y = r.randint(1, 22), r.randint(4, H - 4)
        d.polygon([(x, y), (x + r.choice((-3, 3)), y - 1), (x, y + 1)], fill=C("9a948a"))
    return outline(im)


def root_tile():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    pal = [C("2a1c12"), C("4a3220"), C("6a4a30"), C("8a6844"), C("a8865a")]
    d.rectangle((0, 0, 15, 15), fill=pal[2])
    for k, y in enumerate((2, 7, 12)):
        d.line([(0, y), (5, y + 1), (10, y - 1), (15, y)], fill=pal[3 if k % 2 else 1], width=2)
    d.line([(0, 0), (15, 0)], fill=pal[4]); d.line([(0, 1), (15, 1)], fill=C("5a9a4a"))   # mousse vivante dessus
    d.point((4, 1), fill=C("8ad06a")); d.point((11, 1), fill=C("8ad06a"))
    d.line([(0, 15), (15, 15)], fill=pal[0])
    return im


# ---------------------------------------------------------------- Adan
EMB = [C("ffd27a"), C("ff9a2a"), C("e84a14"), C("8a1a0a")]
BARKD = [C("140e0b"), C("241a14"), C("36271d"), C("4a3628"), C("5e4634"), C("765a44")]


def adan_frame(pose, t):
    """Adan, la Colère : un guerrier d'écorce et de braise, deux fois la taille d'un Envoyé.
    Corps d'écorce noircie fendue de braises, masque de bois aux yeux de feu, crinière de fumée,
    massue d'écorce embrasée. Il regarde vers la gauche."""
    W, H = 72, 72
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    gy = 70
    # paramètres de pose
    lean, crouch, arm_a, arm_b, club_a, stride, glow = 0, 0, 30, 40, 200, 0, 0.0
    if pose == "idle":
        crouch = [0, 1][t]; arm_a, arm_b, club_a = 35, 50, 240
    elif pose == "walk":
        stride = [-5, 0, 5, 0][t]; crouch = [0, 1, 0, 1][t]; arm_a, arm_b, club_a = 30 + stride * 2, 50, 240
    elif pose == "charge":
        lean = 14; crouch = 4; stride = [-7, 7][t]; arm_a, arm_b, club_a = 70, 80, 180
    elif pose == "throw":
        lean = [-6, -10, 10][t]; arm_a = [150, 175, 40][t]; arm_b = [120, 150, 20][t]; club_a = 240; crouch = [1, 2, 0][t]
    elif pose == "slam":
        lean = [-6, 0, 16][t]; crouch = [2, 0, 6][t]; arm_a = [160, 185, 60][t]; arm_b = [150, 175, 40][t]; club_a = [160, 190, 80][t]
    elif pose == "hurt":
        lean = -12; crouch = 2; arm_a, arm_b, club_a = 10, 60, 280
    elif pose == "fury":
        crouch = 3; arm_a = [130, 140][t]; arm_b = [100, 115][t]; club_a = [110, 125][t]; glow = 1.0
    hip = (38 + lean * 0.3, gy - 22 + crouch)
    # jambes (écorce)
    for s_, off in ((-1, stride), (1, -stride)):
        knee = (hip[0] + s_ * 4 + off * 0.6, hip[1] + 10)
        foot = (hip[0] + s_ * 6 + off, gy)
        d.line([hip, knee], fill=BARKD[2], width=8); d.line([knee, foot], fill=BARKD[2], width=7)
        d.polygon([(foot[0] - 7, gy), (foot[0] + 4, gy), (foot[0] + 3, gy - 4), (foot[0] - 5, gy - 4)], fill=BARKD[1])
    # torse massif penché
    ang = math.radians(lean)
    def rot(p, c=hip):
        x, y = p[0] - c[0], p[1] - c[1]
        return (c[0] + x * math.cos(ang) - y * math.sin(ang), c[1] + x * math.sin(ang) + y * math.cos(ang))
    torso = [rot(p) for p in [(hip[0] - 11, hip[1]), (hip[0] - 15, hip[1] - 18), (hip[0] - 12, hip[1] - 30), (hip[0] + 12, hip[1] - 30), (hip[0] + 14, hip[1] - 16), (hip[0] + 10, hip[1])]]
    d.polygon(torso, fill=BARKD[3])
    inner = [rot(p) for p in [(hip[0] - 8, hip[1] - 2), (hip[0] - 11, hip[1] - 17), (hip[0] - 8, hip[1] - 27), (hip[0] + 8, hip[1] - 27), (hip[0] + 10, hip[1] - 16), (hip[0] + 7, hip[1] - 2)]]
    d.polygon(inner, fill=BARKD[4])
    # fissures de braise dans l'écorce
    cracks = [[(-6, -4), (-3, -12), (-6, -20), (-2, -26)], [(4, -6), (7, -14), (3, -22)], [(-10, -14), (-5, -16)]]
    for cr in cracks:
        pts = [rot((hip[0] + x, hip[1] + y)) for x, y in cr]
        d.line(pts, fill=EMB[2], width=2); d.line(pts, fill=EMB[1] if glow < 0.5 else EMB[0], width=1)
    shoulder_f = rot((hip[0] - 12, hip[1] - 27)); shoulder_b = rot((hip[0] + 11, hip[1] - 27))
    # bras arrière
    def arm(sh, a1, a2, col):
        el = (sh[0] - math.sin(math.radians(a1)) * 11, sh[1] + math.cos(math.radians(a1)) * 11)
        ha = (el[0] - math.sin(math.radians(a2)) * 10, el[1] + math.cos(math.radians(a2)) * 10)
        d.line([sh, el], fill=col, width=7); d.line([el, ha], fill=col, width=6)
        d.ellipse((ha[0] - 4, ha[1] - 4, ha[0] + 4, ha[1] + 4), fill=BARKD[2])
        return ha
    arm(shoulder_b, arm_b * 0.6, arm_b * 0.4, BARKD[2])
    # tête : masque de bois, crinière de fumée
    head = rot((hip[0] - 2, hip[1] - 36))
    for k in range(7):                                   # crinière de fumée et de cendre
        a = math.radians(-160 + k * 22 + t * 9)
        r = 9 + (k % 3) * 2
        d.ellipse((head[0] + math.cos(a) * r - 4, head[1] + math.sin(a) * r * 0.8 - 4 - 3, head[0] + math.cos(a) * r + 4, head[1] + math.sin(a) * r * 0.8 + 4 - 3), fill=C("3a3430", 230))
    d.ellipse((head[0] - 8, head[1] - 9, head[0] + 8, head[1] + 8), fill=BARKD[4])
    d.polygon([(head[0] - 8, head[1] - 2), (head[0] - 12, head[1] + 2), (head[0] - 7, head[1] + 4)], fill=BARKD[4])   # mâchoire
    d.polygon([(head[0] - 3, head[1] - 9), (head[0] - 1, head[1] - 16), (head[0] + 2, head[1] - 9)], fill=BARKD[3])   # corne
    d.polygon([(head[0] + 4, head[1] - 8), (head[0] + 8, head[1] - 14), (head[0] + 7, head[1] - 6)], fill=BARKD[3])
    eye = EMB[0] if glow > 0.5 else EMB[1]
    d.rectangle((head[0] - 7, head[1] - 3, head[0] - 3, head[1] - 1), fill=eye)
    d.rectangle((head[0] + 0, head[1] - 3, head[0] + 3, head[1] - 1), fill=eye)
    d.line([(head[0] - 7, head[1] + 3), (head[0] + 1, head[1] + 4)], fill=EMB[2])                                   # bouche
    # bras avant et massue
    hand = arm(shoulder_f, arm_a, arm_b * 0.7, BARKD[3])
    ca = math.radians(club_a)
    tip = (hand[0] + math.sin(ca) * 26, hand[1] - math.cos(ca) * 26)
    d.line([hand, tip], fill=BARKD[2], width=6)
    d.ellipse((tip[0] - 7, tip[1] - 7, tip[0] + 7, tip[1] + 7), fill=BARKD[3])
    for k in range(5):                                    # la tête de massue brûle
        a = ca + math.radians(-60 + k * 30)
        fx, fy = tip[0] + math.sin(a) * 7, tip[1] - math.cos(a) * 7
        d.polygon([(fx - 2, fy), (fx + 2, fy), (fx + math.sin(a) * 5, fy - math.cos(a) * 5 - 2)], fill=EMB[1])
    d.ellipse((tip[0] - 3, tip[1] - 3, tip[0] + 3, tip[1] + 3), fill=EMB[0])
    im = outline(im)
    if glow > 0.5:                                        # en fureur : un halo de braise autour du corps
        a = np.array(im).astype(float)
        m = a[..., 3] > 0
        halo = np.zeros_like(m)
        for dx in (-2, -1, 1, 2):
            for dy in (-2, -1, 1, 2):
                halo |= np.roll(np.roll(m, dx, 1), dy, 0)
        halo &= ~m
        a[halo] = (255, 120, 30, 150)
        im = Image.fromarray(a.astype(np.uint8))
    return im


def spear():
    im = Image.new("RGBA", (22, 6), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.line([(2, 3), (16, 3)], fill=BARKD[3], width=2)
    d.polygon([(16, 0), (21, 3), (16, 5)], fill=EMB[1]); d.point((18, 3), fill=EMB[0])
    for x in range(3, 15, 4):
        d.point((x, 2), fill=EMB[2])
    return im


def flame(i):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    r = random.Random(i * 7)
    for k in range(4):
        x = 2 + k * 4 + r.randint(-1, 1); h = 8 + r.randint(0, 6) + (i + k) % 3
        d.polygon([(x - 3, 16), (x + 3, 16), (x + r.randint(-1, 1), 16 - h)], fill=EMB[2])
        d.polygon([(x - 2, 16), (x + 2, 16), (x, 16 - h * 0.65)], fill=EMB[1])
        d.polygon([(x - 1, 16), (x + 1, 16), (x, 16 - h * 0.35)], fill=EMB[0])
    return im


if __name__ == "__main__":
    sheet([[bat_frame(i) for i in range(4)]], 24, 16).save(f"{OUT}/bat.png")
    eyes = sheet([[bat_frame(i, True) for i in range(4)]], 24, 16)
    eyes.save(f"{OUT}/bat_eyes.png")
    sheet([[rat_frame(i) for i in range(2)]], 16, 10).save(f"{OUT}/rat.png")
    sheet([[golem_frame(i) for i in range(4)], [golem_frame(i, True) for i in range(2)]], 34, 38).save(f"{OUT}/golem.png")
    sheet([[bird_frame(i) for i in range(3)]], 14, 12).save(f"{OUT}/bird.png")
    sheet([[drum_frame(v, False) for v in range(3)], [drum_frame(v, True) for v in range(3)]], 26, 34).save(f"{OUT}/drum_tree.png")
    root_gate().save(f"{OUT}/root_gate.png")
    root_tile().save(f"{OUT}/root_tile.png")
    # (Adan a son propre générateur : adan.py)
    spear().save(f"{OUT}/spear.png")
    sheet([[flame(i) for i in range(4)]], 16, 16).save(f"{OUT}/flame.png")
    # aperçu
    names = ["bat", "rat", "golem", "bird", "drum_tree", "root_gate", "root_tile", "spear", "flame"]
    ims = [Image.open(f"{OUT}/{n}.png") for n in names]
    Wp = max(im.width for im in ims) * 3; Hp = sum(im.height * 3 + 6 for im in ims)
    prev = Image.new("RGBA", (Wp, Hp), (40, 58, 52, 255)); y = 0
    for im in ims:
        prev.alpha_composite(im.resize((im.width * 3, im.height * 3), Image.NEAREST), (0, y)); y += im.height * 3 + 6
    prev.save(f"{OUT}/creatures_prev.png")
