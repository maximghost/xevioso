"""Sprites des cinq Envoyés, version squelette.

Chaque image est calculée à partir d'un squelette articulé (bassin, tronc, cou, tête,
cuisse + tibia + pied, bras + avant-bras + main) piloté par des angles d'articulation.
Les héros sont ensuite « habillés » par-dessus le squelette : les vêtements, les
accessoires et les éléments souples (bandeau, pagne, tresses) suivent donc exactement
les mouvements du corps.

Conventions
-----------
* Cellule 40 x 60, héros tourné vers la droite, plante des pieds sur la ligne 50,
  bassin sur la colonne 16 (marge pour les gestes amples).
* Coordonnées = centres des pixels (le pixel (x, y) a pour centre (x, y)).
* Angles en degrés : 0 = vers le bas, positif = vers l'avant (vers +x).
  - jambe : (cuisse, flexion du genou) ; le tibia part vers l'arrière de la flexion ;
  - bras  : (bras, flexion du coude) ; l'avant-bras se plie vers l'avant ;
  - lean  : inclinaison du tronc autour du bassin (positif = penché en avant).
* Pieds au sol : cinématique inverse (on donne la position du pied, le genou est calculé),
  ce qui garantit des appuis qui ne glissent pas.
* Pieds en l'air : cinématique directe (on donne les angles).

Sorties : out2/<héros>.png (lignes = animations, colonnes = images), out2/<héros>_frames.tres,
et des aperçus agrandis prev2_<héros>.png.
"""
import math, os
from PIL import Image

W, H = 40, 60
ANKLE_Y = 49          # cheville d'un pied posé (le pied occupe les lignes 49 et 50)
HIP_X = 16.0         # axe du bassin (milieu de la cellule)
OUT = "#1b1325"       # contour
BOLT = "#f6e27a"      # marque de foudre

# ---------------------------------------------------------------------------
# Outils de dessin (grille de couleurs, None = transparent)
# ---------------------------------------------------------------------------
def new(): return [[None] * W for _ in range(H)]

def px(g, x, y, c):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < W and 0 <= y < H: g[y][x] = c

def _dist_seg(px_, py_, a, b):
    ax, ay = a; bx, by = b
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px_ - ax) * dx + (py_ - ay) * dy) / l2))
    qx, qy = ax + t * dx, ay + t * dy
    return math.hypot(px_ - qx, py_ - qy)

def seg(g, a, b, r, c):
    """Segment épais : tous les pixels dont le centre est à moins de r du segment."""
    x0, x1 = int(math.floor(min(a[0], b[0]) - r)), int(math.ceil(max(a[0], b[0]) + r))
    y0, y1 = int(math.floor(min(a[1], b[1]) - r)), int(math.ceil(max(a[1], b[1]) + r))
    for y in range(max(0, y0), min(H, y1 + 1)):
        for x in range(max(0, x0), min(W, x1 + 1)):
            if _dist_seg(x, y, a, b) <= r: g[y][x] = c

def poly(g, pts, c):
    """Polygone plein (test pair-impair sur les centres des pixels)."""
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    for y in range(max(0, int(min(ys)) - 1), min(H, int(max(ys)) + 2)):
        for x in range(max(0, int(min(xs)) - 1), min(W, int(max(xs)) + 2)):
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]; xj, yj = pts[j]
                if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                    inside = not inside
                j = i
            if inside: g[y][x] = c

def rect(g, x0, y0, x1, y1, c):
    for y in range(int(min(y0, y1)), int(max(y0, y1)) + 1):
        for x in range(int(min(x0, x1)), int(max(x0, x1)) + 1): px(g, x, y, c)

def outline(g, color=OUT):
    m = [(x, y) for y in range(H) for x in range(W) if g[y][x] is None and any(
        0 <= x + dx < W and 0 <= y + dy < H and g[y + dy][x + dx] not in (None, color)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in m: g[y][x] = color

def layer_onto(dst, src, edge=None):
    """Pose un calque sur la grille ; « edge » trace un liseré sombre là où le calque
    recouvre un pixel déjà peint (sépare un membre du corps sans alourdir la silhouette)."""
    for y in range(H):
        for x in range(W):
            if src[y][x] is None: continue
            if edge and dst[y][x] is not None and any(
                    0 <= x + dx < W and 0 <= y + dy < H and src[y + dy][x + dx] is None
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) and not any(
                    0 <= x + dx < W and 0 <= y + dy < H and src[y + dy][x + dx] is None and dst[y + dy][x + dx] is None
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dst[y][x] = edge
            else:
                dst[y][x] = src[y][x]

def shade(hexc, f=0.72):
    c = hexc.lstrip("#")
    r, g_, b = (int(c[k:k + 2], 16) for k in (0, 2, 4))
    return "#%02x%02x%02x" % (int(r * f), int(g_ * f), int(b * f))

def d(a):
    """Vecteur unitaire pour un angle (0 = bas, positif = avant)."""
    r = math.radians(a)
    return (math.sin(r), math.cos(r))

def add(p, v, k=1.0): return (p[0] + v[0] * k, p[1] + v[1] * k)
def lerp(a, b, t): return a + (b - a) * t

# ---------------------------------------------------------------------------
# Squelette
# ---------------------------------------------------------------------------
class Body:
    """Proportions d'un héros."""
    def __init__(self, thigh=8.0, shin=7.5, torso=13.0, upper=6.0, fore=6.0, half=4.0):
        self.thigh, self.shin, self.torso = thigh, shin, torso
        self.upper, self.fore, self.half = upper, fore, half

    @property
    def leg(self): return self.thigh + self.shin


def ik_leg(hip, ankle, a, b):
    """Genou d'une jambe à deux segments, plié vers l'avant (vers +x)."""
    dx, dy = ankle[0] - hip[0], ankle[1] - hip[1]
    dist = min(math.hypot(dx, dy), a + b - 0.01)
    base = math.atan2(dy, dx)
    cos_k = (a * a + dist * dist - b * b) / (2 * a * dist)
    phi = math.acos(max(-1.0, min(1.0, cos_k)))
    # deux solutions : on garde celle où le genou passe devant
    cands = [(hip[0] + a * math.cos(base + s * phi), hip[1] + a * math.sin(base + s * phi)) for s in (1, -1)]
    knee = max(cands, key=lambda k: k[0])
    # la cheville est recalée à distance exacte (si la jambe était trop courte)
    ux, uy = (ankle[0] - knee[0]), (ankle[1] - knee[1])
    l = math.hypot(ux, uy) or 1
    return knee, (knee[0] + ux / l * b, knee[1] + uy / l * b)


def solve(pose, body):
    """Calcule toutes les positions d'articulation d'une pose."""
    L = pose["lean"]
    up_v, right_v = (math.sin(math.radians(L)), -math.cos(math.radians(L))), (math.cos(math.radians(L)), math.sin(math.radians(L)))

    # Hauteur du bassin
    if pose["ground"]:
        hip_y = ANKLE_Y - body.leg * 0.97 + pose["drop"]
    else:
        hip_y = ANKLE_Y - body.leg + pose["hy"]
    hip = (HIP_X + pose.get("hx", 0), hip_y)

    J = {"hip": hip, "lean": L}
    T = lambda lx, h: (hip[0] + lx * right_v[0] + h * up_v[0], hip[1] + lx * right_v[1] + h * up_v[1])
    J["T"] = T

    # Jambes : « hips » proche (devant) et éloignée (derrière, décalée d'un pixel)
    for side, hx in (("n", -0.5), ("f", 0.8)):
        hp = T(hx, 0)
        spec = pose[side + "l"]
        if spec[0] == "ik":
            fx = spec[1]
            fy = spec[2] if len(spec) > 2 else ANKLE_Y
            knee, ankle = ik_leg(hp, (fx, fy), body.thigh, body.shin)
        else:
            _, t, k = spec
            knee = add(hp, d(t), body.thigh)
            ankle = add(knee, d(t - k), body.shin)
        # le pied : à plat près du sol, sinon perpendiculaire au tibia (pointe tendue en l'air)
        sa = math.degrees(math.atan2(ankle[0] - knee[0], ankle[1] - knee[1]))
        grounded = ankle[1] >= ANKLE_Y - 0.6
        J[side + "hip"], J[side + "knee"], J[side + "ankle"], J[side + "ground"] = hp, knee, ankle, grounded
        J[side + "foot_a"] = 90 if grounded else max(40, min(140, sa + 100))

    # Bras
    for side, (lx, h) in (("n", (0.5, 12.0)), ("f", (-0.8, 12.5))):
        sh = T(lx, h * body.torso / 13.0)
        sh = (sh[0] + 0.5, sh[1])               # bras de 2 pixels : axe décalé d'un demi-pixel
        u, e = pose[side + "a"]
        el = add(sh, d(u), body.upper)
        hand = add(el, d(u + e), body.fore)
        J[side + "sh"], J[side + "el"], J[side + "hand"] = sh, el, hand
        J[side + "fore_a"] = u + e

    neck = T(0.3, body.torso + 1)
    J["neck"] = neck
    J["head"] = (int(round(neck[0] + pose["hdx"])) - 3, int(round(neck[1] + pose["hdy"])) - 10)
    return J


# ---------------------------------------------------------------------------
# Poses (images-clés)
# ---------------------------------------------------------------------------
def K(**kw):
    p = dict(lean=0.0, ground=True, drop=0.0, hy=0.0, hx=0.0,
             nl=("ik", 18), fl=("ik", 13), na=(6, 14), fa=(-6, 14),
             hdx=0, hdy=0, eye="open", wind=(0.15, 0.0), t=0.0, flash=False, mouth="calm")
    p.update(kw)
    return p

# --- repos : respiration (le bassin descend d'un pixel, les bras suivent) ---
IDLE = []
for i in range(6):
    s = math.sin(2 * math.pi * i / 6)
    IDLE.append(K(lean=2 + 0.6 * s, drop=0.0 if s > 0.2 else (1.0 if s < -0.2 else 0.5),
                  na=(5 - 3 * s, 16 + 4 * s), fa=(-7 + 2 * s, 14 - 3 * s),
                  wind=(0.12, 0.0), t=i / 6))

# --- course : 8 images, appui / amorti / passage / poussée / suspension ---
# (cuisse, flexion) de la jambe proche ; la jambe éloignée est décalée d'une demi-foulée.
RUN_LEG = [(34, 14), (20, 34), (2, 26), (-22, 14), (-36, 44), (-14, 98), (20, 86), (40, 38)]
RUN_UP = [0.0, 0.0, 0.5, 1.5]      # rebond vertical du bassin
RUN = []
for i in range(8):
    nt, nk = RUN_LEG[i]; ft, fk = RUN_LEG[(i + 4) % 8]
    up = RUN_UP[i % 4]
    RUN.append(K(lean=13 + (1 if up > 0.5 else 0), ground=False,
                 hy=0.0, hx=2.0, nl=("fk", nt, nk), fl=("fk", ft, fk),
                 # bras opposés aux jambes : le bras proche avance avec la jambe éloignée
                 na=(1.15 * ft, 78 + 0.35 * ft), fa=(1.15 * nt, 78 + 0.35 * nt),
                 hdx=1, wind=(1.0, 0.0), t=i / 8, run_up=up))

# --- saut : impulsion, montée, sommet groupé ---
JUMP = [
    K(lean=6, ground=False, hy=-1, nl=("fk", -8, 6), fl=("fk", 58, 92), na=(142, 18), fa=(-45, 30),
      wind=(0.3, -0.7), t=0.0, hdx=1),
    K(lean=4, ground=False, hy=-1, nl=("fk", 18, 62), fl=("fk", 52, 104), na=(128, 30), fa=(-25, 40),
      wind=(0.3, -0.5), t=0.3, hdx=1),
    K(lean=3, ground=False, hy=-2, nl=("fk", 44, 102), fl=("fk", 30, 92), na=(70, 60), fa=(15, 55),
      wind=(0.25, 0.0), t=0.6, hdx=1),
]

# --- chute : jambes tendues vers le sol, bras écartés qui battent ---
FALL = [
    K(lean=2, ground=False, hy=0, nl=("fk", 12, 22), fl=("fk", -14, 38), na=(135, 12), fa=(-118, 18),
      wind=(0.2, 1.0), t=0.0, mouth="open"),
    K(lean=2, ground=False, hy=0, nl=("fk", 14, 26), fl=("fk", -12, 34), na=(148, 18), fa=(-128, 22),
      wind=(0.2, 1.0), t=0.33, mouth="open"),
    K(lean=2, ground=False, hy=0, nl=("fk", 10, 20), fl=("fk", -16, 40), na=(140, 8), fa=(-122, 14),
      wind=(0.2, 1.0), t=0.66, mouth="open"),
]

# --- lancer : armé, détente, accompagnement, retour (la hache part dès l'appui) ---
THROW = [
    K(lean=-9, drop=1, hx=1, nl=("ik", 20), fl=("ik", 12), na=(-150, 40), fa=(45, 40), hdx=-1,
      wind=(0.2, 0.0), t=0.0, mouth="grit"),
    K(lean=15, drop=2, hx=1, nl=("ik", 22), fl=("ik", 11), na=(98, 8), fa=(-42, 30), hdx=1,
      wind=(0.6, 0.0), t=0.2, flash=True, mouth="open"),
    K(lean=18, drop=2, hx=1, nl=("ik", 22), fl=("ik", 11), na=(42, 18), fa=(-52, 40), hdx=1,
      wind=(0.5, 0.0), t=0.4, mouth="grit"),
    K(lean=11, drop=1, hx=1, nl=("ik", 21), fl=("ik", 12), na=(20, 30), fa=(-30, 30),
      wind=(0.3, 0.0), t=0.6),
    K(lean=5, drop=0.5, nl=("ik", 19), fl=("ik", 13), na=(8, 22), fa=(-12, 20),
      wind=(0.15, 0.0), t=0.8),
]
THROW_DUR = [1.0, 1.0, 1.0, 1.4, 1.2]

# --- touché : recul brutal, bras projetés, puis il se reprend ---
HURT = [
    K(lean=-18, drop=2, hx=2, nl=("ik", 19), fl=("ik", 13), na=(150, 30), fa=(-150, 35), hdx=-1, hdy=0,
      eye="shut", wind=(0.7, 0.3), t=0.0, mouth="open"),
    K(lean=-13, drop=3, hx=2, nl=("ik", 19), fl=("ik", 12), na=(120, 40), fa=(-140, 40), hdx=-1,
      eye="shut", wind=(0.5, 0.1), t=0.3, mouth="open"),
    K(lean=-6, drop=2, hx=1, nl=("ik", 20), fl=("ik", 14), na=(60, 40), fa=(-60, 40),
      eye="shut", wind=(0.3, 0.0), t=0.6, mouth="grit"),
]

# --- réception : écrasement sur les genoux, puis il se redresse ---
LAND = [
    K(lean=12, drop=5, nl=("ik", 20), fl=("ik", 11), na=(35, 50), fa=(-20, 50), hdy=1,
      wind=(0.2, 0.8), t=0.0, mouth="grit"),
    K(lean=8, drop=3, nl=("ik", 19), fl=("ik", 12), na=(20, 35), fa=(-14, 35),
      wind=(0.2, 0.3), t=0.3),
    K(lean=4, drop=1, nl=("ik", 18), fl=("ik", 13), na=(10, 20), fa=(-8, 18),
      wind=(0.15, 0.0), t=0.6),
]

# --- accroupi : genoux pliés, buste penché, la tête rentrée (le héros fait ~26 px de haut) ---
CROUCH = [
    K(lean=40, drop=9, hx=0, nl=("ik", 24), fl=("ik", 5), na=(70, 40), fa=(38, 50), hdx=2, hdy=2,
      wind=(0.15, 0.3), t=0.0, mouth="grit"),
    K(lean=41, drop=9.5, hx=0, nl=("ik", 24), fl=("ik", 5), na=(66, 44), fa=(34, 54), hdx=2, hdy=2,
      wind=(0.15, 0.3), t=0.5, mouth="grit"),
]
# --- marche accroupie : petits pas glissés, le buste reste bas ---
CRAWL = []
for i in range(4):
    s_ = math.sin(2 * math.pi * i / 4)
    CRAWL.append(K(lean=40, drop=9 + 0.5 * abs(s_), hx=0.5, nl=("ik", 23 + 3 * s_), fl=("ik", 6 - 2 * s_),
                   na=(62 + 10 * s_, 42), fa=(34 - 10 * s_, 50), hdx=2, hdy=2,
                   wind=(0.4, 0.2), t=i / 4, mouth="grit"))

ANIMS = {"idle": IDLE, "run": RUN, "jump": JUMP, "fall": FALL, "throw": THROW, "hurt": HURT, "land": LAND,
         "crouch": CROUCH, "crawl": CRAWL}
FPS = {"idle": 6, "run": 14, "jump": 12, "fall": 10, "throw": 18, "hurt": 12, "land": 20, "crouch": 3, "crawl": 9}
LOOP = {"idle": True, "run": True, "jump": False, "fall": True, "throw": False, "hurt": False, "land": False,
        "crouch": True, "crawl": True}
DUR = {"throw": THROW_DUR}

# La course est en cinématique directe : on pose le pied le plus bas sur le sol,
# puis on applique le rebond (positif = le corps monte, phase de suspension).
def ground_run(pose, body):
    p = dict(pose); p["hy"] = 0.0
    J = solve(p, body)
    low = max(J["nankle"][1], J["fankle"][1])
    p["hy"] = (ANKLE_Y - low) - pose.get("run_up", 0.0)
    return p

# ---------------------------------------------------------------------------
# Les héros
# ---------------------------------------------------------------------------
HEROES = {
    "kodjo": dict(skin="#6b3f26", hair="#1e1410", top="#e8772e", top2="#b9541d", trim="#f2e2c4",
                  bottom="#8c2f24", pants=0.25, extra="#d23a2c", body=Body()),
    "afi": dict(skin="#5a3421", hair="#2f3a8f", top="#2f3a8f", top2="#2a9d8f", trim="#f2c14e",
                extra="#2a9d8f", feet="#7a4a2b", sleeves=True, dress="long", body=Body()),
    "yawa": dict(skin="#7a4a2e", hair="#1e1410", top="#3fb6c6", top2="#2e95a4", trim="#f4efe3",
                 bottom="#1d5f8a", pants=0.85, extra="#c9a05a", feet="#5a3a22", body=Body()),
    "abla": dict(skin="#4f2e1c", hair="#1e1410", top="#3b2a3f", top2="#2c1f30", trim="#7a4a2b",
                 bottom="#3a3540", pants=1.0, extra="#6f7680", feet="#2a2228",
                 body=Body(thigh=8.0, shin=7.5, half=5.0, upper=6.0, fore=6.0)),
    "kokou": dict(skin="#6b4429", hair="#6b3fa0", top="#efe6d2", top2="#d8ccb2", trim="#d4a017",
                  extra="#8a5a33", feet="#8a5a33", sleeves=True, dress="knee",
                  body=Body(thigh=6.5, shin=6.0, torso=12.0, upper=5.5, fore=5.5)),
}

def chain(anchor, n, length, base, wind, t, wob=14.0, lift_k=1.0):
    """Élément souple (bandeau, pagne, tresse) : une suite de segments qui traînent
    vers l'arrière selon le « vent » (vitesse) et ondulent avec la phase t."""
    wx, wy = wind
    pts = [anchor]
    p = anchor
    for i in range(n):
        k = (i + 1) / n
        a = base - (70 * wx + 80 * max(wy, 0) * lift_k) * (0.55 + 0.45 * k) + 35 * min(wy, 0) * k
        a += wob * (0.3 + wx) * math.sin(2 * math.pi * t + i * 1.3) * k
        p = add(p, d(a), length)
        pts.append(p)
    return pts


def draw_leg(g, J, side, s, near, under_dress=False):
    body = s["body"]
    skin = s["skin"] if near else shade(s["skin"])
    hip, knee, ankle = J[side + "hip"], J[side + "knee"], J[side + "ankle"]
    seg(g, hip, knee, 1.45, skin)
    seg(g, knee, ankle, 1.2, skin)
    # pied
    fc = s.get("feet", s["skin"])
    fc = fc if near else shade(fc)
    if J[side + "ground"]:
        ax, ay = int(round(ankle[0])), int(round(ankle[1]))
        rect(g, ax - 1, ay, ax + 2, ay + 1, fc); px(g, ax + 3, ay + 1, fc)
    else:
        toe = add(ankle, d(J[side + "foot_a"]), 3.0)
        toe = (toe[0], min(toe[1], ANKLE_Y + 1))   # la pointe ne s'enfonce jamais dans le sol
        seg(g, ankle, toe, 0.9, fc)
    # pantalon : recouvre la cuisse et une part du tibia
    if s.get("bottom") and not under_dress:
        bc = s["bottom"] if near else shade(s["bottom"])
        seg(g, hip, knee, 1.75, bc)
        f = s["pants"]
        if f > 0:
            end = (lerp(knee[0], ankle[0], f), lerp(knee[1], ankle[1], f))
            seg(g, knee, end, 1.45, bc)


def draw_arm(g, J, side, s, near, pose):
    skin = s["skin"] if near else shade(s["skin"])
    sh, el, hand = J[side + "sh"], J[side + "el"], J[side + "hand"]
    if s.get("sleeves"):
        sc = s["top"] if near else shade(s["top"])
        seg(g, sh, el, 1.15, sc)
        cuff = (lerp(el[0], hand[0], 0.35), lerp(el[1], hand[1], 0.35))
        seg(g, el, cuff, 1.25, sc)          # manche ample qui s'évase sur l'avant-bras
        seg(g, cuff, hand, 1.0, skin)
    else:
        seg(g, sh, el, 1.0, skin)
        seg(g, el, hand, 1.0, skin)
    seg(g, hand, hand, 1.2, skin)            # main : un peu plus large que le poignet


def draw(hero, pose):
    s = HEROES[hero]; body = s["body"]
    if pose.get("run_up") is not None:
        pose = ground_run(pose, body)
    J = solve(pose, body)
    T, L = J["T"], J["lean"]
    g = new()
    sk = s["skin"]
    hx, hy = J["head"]
    Hd = lambda x, y: (hx + x - 9, hy + y - 5)     # repère de la tête (même dessin qu'avant)
    wind, t = pose["wind"], pose["t"]
    half = body.half
    dressed = s.get("dress")

    # ---------------- derrière le corps ----------------
    if hero == "kodjo":   # deux pans du bandeau, qui flottent avec la vitesse
        for k, off in enumerate((0, 1.2)):
            pts = chain(Hd(9, 7 + off), 3, 2.6 - k * 0.3, -40, wind, t + k * 0.2)
            for a, b in zip(pts, pts[1:]): seg(g, a, b, 0.62, s["extra"])
    if hero == "afi":     # le pagne-voile, accroché aux épaules
        pts = chain(T(-2.5, body.torso - 1), 4, 4.2, -8, (min(wind[0], 0.75), wind[1]), t, wob=10)
        for i, (a, b) in enumerate(zip(pts, pts[1:])):
            seg(g, a, b, 2.1 - i * 0.15, s["extra"])
        for a, b in zip(pts, pts[1:]):
            seg(g, (a[0] - 1.6, a[1]), (b[0] - 1.6, b[1]), 0.5, s["trim"])
    if hero == "yawa":    # la perche de bambou, sanglée en travers du dos ; tresses
        p0, p1 = T(-6, body.torso + 9), T(-0.5, -11)
        seg(g, p0, p1, 0.75, s["extra"])
        for k in (0.2, 0.4, 0.6, 0.8):
            px(g, lerp(p0[0], p1[0], k), lerp(p0[1], p1[1], k), "#9b7a3d")
    if hero == "yawa":
        for k, off in enumerate((0, 1.5)):
            pts = chain(Hd(8 - k, 8 + off), 3, 3.6, -12, (wind[0] * 0.8, wind[1]), t + 0.15 * k, wob=10)
            for a, b in zip(pts, pts[1:]): seg(g, a, b, 0.62, s["hair"])
            px(g, pts[-1][0], pts[-1][1] + 1, s["trim"])
    if hero == "kokou":   # pompon du bonnet
        pts = chain(Hd(9, 3), 2, 2.5, -60, wind, t, wob=12)
        for a, b in zip(pts, pts[1:]): seg(g, a, b, 0.6, s["trim"])

    # ---------------- membres éloignés ----------------
    back = new()
    draw_arm(back, J, "f", s, False, pose)
    draw_leg(back, J, "f", s, False, under_dress=bool(dressed))
    if dressed:   # sous une robe, les deux jambes passent derrière le tissu
        draw_leg(back, J, "n", s, True, under_dress=True)
    layer_onto(g, back)

    # ---------------- tronc et vêtements ----------------
    tw = half
    shoulder_h = body.torso
    torso_pts = [T(-tw + 0.5, -1), T(tw - 0.5, -1), T(tw, shoulder_h * 0.6), T(tw - 0.5, shoulder_h),
                 T(-tw + 1, shoulder_h + 0.5), T(-tw, shoulder_h * 0.6)]
    if dressed:
        nk, fk = J["nknee"], J["fknee"]
        na_, fa_ = J["nankle"], J["fankle"]
        if dressed == "long":    # robe jusqu'aux chevilles, l'ourlet suit les jambes
            hem_y = max(lerp(nk[1], na_[1], 0.72), lerp(fk[1], fa_[1], 0.72))
            l = min(nk[0], fk[0], lerp(nk[0], na_[0], .7), lerp(fk[0], fa_[0], .7)) - 1.8 - 1.5 * wind[0]
            r = max(nk[0], fk[0], lerp(nk[0], na_[0], .7), lerp(fk[0], fa_[0], .7)) + 1.8
        else:                    # boubou jusqu'aux genoux
            hem_y = max(nk[1], fk[1]) + 1.5
            l = min(nk[0], fk[0]) - 2.2 - 1.2 * wind[0]
            r = max(nk[0], fk[0]) + 2.2
        # l'ourlet se soulève quand il tombe (vent vers le haut)
        lift = 2.5 * max(wind[1], 0)
        dress_pts = [T(-tw + 1, shoulder_h + 0.5), T(tw - 0.5, shoulder_h), T(tw, 4), (r + lift * 0.4, hem_y - lift),
                     (l - lift * 0.4, hem_y - lift * 0.6), T(-tw - 0.5, 4)]
        dg = new()
        poly(dg, dress_pts, s["top"])
        poly(dg, torso_pts, s["top"])
        for y in range(H):        # bandes et motifs du tissu
            for x in range(W):
                if dg[y][x] is None: continue
                if hero == "afi":
                    if (y // 3) % 2: dg[y][x] = s["top2"]
                    if y % 6 == 2 and x % 3 == 0: dg[y][x] = s["trim"]
                else:
                    if y >= hem_y - lift - 1.2: dg[y][x] = s["trim"]   # bordure dorée de l'ourlet
        layer_onto(g, dg)
        if hero == "kokou":   # plastron brodé et bandoulière du tambour
            for k in range(3): px(g, *T(1 - k * 0.0, shoulder_h - 1 - k * 2), s["trim"])
            p0, p1 = T(-tw + 1, shoulder_h), T(tw, 2)
            for k in range(9): px(g, lerp(p0[0], p1[0], k / 8), lerp(p0[1], p1[1], k / 8), shade(s["trim"], 0.85))
    else:
        tg = new()
        poly(tg, torso_pts, s["top"])
        # bassin (ceinture / haut du pantalon)
        poly(tg, [T(-tw + 0.5, 2.5), T(tw - 0.5, 2.5), T(tw - 0.5, -2), T(-tw + 0.5, -2)], s.get("bottom", s["top2"]))
        poly(tg, [T(-tw + 0.5, 4.5), T(tw - 0.2, 4.5), T(tw - 0.2, 2.5), T(-tw + 0.5, 2.5)], s["top2"])
        if hero == "kodjo":   # bande brodée en zigzag
            for k in range(-4, 5):
                px(tg, *T(k, 9 + (k % 2)), s["trim"])
        if hero == "yawa":    # haut court : le ventre est visible
            poly(tg, [T(-tw + 0.5, 6.5), T(tw - 0.3, 6.5), T(tw - 0.3, 2.6), T(-tw + 0.5, 2.6)], sk)
        if hero == "abla":    # tablier de cuir du forgeron
            poly(tg, [T(0.5, shoulder_h - 2), T(tw + 0.4, shoulder_h - 2), T(tw + 0.6, -7), T(0.2, -7)], s["trim"])
            seg(tg, T(0.5, shoulder_h - 2), T(tw + 0.4, shoulder_h - 2), 0.5, "#5c3720")
        # les contours internes du tronc sont repoussés pour que les jambes « entrent » dedans
        layer_onto(g, tg)

    # ---------------- tête ----------------
    hg = new()
    rect(hg, *Hd(10, 5), *Hd(14, 5), sk); rect(hg, *Hd(9, 6), *Hd(15, 13), sk)
    rect(hg, *Hd(10, 14), *Hd(14, 14), sk); rect(hg, *Hd(11, 15), *Hd(13, 15), shade(sk))
    if pose["eye"] == "open":
        px(hg, *Hd(14, 9), OUT); px(hg, *Hd(13, 8), shade(sk, 0.6))       # œil et sourcil
    else:
        rect(hg, *Hd(13, 9), *Hd(14, 9), OUT); px(hg, *Hd(14, 8), shade(sk, 0.6))
    if pose["mouth"] == "open":
        px(hg, *Hd(15, 12), OUT); px(hg, *Hd(14, 12), OUT)
    elif pose["mouth"] == "grit":
        rect(hg, *Hd(14, 12), *Hd(15, 12), shade(sk, 0.55))
    else:
        px(hg, *Hd(15, 12), shade(sk))
    px(hg, *Hd(11, 10), shade(sk, 0.85))                                  # oreille
    if hero == "kodjo":
        rect(hg, *Hd(9, 4), *Hd(15, 6), s["hair"]); rect(hg, *Hd(9, 7), *Hd(9, 9), s["hair"])
        rect(hg, *Hd(9, 7), *Hd(15, 7), s["extra"])
    elif hero == "afi":
        rect(hg, *Hd(9, 2), *Hd(15, 8), s["hair"]); rect(hg, *Hd(10, 0), *Hd(14, 1), s["hair"])
        rect(hg, *Hd(8, 4), *Hd(8, 7), s["hair"])
        for x, y in ((11, 3), (13, 5), (11, 7), (14, 1), (9, 5)): px(hg, *Hd(x, y), s["trim"])
    elif hero == "yawa":
        rect(hg, *Hd(9, 4), *Hd(15, 6), s["hair"]); rect(hg, *Hd(8, 6), *Hd(9, 9), s["hair"])
        px(hg, *Hd(12, 4), "#3a2a20")
    elif hero == "abla":
        rect(hg, *Hd(10, 1), *Hd(14, 4), s["hair"]); rect(hg, *Hd(9, 5), *Hd(15, 6), s["hair"])
        rect(hg, *Hd(9, 6), *Hd(9, 8), s["hair"])
    elif hero == "kokou":
        rect(hg, *Hd(9, 2), *Hd(15, 6), s["hair"]); rect(hg, *Hd(9, 6), *Hd(15, 6), s["trim"])
        px(hg, *Hd(11, 4), shade(s["hair"], 1.25) if False else "#8a5cc0")
    layer_onto(g, hg)

    # ---------------- jambe proche ----------------
    if not dressed:
        lg = new()
        draw_leg(lg, J, "n", s, True)
        layer_onto(g, lg, edge=shade(s.get("bottom", sk), 0.55))
        if hero == "abla":   # le tablier retombe devant la cuisse
            ag = new()
            poly(ag, [T(0.5, 4), T(half + 0.6, 4), T(half + 0.8, -7), T(0.2, -7)], s["trim"])
            layer_onto(g, ag)

    # ---------------- accessoires portés devant ----------------
    if hero == "yawa":   # filet de pêche à la hanche
        c = T(-half - 0.5, 0)
        for y in range(-2, 4):
            for x in range(-2, 2):
                if (x + y) % 2 == 0: px(g, c[0] + x, c[1] + y, "#e0d5b5")
    if hero == "kokou":  # le tambour sur la hanche
        c = T(half + 1.5, 2)
        dgm = new()
        rect(dgm, c[0] - 2, c[1] - 3, c[0] + 3, c[1] + 4, s["extra"])
        rect(dgm, c[0] - 2, c[1] - 3, c[0] + 3, c[1] - 3, "#e8d3a6")
        for x in range(-2, 4): px(dgm, c[0] + x, c[1] + (x % 2), "#f2e2c4")
        layer_onto(g, dgm)

    # ---------------- bras proche ----------------
    ag = new()
    draw_arm(ag, J, "n", s, True, pose)
    el, hand = J["nel"], J["nhand"]
    fa = J["nfore_a"]
    if hero == "abla":   # bracelet de fer et marteau de forge, qui pend dans la main
        cuff = (lerp(el[0], hand[0], 0.45), lerp(el[1], hand[1], 0.45))
        seg(ag, cuff, cuff, 1.2, s["extra"])
        if not pose["flash"]:
            head_c = add(hand, d(fa), 6.0)
            seg(ag, hand, head_c, 0.6, "#8a5a33")
            perp = d(fa + 90)
            seg(ag, add(head_c, perp, -2.0), add(head_c, perp, 2.0), 1.4, s["extra"])
            px(ag, *add(head_c, perp, 2.0), "#ff7b2e")
    mid = (lerp(el[0], hand[0], 0.5), lerp(el[1], hand[1], 0.5))
    px(ag, mid[0], mid[1], BOLT)          # marque de la foudre sur l'avant-bras
    if pose["flash"]:                     # éclair qui jaillit de la main au lâcher
        f = add(hand, d(fa), 2.5)
        px(ag, *f, BOLT); px(ag, f[0] + 1, f[1] - 1, BOLT); px(ag, f[0] + 2, f[1], "#fff6c8")
    layer_onto(g, ag, edge=shade(sk, 0.55))

    outline(g)
    return g


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
def to_img(g):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y in range(H):
        for x in range(W):
            if g[y][x]:
                c = g[y][x].lstrip("#")
                im.putpixel((x, y), tuple(int(c[k:k + 2], 16) for k in (0, 2, 4)) + (255,))
    return im

ROWS = ["idle", "run", "jump", "fall", "throw", "hurt", "land", "crouch", "crawl"]
COLS = max(len(v) for v in ANIMS.values())

def frames_tres(hero):
    """SpriteFrames Godot qui découpe la planche : une AtlasTexture par image."""
    subs, anims = [], []
    for r, name in enumerate(ROWS):
        frames = []
        for c in range(len(ANIMS[name])):
            sid = f"AtlasTexture_{name}_{c}"
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1_sheet")\n'
                        f'region = Rect2({c * W}, {r * H}, {W}, {H})\n')
            dur = DUR.get(name, [1.0] * 99)[c]
            frames.append('{\n"duration": %.1f,\n"texture": SubResource("%s")\n}' % (dur, sid))
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                     % (", ".join(frames), "true" if LOOP[name] else "false", name, FPS[name]))
    return ('[gd_resource type="SpriteFrames" format=3]\n\n'
            f'[ext_resource type="Texture2D" path="res://assets/heroes/{hero}/{hero}.png" id="1_sheet"]\n\n'
            + "\n".join(subs) + '\n[resource]\nanimations = [' + ", ".join(anims) + ']\n')


if __name__ == "__main__":
    import sys
    os.makedirs("out2", exist_ok=True)
    only = sys.argv[1:] or list(HEROES)
    for hero in only:
        sheet = Image.new("RGBA", (W * COLS, H * len(ROWS)), (0, 0, 0, 0))
        for r, name in enumerate(ROWS):
            for c, pose in enumerate(ANIMS[name]):
                sheet.paste(to_img(draw(hero, pose)), (c * W, r * H))
        sheet.save(f"out2/{hero}.png")
        open(f"out2/{hero}_frames.tres", "w").write(frames_tres(hero))
        big = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (58, 52, 70, 255))
        # repère du sol pour vérifier les appuis
        for r in range(len(ROWS)):
            for x in range(big.width):
                bg.putpixel((x, (r * H + 51) * 4), (120, 110, 90, 255))
        bg.alpha_composite(big); bg.save(f"prev2_{hero}.png")
    print("ok")
