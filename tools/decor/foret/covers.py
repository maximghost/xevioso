"""Habillages raccordables pour les masses de terre qui doivent se lire autrement :
  bark_v.png  (32 × 64, raccord vertical et horizontal) : écorce d'un tronc géant qui monte
  log_h.png   (64 × 32, raccord horizontal) : tronc couché (le porche du sous-bois)
  roots_v.png (32 × 32) : masse de racines entrelacées (le plafond du tunnel)
"""
import math, sys, random
import numpy as np
from PIL import Image
OUT = sys.argv[1]
BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
def hexc(h): return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.uint8)
BARK = [hexc(c) for c in ("130e0b", "1f1712", "2c211a", "3b2d23", "4c3a2d", "5f4a3a")]
ROOT = [hexc(c) for c in ("1c140e", "2e2016", "45311f", "5e452c", "7a5c3c")]
def paint(val, pal, h, w):
    yy, xx = np.mgrid[0:h, 0:w]
    idx = np.clip(np.floor(val * (len(pal) - 1) + BAY[yy % 4, xx % 4]), 0, len(pal) - 1).astype(int)
    out = np.zeros((h, w, 4), np.uint8)
    for i, c in enumerate(pal):
        out[idx == i, :3] = c
    out[..., 3] = 255
    return out
# écorce verticale : côtes ondulées (périodiques sur 64 px de haut, 32 de large)
h, w = 64, 32
yy, xx = np.mgrid[0:h, 0:w]
ridge = np.sin(2 * np.pi * (xx / 8.0 + 0.15 * np.sin(2 * np.pi * yy / 64.0)))
val = 0.35 + 0.22 * ridge + 0.08 * np.sin(2 * np.pi * yy / 16.0 + xx)
val[ridge < -0.8] = 0.02
Image.fromarray(paint(val, BARK, h, w)).save(f"{OUT}/bark_v.png")
# tronc couché : cylindre (clair en haut), stries horizontales
h, w = 32, 64
yy, xx = np.mgrid[0:h, 0:w]
cyl = 1 - np.abs(yy - 10) / 22.0
ridge = np.sin(2 * np.pi * (yy / 6.0 + 0.12 * np.sin(2 * np.pi * xx / 64.0)))
val = 0.12 + 0.55 * cyl + 0.12 * ridge
val[ridge < -0.85] = 0.0
img = paint(np.clip(val, 0, 1), BARK, h, w)
img[0] = (12, 9, 8, 255)
r = random.Random(3)
for i in range(40):                                  # mousse sur le dessus
    x = r.randrange(w); img[1 + r.randrange(2), x, :3] = (58, 82, 48) if r.random() < 0.6 else (90, 84, 74)
Image.fromarray(img).save(f"{OUT}/log_h.png")
# masse de racines : cordes qui se croisent en diagonale
h, w = 32, 32
yy, xx = np.mgrid[0:h, 0:w]
a = np.sin(2 * np.pi * (xx + yy) / 16.0); b = np.sin(2 * np.pi * (xx - yy) / 16.0 + 1.0)
val = 0.25 + 0.3 * np.maximum(a, b)
val[np.maximum(a, b) < -0.3] = 0.0
Image.fromarray(paint(np.clip(val, 0, 1), ROOT, h, w)).save(f"{OUT}/roots_v.png")
