"""Niveau 2 — la forêt des irokos : tracé complet (≈ 600 colonnes, 48 lignes), vérifié par
simulation des sauts.

  1. L'orée (0-155)            racines, tronc couché, fourmis, lianes-balanciers, champignons,
                                branches mortes, champ de ronces.
  2. Le sous-bois sombre (155-322)  la canopée éteint le jour : lucioles à emporter, fosses
                                bordées de champignons bleus, chauves-souris aux yeux luisants,
                                tunnel de racines à franchir accroupi (une niche où s'abriter),
                                puits de champignons, ravine noire sur des branches mortes.
  3. Le sanctuaire (322-420)   l'énigme des trois voix (l'oiseau messager), la porte de racines,
                                Kokou et le Tambour parlant ; les premières racines sacrées.
  4. La canopée (420-515)      le Poussiéreux à endormir, l'ascension (racines, branches, courant
                                ascendant pour Afi), la traversée des cimes (rafales, lianes).
  5. Le cœur de l'iroko (515-600)  l'arène d'Adan, puis le cœur de l'arbre (l'autel).

Usage : python3 layout_foret.py <sortie.json> [--check]
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from physics_check import World, reachable, touched, surfaces

COLS, ROWS = 602, 48
G = 42                    # ligne du sol « de base » (l'orée de la version 1 était à 18 : +24)
BOUNCE_V = 546.0
solid = [[False] * COLS for _ in range(ROWS)]
plank = [[False] * COLS for _ in range(ROWS)]
ents, decor, rects, bounces, updrafts, roots = [], [], [], [], [], []
dark_ranges = []


def ground(x0, x1, top, bottom=ROWS - 1):
    for x in range(x0, x1 + 1):
        for y in range(top, bottom + 1): solid[y][x] = True
def hole(x0, x1, y0, y1):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1): solid[y][x] = False
def planks(x0, x1, row):
    for x in range(x0, x1 + 1): plank[row][x] = True
    rects.append((x0 * 16, row * 16, (x1 + 1) * 16, row * 16 + 6))
def ent(kind, col, row, **kw):
    """Entité posée en bas de la case (col, row)."""
    ents.append(dict(kind=kind, x=col * 16 + 8, y=row * 16 + 16, **kw))
def crumble(c0, row, w):
    ents.append(dict(kind="crumble", x=c0 * 16 + w * 8, y=row * 16, w=w))
    rects.append((c0 * 16, row * 16, (c0 + w) * 16, row * 16 + 8))
def mushroom(col, row):
    x, y = col * 16 + 8, row * 16 + 16
    ents.append(dict(kind="mushroom", x=x, y=y))
    rects.append((x - 11, y - 14, x + 11, y - 8))
    bounces.append((x - 11, y - 14, x + 11, BOUNCE_V))
def vine(col, ground_row, length=120, amplitude=55, period=2.4, phase=0.0):
    gy = ground_row * 16
    ents.append(dict(kind="vine", x=col * 16 + 8, y=gy - 38 - length, length=length, amplitude=amplitude, period=period, phase=phase))
def sacred_root(col, ground_row, w=2, h=2, grow="up", stay=6.0, name=None):
    """Racine sacrée (Tambour parlant). Pour la vérification, elle compte comme un appui
    seulement dans les parcours « avec Kokou »."""
    x, y = col * 16 + (w * 8 if grow == "up" else 0), ground_row * 16
    e = dict(kind="root", x=x, y=y, w=w, h=h, grow=grow, stay=stay)
    if name: e["name"] = name
    ents.append(e)
    if grow == "up":
        roots.append((x - w * 8, y - h * 16, x + w * 8, y))
    elif grow == "right":
        roots.append((x, y - h * 16, x + w * 16, y))
    else:
        roots.append((x - w * 16, y - h * 16, x, y))
def updraft(col, top_row, bottom_row, w=3):
    x0, x1 = col * 16, (col + w) * 16
    ents.append(dict(kind="updraft", x=(x0 + x1) / 2, y=bottom_row * 16 + 16, w=w * 16, h=(bottom_row - top_row + 1) * 16))
    updrafts.append((x0, top_row * 16, x1, bottom_row * 16 + 16))
def gust(col0, col1, top_row, bottom_row, direction, period=5.0, phase=0.0, strength=150.0):
    ents.append(dict(kind="gust", x=(col0 + col1 + 1) * 8, y=(bottom_row + 1) * 16, w=(col1 - col0 + 1) * 16,
                     h=(bottom_row - top_row + 1) * 16, dir=direction, period=period, phase=phase, strength=strength))
def cover(c0, c1, r0, r1, texture):
    """Habille un bloc de terre (tronc, tronc couché, racines) : une image raccordable posée
    par-dessus les tuiles, de la colonne c0 à c1, de la ligne r0 à r1 (incluses)."""
    ents.append(dict(kind="cover", x=c0 * 16, y=r0 * 16, w=(c1 - c0 + 1) * 16, h=(r1 - r0 + 1) * 16, texture=texture))
def wall(col, r0, r1):
    """Mur invisible (sous l'habillage d'un tronc)."""
    for y in range(r0, r1 + 1): solid[y][col] = True
def deco(col, name, front=False, row=None, light=None, flip=False):
    decor.append(dict(name=name, col=col, row=row, front=front, light=light, flip=flip))
def surface(col, below=0):
    for y in range(below, ROWS):
        if solid[y][col]: return y
    return ROWS
def voice(col, vid, row=None):
    r = row if row is not None else surface(col)
    ents.append(dict(kind="voice", x=col * 16 + 8, y=r * 16, id=vid))


# ===== 1. L'orée (0-155) =============================================================
ground(0, 34, G)
ent("player", 6, G - 1)
ground(16, 18, G - 1)
ground(19, 20, G - 2)
vine(25, G, length=150, period=2.6)
ent("ant", 33, G - 1, dir=1)
ground(35, 44, G - 3)                       # le dos d'un tronc couché
planks(38, 41, G - 6)
ent("sokpe", 40, G - 8, name="SokpeBranche", dx=8)
ground(45, 70, G)
ent("ant", 50, G - 1, dir=1)
mushroom(57, G - 1)
ground(60, 70, G - 7, G - 7)                # le rebord de racines (on passe dessous)
ent("sokpe", 66, G - 2, name="SokpeCreux", dx=8)
ent("ant", 64, G - 1, dir=-1)
ground(71, 73, G)
crumble(76, G - 3, 2)
crumble(80, G - 5, 2)
ent("sokpe", 81, G - 8, name="SokpeRavine", dx=0)
ground(86, 112, G - 2)
vine(92, G - 2, length=140, period=2.2, phase=0.0)
vine(97, G - 2, length=140, period=2.2, phase=0.5)
ent("checkpoint", 104, G - 3, name="SteleOree")
mushroom(110, G - 3)
ground(113, 121, G)
ent("thorns", 117, G - 1, w=8, dx=-8)
ground(121, 160, G - 2)
ent("sokpe", 117, G - 10, name="SokpeRonces", dx=8)
ent("ant", 136, G - 3, dir=-1)
ent("ant", 142, G - 3, dir=1)

# ===== 2. Le sous-bois sombre (155-322) ==============================================
# L'entrée : un arbre couché fait un porche ; derrière, la nuit.
ground(156, 167, 30, 33)                    # le porche (le tronc couché au-dessus du chemin)
cover(156, 167, 30, 33, "log_h")
dark_ranges.append((161, 322))
ent("fireflies", 164, G - 4, name="Lucioles1")
ground(161, 175, G - 2)
# a. une fosse dans le noir, bordée de champignons bleus (on la devine à leur lueur)
ground(181, 200, G - 2)
deco(175, "champignons_bleus", light=(0.35, 0.75, 1.0))
deco(181, "champignons_bleus", light=(0.35, 0.75, 1.0), flip=True)
ent("bat", 191, G - 9)
ent("rat", 187, G - 3)
# b. le tunnel de racines : 32 px de haut, on le franchit accroupi ; une niche au milieu
ground(200, 222, G - 2)
ground(201, 221, 28, G - 5)                 # le plafond de racines (bas : 2 cases au-dessus du sol)
hole(210, 211, 36, G - 5)                   # la niche : on peut s'y redresser
cover(201, 209, 28, G - 5, "roots_v")
cover(212, 221, 28, G - 5, "roots_v")
cover(210, 211, 28, 35, "roots_v")
ent("sokpe", 210, 36, name="SokpeTunnel", dx=8)
ent("ant", 219, G - 3, dir=-1)
ent("rat", 205, G - 3)
ent("rat", 215, G - 3)
ent("checkpoint", 228, G - 3, name="SteleTunnel")
# c. le puits : deux champignons pour monter dans le noir ; une pierre dans un renfoncement
ground(222, 252, G - 2)
ent("fireflies", 226, G - 4, name="Lucioles2")
ground(252, 256, 26)                        # la paroi : on ne passe que par le haut
mushroom(237, G - 3)
ground(239, 244, 33, 33)                    # premier palier
mushroom(243, 32)
ground(245, 251, 26, 26)                    # second palier, contre la paroi
ground(233, 234, 30, 30)                    # renfoncement à gauche du puits (Ruée ou Pagne)
ent("sokpe", 233, 29, name="SokpePuits", dx=8)
ent("bat", 241, 24)
# d. la ravine noire : branches mortes, une liane, des chauves-souris ; une corniche secrète
ground(257, 262, 26)
crumble(264, 26, 2)
crumble(269, 25, 2)
planks(273, 277, 24)
vine(275, 24, length=110, period=2.4)
crumble(280, 25, 2)
crumble(285, 26, 2)
planks(289, 292, 26)
ent("bat", 290, 20)
crumble(295, 26, 2)
ground(298, 306, 26)
ground(281, 282, 31, 31)                    # la corniche secrète, sous le chemin
mushroom(282, 30)
ent("sokpe", 281, 30, name="SokpeRavineNoire", dx=0)
ent("sokpe", 287, 21, name="SokpeVolee", dx=0)  # au-dessus du vide, entre deux branches
# e. la descente et la stèle, entre les champignons bleus
for k, col in enumerate(range(307, 315)):
    ground(col, col, 26 + 2 * (k + 1))
ground(307, 330, G - 2)
deco(316, "champignons_bleus", light=(0.35, 0.75, 1.0))
deco(321, "champignons_bleus", light=(0.35, 0.75, 1.0), flip=True)
ent("checkpoint", 319, G - 3, name="SteleSousBois")

# ===== 3. Le sanctuaire de Kokou (322-420) ===========================================
ground(330, 400, G - 2)
voice(326, "foret_sanctuaire")
ent("drum", 338, G - 3, voice=0, name="TambourBlanc")
mushroom(347, G - 3)
ground(350, 355, 33, 33)                    # le haut rebord du tambour rouge
ent("drum", 354, 32, voice=1, name="TambourRouge")
ent("sokpe", 351, 30, name="SokpeTambour", dx=0)
planks(380, 383, G - 5)                     # d'où frapper le tambour indigo
ground(392, 396, G - 5)                     # le tertre du tambour indigo
ent("drum", 394, G - 6, voice=2, name="TambourIndigo")
vine(389, G - 2, length=130, period=2.6)
ent("bird", 366, 27, name="Oiseau")
ent("puzzle", 340, G - 3, name="Enigme", drums=["TambourRouge", "TambourBlanc", "TambourIndigo"], gate="PorteSanctuaire",
    bird="Oiseau", sequence=[1, 0, 2, 0], start_x=334 * 16)
ent("rootgate", 400, G - 3, name="PorteSanctuaire", h=5)
ground(400, 414, G - 2)
ent("checkpoint", 403, G - 3, name="SteleSanctuaire")
ent("shrine", 407, G - 3, name="AutelKokou", hero="kokou")
voice(409, "foret_kokou")
# première racine sacrée : la paroi de 4 cases ne se franchit qu'avec elle
ground(415, 440, G - 6)
sacred_root(412, G - 2, w=2, h=2, name="RacineMarche")
ent("sokpe", 405, 30, name="SokpeKokou", dx=0)
sacred_root(404, G - 2, w=1, h=5, stay=7.0, name="RacineKokou")      # le pilier qui mène à la pierre

# ===== 4. La canopée (420-515) =======================================================
voice(418, "foret_poussiereux", row=G - 6)
ent("golem", 430, G - 7, dir=-1, name="Poussiereux")
ent("bat", 436, 28)
# l'ascension : racine, puis branches en zigzag (3 cases) ; courant ascendant pour Afi
sacred_root(441, G - 6, w=2, h=2, name="RacineAscension")
ground(441, 451, 36, 47)                    # (le sol continue sous l'ascension)
planks(444, 448, 31)
planks(440, 443, 28)
planks(445, 449, 25)
planks(440, 443, 22)
planks(445, 449, 19)
planks(440, 443, 16)
ground(452, 456, 14, 47)                    # le tronc qui borde l'ascension
cover(452, 456, 0, 12, "bark_v")
cover(452, 456, 14, 41, "bark_v")
ground(445, 466, 13, 13)                    # la grosse branche du haut
hole(450, 451, 13, 13)                      # le courant passe à travers
updraft(450, 7, 35, w=2)
ent("sokpe", 450, 7, name="SokpeCourant", dx=0)
ent("bat", 446, 18)
ent("bat", 443, 10)
voice(447, "foret_canopee", row=13)
ent("checkpoint", 461, 12, name="SteleCime")
# la traversée des cimes
gust(467, 474, 6, 12, -1, period=5.0, strength=140.0)
crumble(470, 13, 2)
planks(475, 480, 12)
vine(477, 12, length=100, period=2.2)
planks(481, 486, 17)
mushroom(485, 16)
planks(488, 494, 11)
ent("bat", 491, 6)
gust(486, 494, 3, 10, 1, period=4.0, phase=0.4, strength=120.0)
ent("sokpe", 483, 6, name="SokpeRafale", dx=0)
ground(495, 503, 11, 11)
ent("checkpoint", 498, 10, name="SteleCanopee")
ent("sokpe", 502, 3, name="SokpeCime", dx=0)
planks(499, 501, 6)                          # au-dessus de la stèle : une branche fine…
mushroom(497, 10)                            # … qu'on atteint d'un champignon
# la descente vers le cœur : une longue chute dans les feuilles
ground(504, 541, G - 2)

# ===== 5. Le cœur de l'iroko (515-600) ===============================================
ent("checkpoint", 520, G - 3, name="SteleCoeur")
voice(526, "foret_coeur")
ent("rootgate", 541, G - 3, name="PorteArene", h=5, open=True)
ground(542, 587, G - 2)
for c in (539, 540, 541):                    # l'arène est fermée par deux troncs géants
    wall(c, 0, G - 8)
for c in (588, 589, 590):
    wall(c, 0, G - 8)
cover(539, 541, 0, G - 8, "bark_v")
cover(588, 590, 0, G - 8, "bark_v")
cover(539, 541, G - 7, G - 3, "hollow")           # on passe dans le creux du tronc
cover(588, 590, G - 7, G - 3, "hollow")
planks(548, 551, G - 8)
planks(578, 581, G - 8)
ent("sokpe", 564, G - 10, name="SokpeArene", dx=8)
planks(563, 566, G - 6)
for col, h in ((546, 3), (556, 2), (571, 2), (583, 3)):
    sacred_root(col, G - 2, w=2, h=h, stay=7.0, name=f"RacineArene{col}")
ent("firefloor", 542, G - 3, w=(587 - 542 + 1) * 16, name="SolBrulant")
ent("adan", 575, G - 3, name="Adan", left=542 * 16, right=588 * 16)
ent("arena", 545, G - 3, name="Arene")
ent("rootgate", 588, G - 3, name="PorteCoeur", h=5)
ground(588, 601, G - 2)
ent("end", 596, G - 3, name="CoeurIroko")
for y in range(0, ROWS):
    solid[y][601] = True

# ===== Voix ==========================================================================
for col, vid in [(9, "foret_depart"), (20, "foret_liane"), (53, "foret_champi"), (107, "foret_ronces"),
                 (158, "foret_sombre"), (198, "foret_tunnel"), (232, "foret_puits")]:
    voice(col, vid)

# ===== Décor =========================================================================
for col, name, front in [
    (3, "iroko", False), (12, "fougere", False), (22, "colocase", False), (27, "champignons", False), (31, "souche", False),
    (46, "raphia", False), (52, "fromager", False), (69, "champignons", False), (72, "fougere", False),
    (90, "colocase", False), (99, "iroko", False), (108, "grande_fougere", False), (127, "souche", False),
    (131, "tronc_couche", False), (140, "raphia", False), (146, "buisson_foret", False),
    (8, "fougere", True), (48, "grande_fougere", True), (93, "fougere", True), (133, "fougere", True),
    # sous-bois sombre
    (165, "arbre_mort", False), (171, "toile", False), (186, "figuier", False), (196, "termitiere", False),
    (228, "arbre_mort", False), (231, "toile", False), (301, "figuier", False), (311, "termitiere", False),
    (170, "grande_fougere", True), (226, "fougere", True), (316, "fougere", True),
    # sanctuaire
    (334, "raphia", False), (344, "colocase", False), (366, "iroko", False), (374, "grande_fougere", False),
    (386, "raphia", False), (397, "colocase", False), (406, "fougere", False),
    (336, "fougere", True), (377, "grande_fougere", True),
    # canopée (au sol)
    (424, "colocase", False), (433, "fougere", False),
    # le cœur
    (508, "fromager", False), (517, "colocase", False), (530, "iroko", False), (536, "grande_fougere", False),
    (591, "fromager", False), (599, "colocase", False),
    (512, "fougere", True), (538, "fougere", True),
]:
    deco(col, name, front)


# ===== Vérification =================================================================
def world(with_roots):
    r = list(rects) + (list(roots) if with_roots else [])
    return World(solid, r, COLS, ROWS, updrafts)


def check():
    start = next((e["x"], e["y"]) for e in ents if e["kind"] == "player")
    cps = {e["name"]: (e["x"], e["y"]) for e in ents if e["kind"] == "checkpoint"}
    runs = [("départ (Kodjo, Afi)", start, ("dash", "glide"), False, 0, 6200),
            ("stèle du sous-bois", cps["SteleSousBois"], ("dash", "glide"), False, 0, 6500),
            ("stèle du sanctuaire, avec Kokou", cps["SteleSanctuaire"], ("dash", "glide"), True, 0, 9700),
            ("stèle de la cime, avec Kokou", cps["SteleCime"], ("dash", "glide"), True, 0, 9700),
            ("stèle de la canopée, avec Kokou", cps["SteleCanopee"], ("dash", "glide"), True, 0, 9700),
            ("stèle du cœur, avec Kokou", cps["SteleCoeur"], ("dash", "glide"), True, 0, 9700),
            ("départ, sans capacité", start, (), False, 0, 6200)]
    for label, st, ab, wr, xmin, xmax in runs:
        w = world(wr)
        segs, seen, how, visited = reachable(w, st, ab, bounces=bounces)
        far = max((segs[i][1] for i in seen), default=0)
        print(f"\n--- {label} : le plus loin atteint col {int(far) // 16}")
        for e in ents:
            if e["kind"] in ("sokpe", "checkpoint") and st[0] - 50 <= e["x"] <= xmax:
                x, y = e["x"] + e.get("dx", 0), e["y"] - 8
                ok = touched(visited, x, y, 9 if e["kind"] == "sokpe" else 14)
                print(f"   {'OK ' if ok else '-- '} {e['kind']:10} {e.get('name', ''):18} col {x // 16}")


# ===== Auto-tuilage ==================================================================
def S(x, y):
    if x < 0 or x >= COLS: return solid[y][max(0, min(COLS - 1, x))] if 0 <= y < ROWS else True
    if y >= ROWS: return True
    if y < 0: return False
    return solid[y][x]
cells = []
for y in range(ROWS):
    for x in range(COLS):
        if solid[y][x]:
            u, d, l, r = S(x, y - 1), S(x, y + 1), S(x - 1, y), S(x + 1, y)
            var = 1 + (x * 7 + y * 13) % 3
            col = 5 if (not l and not r) else 0 if not l else 4 if not r else var
            if not u: row = 0
            elif not d: row = 2
            else:
                row = 1
                if l and r:
                    if not S(x - 1, y - 1): col, row = 0, 3
                    elif not S(x + 1, y - 1): col, row = 1, 3
            depth = 0
            while depth < 8 and S(x, y - depth - 1): depth += 1
            if row == 1: row = {3: 4, 4: 5, 5: 5, 6: 6}.get(depth, 7 if depth >= 7 else 1)
            cells.append([x, y, col, row, 0])
        elif plank[y][x]:
            l, r = plank[y][x - 1], plank[y][x + 1]
            col = 2 if not l and r else 4 if l and not r else 3
            cells.append([x, y, col, 3, 1])

# position des décors (posés sur la surface sous leur colonne)
for d in decor:
    d["x"] = d["col"] * 16 + 8
    d["y"] = (d["row"] if d["row"] is not None else surface(d["col"], 0 if d["col"] < 156 or d["col"] > 167 else 34)) * 16

if __name__ == "__main__":
    json.dump(dict(cols=COLS, rows=ROWS, cells=cells, entities=ents, decor=decor, dark=[[a * 16, b * 16] for a, b in dark_ranges]),
              open(sys.argv[1], "w"))
    if "--check" in sys.argv: check()
