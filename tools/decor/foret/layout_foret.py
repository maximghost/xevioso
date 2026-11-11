"""Niveau 2 — la forêt des irokos. Construit section par section ; ce fichier contient pour
l'instant la première : l'orée.

  1. L'orée (0-150) — on entre dans la forêt malade : racines en marches, troncs couchés,
     premières fourmis corrompues ; les champignons qui font bondir (un rebord trop haut,
     puis un champ de ronces trop large pour un simple saut) ; des branches qui cassent
     au-dessus d'une ravine ; la stèle de l'orée.
  (à suivre : le sous-bois sombre, le sanctuaire de Kokou, la canopée, le cœur de l'iroko)

Usage : python3 layout_foret.py <sortie.json> [--check]
"""
import json, sys
sys.path.insert(0, ".")
from physics_check import World, reachable, touched, surfaces

COLS, ROWS = 160, 24
BOUNCE_V = 546.0          # vitesse donnée par un champignon (≈ 120 px de haut)
solid = [[False] * COLS for _ in range(ROWS)]
plank = [[False] * COLS for _ in range(ROWS)]
ents, decor, rects, bounces = [], [], [], []


def ground(x0, x1, top):
    for x in range(x0, x1 + 1):
        for y in range(top, ROWS): solid[y][x] = True
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
    """Champignon qui fait bondir, posé sur le sol de la case (col, row) ; chapeau de 14 px."""
    x, y = col * 16 + 8, row * 16 + 16
    ents.append(dict(kind="mushroom", x=x, y=y))
    rects.append((x - 11, y - 14, x + 11, y - 8))
    bounces.append((x - 11, y - 14, x + 11, BOUNCE_V))
def vine(col, ground_row, length=120, amplitude=55, period=2.4, phase=0.0):
    """Liane-balancier : au plus bas, la boule (rayon 8) frôle 30 px au-dessus du sol de la
    case — on passe accroupi (26 px), pas debout (40 px)."""
    gy = ground_row * 16
    ents.append(dict(kind="vine", x=col * 16 + 8, y=gy - 38 - length, length=length,
                     amplitude=amplitude, period=period, phase=phase))
def surface(col):
    for y in range(ROWS):
        if solid[y][col]: return y
    return ROWS


# ===== 1. L'orée (0-150) ==========================================================
# a. L'entrée : un sol plat, des racines en marches, la première fourmi.
ground(0, 34, 18)
ent("player", 6, 17)
ground(16, 18, 17)                 # racine (1 case)
ground(19, 20, 16)                 # racine plus haute (2 cases)
vine(25, 18, length=150, period=2.6)
ent("ant", 33, 17, dir=1)
# b. Un grand tronc couché à franchir, une branche au-dessus avec une pierre.
ground(35, 44, 15)                 # le dos du tronc (3 cases au-dessus du sol)
planks(38, 41, 12)
ent("sokpe", 40, 10, name="SokpeBranche", dx=8)
ground(45, 70, 18)
ent("ant", 50, 17, dir=1)
# c. Le premier champignon : le rebord est à 7 cases, trop haut pour un saut.
mushroom(57, 17)
ground(60, 70, 11)                 # le rebord (une avancée de racines)
hole(60, 70, 12, 17)               # dessous : un creux sous le rebord…
ground(60, 70, 18)                 # … mais le sol continue (on peut passer dessous)
ent("sokpe", 66, 16, name="SokpeCreux", dx=8)     # la pierre cachée sous le rebord
ent("ant", 64, 17, dir=-1)
# d. La ravine : des branches qui cassent ; on peut aussi arriver par le rebord.
#    (sol 71-73 au niveau 18 ; trou 74-85 ; sol au-delà)
ground(71, 73, 18)
crumble(76, 15, 2)
crumble(80, 13, 2)
ent("sokpe", 81, 10, name="SokpeRavine", dx=0)
ground(86, 112, 16)
vine(92, 16, length=140, period=2.2, phase=0.0)
vine(97, 16, length=140, period=2.2, phase=0.5)    # deux lianes en contretemps
ent("checkpoint", 104, 15, name="SteleOree")
# e. Le champ de ronces : 8 cases d'épines, trop large même en courant.
#    Un champignon au bord : il faut y arriver lancé et garder la direction.
mushroom(110, 15)
ground(113, 121, 18)               # le champ est en contrebas
ent("thorns", 117, 17, w=8, dx=-8)   # centrées : cases 113 à 120
ground(121, 150, 16)
ent("sokpe", 117, 8, name="SokpeRonces", dx=8)    # au sommet du grand bond
ent("ant", 136, 15, dir=-1)
ent("ant", 142, 15, dir=1)
# f. Fin provisoire : l'entrée du sous-bois (la suite arrive)
for y in range(0, 16):
    solid[y][150] = True

# ===== La voix de Xɛvioso ==========================================================
for col, vid in [(9, "foret_depart"), (20, "foret_liane"), (53, "foret_champi"), (107, "foret_ronces"), (146, "foret_suite")]:
    ents.append(dict(kind="voice", x=col * 16 + 8, y=surface(col) * 16, id=vid))

# ===== Décor =======================================================================
for col, name, plane in [
    (3, "iroko_tronc", "back"), (12, "fougere", "back"), (22, "buisson_foret", "back"), (26, "champignons", "back"),
    (31, "souche", "back"), (46, "fougere", "back"), (52, "iroko_tronc", "back"), (69, "champignons", "back"),
    (72, "fougere", "back"), (90, "buisson_foret", "back"), (98, "iroko_tronc", "back"), (108, "fougere", "back"),
    (127, "souche", "back"), (131, "tronc_couche", "back"), (139, "iroko_tronc", "back"), (145, "buisson_foret", "back"),
    (8, "fougere", "front"), (48, "fougere", "front"), (93, "fougere", "front"), (133, "fougere", "front"),
]:
    if surface(col) >= ROWS: continue
    decor.append(dict(name=name, x=col * 16 + 8, y=surface(col) * 16, front=plane == "front"))


# ===== Vérification d'atteignabilité ===============================================
def check():
    start = next((e["x"], e["y"]) for e in ents if e["kind"] == "player")
    cp = {e["name"]: (e["x"], e["y"]) for e in ents if e["kind"] == "checkpoint"}
    runs = [("départ, sans capacité", start, ()),
            ("départ, Ruée + Pagne-voile", start, ("dash", "glide")),
            ("stèle de l'orée, sans capacité", cp["SteleOree"], ())]
    for label, st, abilities in runs:
        w = World(solid, rects, COLS, ROWS)
        segs, seen, how, visited = reachable(w, st, abilities, bounces=bounces)
        print(f"\n--- {label} : {len(seen)}/{len(segs)} surfaces atteintes")
        for e in ents:
            if e["kind"] in ("sokpe", "checkpoint") and e["x"] > st[0] - 200:
                x, y = e["x"] + e.get("dx", 0), e["y"] - 8
                ok = touched(visited, x, y, 9 if e["kind"] == "sokpe" else 14)
                print(f"   {'OK ' if ok else '-- '} {e['kind']:10} {e.get('name', ''):16} col {x // 16}")
        far = max((segs[i][1] for i in seen), default=0)
        print(f"   le plus loin atteint : col {int(far) // 16}")
        unreached = [segs[i] for i in range(len(segs)) if i not in seen and segs[i][0] > st[0] - 200]
        print("   inaccessibles :", ", ".join(f"{int(a) // 16}-{int(b) // 16}/l{int(y) // 16}" for a, b, y in unreached) or "aucune")


# ===== Auto-tuilage (comme le village) =============================================
def S(x, y):
    if x < 0 or x >= COLS: return solid[y][max(0, min(COLS - 1, x))] if 0 <= y < ROWS else True
    if y >= ROWS: return True
    if y < 0: return False
    return solid[y][x]
cells, back = [], []
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

if __name__ == "__main__":
    json.dump(dict(cols=COLS, rows=ROWS, cells=cells, back=back, entities=ents, decor=decor), open(sys.argv[1], "w"))
    if "--check" in sys.argv: check()
