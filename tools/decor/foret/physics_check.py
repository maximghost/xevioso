"""Vérificateur d'atteignabilité : simule les vrais sauts du héros sur la grille du niveau.

Réglages identiques au jeu (héros du village) : vitesse 200 px/s, saut de 56 px atteint
en 0,3 s, chute à la même gravité, contrôle en l'air réduit, saut à hauteur variable.
Le héros est une boîte de 14 × 40 px. Les sols : cases pleines, planches pleines (6 px),
dalles qui s'effritent, nacelles (à leurs deux extrémités).
Capacités : Ruée de Kodjo (460 px/s pendant 0,16 s, sans gravité), Pagne-voile d'Afi (chute ≤ 45 px/s).
"""
import math
DT = 1 / 60
MAX_SPEED, ACCEL, AIR_ACCEL, AIR_FRICTION = 200.0, 900.0, 600.0, 400.0
H_JUMP, T_APEX = 56.0, 0.3
G = 2 * H_JUMP / T_APEX ** 2
V0 = -2 * H_JUMP / T_APEX
MAX_FALL = 380.0
HW, HH = 7.0, 20.0        # demi-largeur, demi-hauteur du héros

class World:
    def __init__(self, solid, rects, cols, rows, updrafts=()):
        self.solid, self.rects, self.cols, self.rows = solid, rects, cols, rows
        self.updrafts = list(updrafts)          # (x0, y0, x1, y1) : portent Afi sous son voile
    def hit(self, x, y, hh=None):
        """La boîte centrée en (x, y) chevauche-t-elle un obstacle ? (hh : demi-hauteur)"""
        hh = HH if hh is None else hh
        x0, x1, y0, y1 = x - HW, x + HW, y - hh, y + hh
        for cy in range(max(0, int(y0 // 16)), min(self.rows, int((y1 - 0.01) // 16) + 1)):
            for cx in range(int(x0 // 16), int((x1 - 0.01) // 16) + 1):
                if cx < 0 or cx >= self.cols: return True
                if self.solid[cy][cx]: return True
        for (rx0, ry0, rx1, ry1) in self.rects:
            if x0 < rx1 and x1 > rx0 and y0 < ry1 and y1 > ry0: return True
        return False

def simulate(w, x, y, vx, dir_, hold, jump_frames, ability=None, ability_at=0, max_t=3.5, v0=None):
    """Saut depuis (x, y) (centre du corps, pieds posés). Renvoie (atterrissage, trajectoire)."""
    vy = (V0 if v0 is None else v0) if jump_frames > 0 else 0.0
    path = []
    dash_left = 0.0
    used = False
    for f in range(int(max_t / DT)):
        inp = dir_ if f < hold else 0
        # capacité
        if ability == "dash" and not used and f == ability_at:
            used = True; dash_left = 0.16
        if dash_left > 0:
            dash_left -= DT
            vx = dir_ * 460.0; vy = 0.0
            if dash_left <= 0: vx = dir_ * MAX_SPEED
        else:
            if inp: vx = vx + (inp * MAX_SPEED - vx) * min(1, AIR_ACCEL * DT / max(1e-6, abs(inp * MAX_SPEED - vx)))
            else: vx = vx - math.copysign(min(abs(vx), AIR_FRICTION * DT), vx)
            if jump_frames and 0 < f == jump_frames and vy < 0: vy *= 0.5    # relâcher tôt
            vy = min(vy + G * DT, MAX_FALL)
            if ability == "glide" and f >= ability_at:
                if any(ux0 <= x <= ux1 and uy0 <= y <= uy1 for (ux0, uy0, ux1, uy1) in w.updrafts):
                    vy = max(vy - 2200 * DT, -150.0)       # le courant ascendant la porte
                elif vy > 0: vy = min(vy, 45.0)
        # déplacement : horizontal puis vertical (comme move_and_slide)
        nx = x + vx * DT
        if w.hit(nx, y):
            step = 1 if vx > 0 else -1
            while not w.hit(x + step, y) and abs(x + step - nx) >= 1: x += step
            vx = 0
        else: x = nx
        ny = y + vy * DT
        if w.hit(x, ny):
            step = 1 if vy > 0 else -1
            while not w.hit(x, y + step): y += step
            if vy > 0: return (x, y), path          # posé
            vy = 0                                   # tête cognée
        else: y = ny
        path.append((x, y))
        if y > w.rows * 16 + 60: return None, path  # tombé dans le vide
    return None, path

def surfaces(w):
    """Segments où l'on peut se tenir : (x gauche, x droite, y des pieds)."""
    tops = []
    for r in range(1, w.rows):
        c = 0
        while c < w.cols:
            if w.solid[r][c] and not w.solid[r - 1][c]:
                c0 = c
                while c < w.cols and w.solid[r][c] and not w.solid[r - 1][c]: c += 1
                tops.append((c0 * 16, c * 16, r * 16))
            else: c += 1
    for (rx0, ry0, rx1, ry1) in w.rects:
        tops.append((rx0, rx1, ry0))
    # on ne garde que ceux où le héros tient debout (assez de place au-dessus)
    # on ne garde que les positions où le héros tient debout (assez de place, aucun obstacle),
    # et on coupe le segment là où il ne peut pas se tenir (un portail, un mur, un plafond bas)
    out = []
    for (x0, x1, y) in tops:
        # debout (40 px) ou, sous un plafond bas, accroupi (26 px) : on y avance au pas
        xs = [x for x in range(int(x0) + 2, int(x1) - 1, 4) if not w.hit(x, y - HH - 0.5) or not w.hit(x, y - 13.5, 13.0)]
        run = []
        for x in xs:
            if run and x - run[-1] > 4:
                out.append((run[0], run[-1], y)); run = []
            run.append(x)
        if run: out.append((run[0], run[-1], y))
    return out

def reachable(w, start, abilities=(), extra_edges=(), bounces=()):
    """Parcours en largeur des surfaces atteignables depuis la position de départ."""
    segs = surfaces(w)
    def seg_of(x, feet):
        best, dist = None, 99
        for i, (x0, x1, y) in enumerate(segs):
            if abs(feet - y) < 1.5:
                d = 0 if x0 <= x <= x1 else min(abs(x - x0), abs(x - x1))
                if d < dist and d <= 8: best, dist = i, d
        return best
    first = seg_of(start[0], start[1])
    seen, todo, visited = {first}, [first], set()
    how = {first: "départ"}
    while todo:
        i = todo.pop()
        x0, x1, y = segs[i]
        cy = y - HH
        bv = next((b[3] for b in bounces if abs(b[1] - y) < 1.5 and b[0] - 8 <= x0 and x1 <= b[2] + 8), None)
        if bv is not None:
            # un champignon : on ne s'y pose pas, il relance aussitôt (élan conservé ou non)
            for sx in (x0, (x0 + x1) / 2, x1):
                for d in (-1, 1):
                    for vx in (d * MAX_SPEED, 0.0):
                        for hold in (999, 20, 0):
                            for ab, at in [(None, 0)] + [(a, k) for a in abilities for k in (20, 35, 50)]:
                                land, path = simulate(w, sx, cy, vx, d, hold, 999, ab, at, v0=-bv)
                                for p in path[::2]: visited.add((int(p[0]) // 4, int(p[1]) // 4))
                                if land:
                                    j = seg_of(land[0], land[1] + HH)
                                    if j is not None and j not in seen:
                                        seen.add(j); todo.append(j); how[j] = "champignon"
            continue
        starts = sorted(set([x0, x1] + list(range(int(x0), int(x1) + 1, 16))))
        modes = [(None, 0)] + [(a, k) for a in abilities for k in (8, 16, 24)]
        for sx in starts:
            for d in (-1, 1):
                run = (sx - x0 if d > 0 else x1 - sx) >= 24
                for vx in ([d * MAX_SPEED] if run else []) + [0.0]:
                    for hold in (999, 14):
                        for jf in (999, 8, 0):
                            for ab, at in modes:
                                if jf == 0 and ab is not None: continue
                                land, path = simulate(w, sx, cy, vx, d, hold, jf, ab, at)
                                for p in path[::2]: visited.add((int(p[0]) // 4, int(p[1]) // 4))
                                if land:
                                    j = seg_of(land[0], land[1] + HH)
                                    if j is not None and j not in seen:
                                        seen.add(j); todo.append(j)
                                        how[j] = "capacité : " + ab if ab else "saut"
    return segs, seen, how, visited

def touched(visited, x, y, radius=9):
    """La pierre en (x, y) a-t-elle été frôlée par le héros sur l'une des trajectoires ?"""
    for gx in range(int((x - HW - radius) // 4), int((x + HW + radius) // 4) + 1):
        for gy in range(int((y - HH - radius) // 4), int((y + HH + radius) // 4) + 1):
            if (gx, gy) in visited: return True
    return False
