"""Adan, « la Colère », serviteur d'Adaka : planche d'animation (96 × 96 par image, regard à gauche).

Silhouette : un colosse voûté, épaules énormes hérissées d'éclats d'écorce, petite tête basse
enfoncée entre elles, bras qui tombent jusqu'aux genoux, jambes courtes et massives.
Matière : écorce noircie en plaques superposées, fendue de braises ; au milieu de la poitrine
un cœur de braise qui bat. Masque de bois sculpté aux yeux de feu ; une crinière de fumée et
de cendre qui monte. Arme : une branche d'iroko arrachée, dont la tête brûle.

Lignes : idle(2) walk(4) charge(2) throw(3) slam(3) hurt(1) fury(2) dead(1)
"""
import math, sys
import numpy as np
from PIL import Image, ImageDraw

OUT = sys.argv[1]
W, H = 144, 136
GY = 132
BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
YY, XX = np.mgrid[0:H, 0:W]


def C(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.uint8)


BARK = [C(c) for c in ("0e0a08", "1a1310", "281d17", "382920", "4a372b", "5e4738", "735a48")]
BARK_L = [C(c) for c in ("1a1310", "2c211a", "3e2e24", "55402f", "6c523e", "866a52")]   # plaques claires
EMB = [C(c) for c in ("6a1206", "a8280a", "e2521a", "ff8a2a", "ffc25a", "fff0b0")]
SMOKE = [C(c) for c in ("2a2624", "3a3532", "4e4844", "645d57")]
OUTL = C("0a0706")


class Frame:
    def __init__(self):
        self.rgb = np.zeros((H, W, 3), np.uint8)
        self.a = np.zeros((H, W), np.uint8)       # 0 vide, 255 plein, autre = transparence (fumée)

    def mask(self, fn):
        im = Image.new("L", (W, H), 0)
        fn(ImageDraw.Draw(im))
        return np.array(im) > 127

    def paint(self, m, val, pal, alpha=255):
        idx = np.clip(np.floor(val * (len(pal) - 1) + BAY[YY % 4, XX % 4]), 0, len(pal) - 1).astype(int)
        for i, c in enumerate(pal):
            sel = m & (idx == i)
            self.rgb[sel] = c
            self.a[sel] = np.maximum(self.a[sel], alpha)

    def outline(self):
        m = self.a == 255
        o = np.zeros_like(m)
        o[1:] |= m[:-1]; o[:-1] |= m[1:]; o[:, 1:] |= m[:, :-1]; o[:, :-1] |= m[:, 1:]
        o &= ~m
        self.rgb[o] = OUTL
        self.a[o] = 255

    def image(self):
        im = np.zeros((H, W, 4), np.uint8)
        im[..., :3] = self.rgb
        im[..., 3] = self.a
        return Image.fromarray(im, "RGBA")


def lit(cx, cy, r):
    """Éclairage d'une forme ronde : lumière venue d'en haut à gauche (et un reflet de braise en bas)."""
    return np.clip(0.55 - ((XX - cx) + (YY - cy)) / (2.6 * r), 0, 1)


def limb(f, a, b, w0, w1, pal, light=1.0):
    """Un membre : un tronc de cône d'écorce de a vers b, ombré dans sa largeur."""
    ax, ay = a; bx, by = b
    dx, dy = bx - ax, by - ay
    L = math.hypot(dx, dy) + 1e-6
    nx, ny = -dy / L, dx / L
    poly = [(ax + nx * w0, ay + ny * w0), (bx + nx * w1, by + ny * w1), (bx - nx * w1, by - ny * w1), (ax - nx * w0, ay - ny * w0)]
    m = f.mask(lambda d: (d.polygon(poly, fill=255), d.ellipse((bx - w1, by - w1, bx + w1, by + w1), fill=255), d.ellipse((ax - w0, ay - w0, ax + w0, ay + w0), fill=255)))
    # position dans la largeur : -1..1 (le côté +n est à l'ombre)
    side = ((XX - ax) * nx + (YY - ay) * ny) / max(w0, w1)
    rings = np.sin(((XX - ax) * dx + (YY - ay) * dy) / L * 0.9)
    val = (0.55 - 0.3 * side) * light + 0.08 * rings
    f.paint(m, np.clip(val, 0, 1), pal)
    return m


def embers_line(f, pts, glow):
    im = Image.new("L", (W, H), 0); d = ImageDraw.Draw(im)
    d.line(pts, fill=255, width=2)
    m = np.array(im) > 127
    im2 = Image.new("L", (W, H), 0); d2 = ImageDraw.Draw(im2)
    d2.line(pts, fill=255, width=1)
    core = np.array(im2) > 127
    on = f.a == 255
    f.rgb[m & on] = EMB[2]
    f.rgb[core & on] = EMB[4 if glow else 3]


def draw(pose, t):
    f = Frame()
    # --- paramètres de pose (angles en degrés, 0 = vers le bas, positif = vers l'avant/gauche)
    P = dict(lean=8, crouch=0, stride=0, fsh=20, fel=40, bsh=-10, bel=20, club=25, mane=t, glow=False, head_dy=0)
    if pose == "idle":
        P.update(crouch=[0, 1][t], fsh=[18, 20][t], fel=[38, 40][t])
    elif pose == "walk":
        P.update(stride=[-6, 0, 6, 0][t], crouch=[0, 2, 0, 2][t], fsh=20 + [-6, 0, 6, 0][t], bsh=-10 - [-6, 0, 6, 0][t])
    elif pose == "charge":
        P.update(lean=26, crouch=6, stride=[-9, 9][t], fsh=70, fel=80, bsh=-40, bel=-20, club=95)
    elif pose == "throw":
        P.update(lean=[-6, -10, 18][t], crouch=[2, 3, 1][t], fsh=[150, 170, 40][t], fel=[160, 175, 30][t], club=[230, 250, 120][t])
    elif pose == "slam":
        P.update(lean=[-4, -8, 24][t], crouch=[3, 0, 8][t], fsh=[160, 185, 60][t], fel=[170, 190, 70][t], bsh=[150, 175, 50][t], bel=[160, 185, 60][t], club=[200, 230, 95][t])
    elif pose == "hurt":
        P.update(lean=-14, crouch=3, fsh=-20, fel=10, club=-20, head_dy=2)
    elif pose == "fury":
        P.update(lean=-8, crouch=4, fsh=[120, 128][t], fel=[150, 158][t], bsh=[110, 118][t], bel=[140, 150][t], club=[200, 210][t], glow=True)
    elif pose == "dead":
        P.update(lean=34, crouch=18, fsh=10, fel=10, bsh=0, bel=0, club=80)
    lean = math.radians(P["lean"])
    hip = (94 + P["lean"] * 0.25, GY - 24 + P["crouch"])
    def rot(dx, dy):
        """Point du buste (repère hanche), tourné de l'inclinaison."""
        return (hip[0] + dx * math.cos(lean) + dy * math.sin(lean), hip[1] - dx * math.sin(lean) * -1 * 0 + dy * math.cos(lean) - dx * math.sin(lean) * 0)
    def R(dx, dy):
        c, s = math.cos(lean), math.sin(lean)
        return (hip[0] + dx * c + dy * s, hip[1] - dx * s * 0 + dy * c + (-dx) * s * 0 + dx * 0)
    def P2(dx, dy):
        c, s = math.cos(lean), math.sin(lean)
        # inclinaison vers l'avant (la gauche) : le haut du corps part à gauche
        return (hip[0] + dx * c + dy * s, hip[1] + dy * c - dx * s * 0.0)

    # 1. la fumée de la crinière (derrière tout), semi-transparente
    head = P2(-4, -44 + P["head_dy"])
    for k in range(10):
        a = math.radians(-170 + k * 18)
        rise = (P["mane"] * 3 + k * 5) % 14
        cx = head[0] + math.cos(a) * 12 + 3
        cy = head[1] - 6 + math.sin(a) * 7 - rise - 4
        r = 5 + (k % 3)
        m = f.mask(lambda d, cx=cx, cy=cy, r=r: d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255))
        f.paint(m & (f.a == 0), lit(cx, cy, r), SMOKE, alpha=170)
    # 2. bras arrière
    bsh = P2(12, -36)
    bel = (bsh[0] - math.sin(math.radians(P["bsh"])) * 15, bsh[1] + math.cos(math.radians(P["bsh"])) * 15)
    bha = (bel[0] - math.sin(math.radians(P["bel"])) * 14, bel[1] + math.cos(math.radians(P["bel"])) * 14)
    limb(f, bsh, bel, 7, 6, BARK, 0.7); limb(f, bel, bha, 6, 6, BARK, 0.7)
    m = f.mask(lambda d: d.ellipse((bha[0] - 6, bha[1] - 5, bha[0] + 6, bha[1] + 6), fill=255)); f.paint(m, lit(*bha, 6) * 0.7, BARK)
    # 3. jambes
    for s_, off in ((1, -P["stride"]), (-1, P["stride"])):
        h0 = (hip[0] + s_ * 7, hip[1])
        knee = (hip[0] + s_ * 8 + off * 0.5 - 3, hip[1] + 11)
        foot = (hip[0] + s_ * 9 + off, GY - 3)
        light = 0.75 if s_ > 0 else 1.0
        limb(f, h0, knee, 9, 8, BARK, light); limb(f, knee, foot, 8, 7, BARK, light)
        m = f.mask(lambda d, foot=foot: d.polygon([(foot[0] - 11, GY), (foot[0] + 6, GY), (foot[0] + 5, GY - 7), (foot[0] - 8, GY - 8)], fill=255))
        f.paint(m, lit(foot[0], GY - 4, 8) * light, BARK)
    # 4. le buste : une masse en tonneau, voûtée
    torso_pts = [P2(-16, -2), P2(-22, -18), P2(-22, -34), P2(-12, -46), P2(14, -46), P2(24, -34), P2(20, -16), P2(14, -2)]
    m_torso = f.mask(lambda d: d.polygon(torso_pts, fill=255))
    tc = P2(0, -24)
    f.paint(m_torso, lit(tc[0], tc[1], 24) * 0.9 + 0.05, BARK)
    # plaques d'écorce superposées (plus claires, bord supérieur éclairé)
    for (dx, dy, w, h) in ((-12, -38, 16, 10), (4, -40, 16, 10), (-16, -26, 14, 12), (8, -28, 14, 12), (-10, -14, 14, 10), (6, -14, 12, 10)):
        p = [P2(dx, dy), P2(dx + w, dy - 1), P2(dx + w - 1, dy + h), P2(dx + 1, dy + h + 1)]
        mm = f.mask(lambda d, p=p: d.polygon(p, fill=255)) & m_torso
        cx, cy = P2(dx + w / 2, dy + h / 2)
        f.paint(mm, lit(cx, cy, w), BARK_L)
        top = f.mask(lambda d, p=p: d.line([p[0], p[1]], fill=255)) & m_torso
        f.rgb[top] = BARK_L[5]
    # éclats d'écorce sur les épaules (cornes)
    for (dx, dy, tx, ty) in ((-20, -40, -30, -52), (-12, -46, -16, -58), (16, -44, 24, -56), (22, -36, 32, -44)):
        a, b = P2(dx, dy), P2(tx, ty)
        mm = f.mask(lambda d, a=a, b=b: d.polygon([(a[0] - 4, a[1]), (a[0] + 4, a[1] + 1), b], fill=255))
        f.paint(mm, lit(a[0], a[1], 6), BARK_L)
    # fissures de braise et le cœur
    for cr in ([(-14, -30), (-9, -24), (-12, -16), (-7, -8)], [(10, -34), (6, -27), (11, -20)], [(-4, -42), (0, -36)]):
        embers_line(f, [P2(*p) for p in cr], P["glow"])
    heart = P2(-2, -26)
    hr = 5 if not P["glow"] else 6
    m = f.mask(lambda d: d.ellipse((heart[0] - hr, heart[1] - hr, heart[0] + hr, heart[1] + hr), fill=255))
    f.paint(m, np.clip(1 - np.hypot(XX - heart[0], YY - heart[1]) / hr, 0, 1), EMB[1:])
    # 5. la tête : masque de bois, enfoncée entre les épaules
    m = f.mask(lambda d: d.polygon([(head[0] - 10, head[1] - 6), (head[0] - 4, head[1] - 12), (head[0] + 8, head[1] - 11), (head[0] + 11, head[1] - 2),
                                    (head[0] + 7, head[1] + 9), (head[0] - 6, head[1] + 10), (head[0] - 13, head[1] + 3)], fill=255))
    f.paint(m, lit(head[0], head[1], 11), BARK_L)
    # front sculpté, yeux de feu, bouche dentelée
    brow = f.mask(lambda d: d.line([(head[0] - 11, head[1] - 3), (head[0] - 2, head[1] - 5), (head[0] + 7, head[1] - 4)], fill=255, width=2))
    f.rgb[brow & (f.a == 255)] = BARK[1]
    eye = EMB[5] if P["glow"] else EMB[4]
    for ex in (-8, 1):
        mm = f.mask(lambda d, ex=ex: d.polygon([(head[0] + ex, head[1] - 2), (head[0] + ex + 5, head[1] - 2), (head[0] + ex + 4, head[1] + 1), (head[0] + ex + 1, head[1] + 1)], fill=255))
        f.rgb[mm] = eye; f.a[mm] = 255
    mouth = [(head[0] - 9, head[1] + 5), (head[0] - 6, head[1] + 3), (head[0] - 4, head[1] + 6), (head[0] - 1, head[1] + 3), (head[0] + 2, head[1] + 6), (head[0] + 5, head[1] + 4)]
    mm = f.mask(lambda d: d.line(mouth, fill=255, width=2))
    f.rgb[mm & (f.a == 255)] = EMB[2]
    # 6. bras avant et la massue
    fsh = P2(-18, -36)
    fel = (fsh[0] - math.sin(math.radians(P["fsh"])) * 16, fsh[1] + math.cos(math.radians(P["fsh"])) * 16)
    fha = (fel[0] - math.sin(math.radians(P["fel"])) * 15, fel[1] + math.cos(math.radians(P["fel"])) * 15)
    ca = math.radians(P["club"])
    tip = (fha[0] - math.sin(ca) * 30, fha[1] + math.cos(ca) * 30)
    limb(f, fha, tip, 3, 5, BARK, 0.9)
    for k in range(3):                       # nœuds de la branche
        p = (fha[0] + (tip[0] - fha[0]) * (0.35 + k * 0.2), fha[1] + (tip[1] - fha[1]) * (0.35 + k * 0.2))
        f.rgb[int(p[1]) % H, int(p[0]) % W] = BARK_L[4]
    m = f.mask(lambda d: d.ellipse((tip[0] - 9, tip[1] - 9, tip[0] + 9, tip[1] + 9), fill=255))
    f.paint(m, lit(tip[0], tip[1], 9), BARK)
    for k in range(4):
        cr = [(tip[0] + math.cos(k * 1.6) * 7, tip[1] + math.sin(k * 1.6) * 7), (tip[0] + math.cos(k * 1.6 + 0.8) * 3, tip[1] + math.sin(k * 1.6 + 0.8) * 3)]
        embers_line(f, cr, True)
    limb(f, fsh, fel, 8, 7, BARK, 1.0); limb(f, fel, fha, 7, 6, BARK, 1.0)
    m = f.mask(lambda d: d.ellipse((fha[0] - 7, fha[1] - 6, fha[0] + 6, fha[1] + 7), fill=255)); f.paint(m, lit(*fha, 7), BARK_L)
    f.outline()
    # 7. les flammes de la massue (après le contour : elles débordent, lumineuses)
    for k in range(7):
        a = ca + math.pi + math.radians(-80 + k * 27)
        bx, by = tip[0] + math.sin(a) * -6, tip[1] + math.cos(a) * 6
        hgt = 7 + (k * 3 + t * 5) % 6
        m = f.mask(lambda d, bx=bx, by=by, hgt=hgt: d.polygon([(bx - 3, by), (bx + 3, by), (bx + (k % 3 - 1), by - hgt)], fill=255))
        f.paint(m & (f.a == 0), np.clip((YY - (by - hgt)) / hgt, 0, 1), EMB[2:][::-1])
    if P["glow"]:                             # fureur : halo de braise autour du corps
        mm = f.a == 255
        halo = np.zeros_like(mm)
        for dx in (-2, -1, 1, 2):
            for dy in (-2, -1, 1, 2):
                halo |= np.roll(np.roll(mm, dx, 1), dy, 0)
        halo[:2] = False; halo[-2:] = False; halo[:, :2] = False; halo[:, -2:] = False
        halo &= ~mm
        f.rgb[halo] = EMB[3]; f.a[halo] = 200
    return f.image()


POSES = [("idle", 2), ("walk", 4), ("charge", 2), ("throw", 3), ("slam", 3), ("hurt", 1), ("fury", 2), ("dead", 1)]
if __name__ == "__main__":
    sheet = Image.new("RGBA", (W * 4, H * len(POSES)), (0, 0, 0, 0))
    for j, (p, n) in enumerate(POSES):
        for i in range(n):
            sheet.paste(draw(p, i), (i * W, j * H))
    sheet.save(f"{OUT}/adan.png")
    prev = Image.new("RGBA", sheet.size, (38, 52, 46, 255)); prev.alpha_composite(sheet)
    prev.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(f"{OUT}/adan_prev.png")
