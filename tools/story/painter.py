"""Petit atelier de peinture pour les tableaux du prologue (pixel art « peint »).

On peint en couleurs flottantes (numpy), avec de vrais volumes éclairés (relief → normales →
lumière orientable), une perspective atmosphérique (les lointains se fondent dans la couleur
du ciel), des liserés de lumière côté soleil et des ombres portées ; puis on ramène l'image à
une palette de pixel art par un tramage ordonné (Bayer 4×4), pour garder des pixels nets.
"""
import math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5


def C(h):
    """'#rrggbb' ou 'rrggbb' → couleur flottante 0..1."""
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float) / 255.0


def mix(a, b, t):
    t = np.asarray(t, float)
    if t.ndim:
        t = t[..., None]
    return a * (1 - t) + b * t


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


def fbm(h, w, seed, cells=(64, 32, 16, 8), periodic_x=False):
    r = np.random.default_rng(seed)
    out = np.zeros((h, w)); amp, tot = 1.0, 0.0
    for c in cells:
        gh, gw = h // c + 3, w // c + 3
        g = r.random((gh, gw))
        if periodic_x:
            g[:, -3:] = g[:, :3]
        out += amp * ndimage.zoom(g, c, order=3)[:h, :w]; tot += amp; amp *= 0.55
    out /= tot
    return (out - out.min()) / (np.ptp(out) + 1e-9)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3))
        self.a = np.zeros((h, w))
        self.yy, self.xx = np.mgrid[0:h, 0:w].astype(float)

    # --- masques
    def mask(self, fn):
        im = Image.new("L", (self.w, self.h), 0)
        fn(ImageDraw.Draw(im))
        return np.asarray(im) > 127

    def poly(self, pts):
        return self.mask(lambda d: d.polygon([(float(x), float(y)) for x, y in pts], fill=255))

    def ellipse(self, x0, y0, x1, y1):
        return self.mask(lambda d: d.ellipse((x0, y0, x1, y1), fill=255))

    # --- peinture
    def fill(self, m, color, alpha=1.0):
        """color : couleur (3,) ou image (h, w, 3) ; alpha : nombre ou image."""
        a = np.where(m, alpha, 0.0) if np.ndim(alpha) == 0 else np.where(m, alpha, 0.0)
        col = color if np.ndim(color) == 3 else np.broadcast_to(color, self.rgb.shape)
        self.rgb = self.rgb * (1 - a[..., None]) + col * a[..., None]
        self.a = np.maximum(self.a, a) if np.ndim(alpha) else np.where(m, np.maximum(self.a, alpha), self.a)

    def image(self):
        return self.rgb, self.a


def relief(m, cap):
    d = ndimage.distance_transform_edt(m)
    t = np.clip(d / max(cap, 1e-3), 0, 1)
    return np.sqrt(1 - (1 - t) ** 2) * cap


def normals(hgt, blur=0.8):
    gy, gx = np.gradient(ndimage.gaussian_filter(hgt, blur))
    n = np.stack([-gx, -gy, np.ones_like(hgt)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def light(hgt, m, ldir, ambient=0.25, wrap=0.0):
    """Éclairage d'un relief : ldir = (x, y, z) vers la lumière (y vers le bas de l'image)."""
    L = np.array(ldir, float); L /= np.linalg.norm(L)
    v = (normals(hgt) @ L + wrap) / (1 + wrap)
    return np.where(m, ambient + (1 - ambient) * np.clip(v, 0, 1), 0)


def edge_toward(m, dx, dy, width=1):
    """Les pixels du masque dont le voisin dans la direction (dx, dy) est vide : le bord
    tourné vers cette direction (pour les liserés de lumière)."""
    out = np.zeros_like(m)
    for k in range(1, width + 1):
        sh = np.roll(np.roll(m, -dy * k, 0), -dx * k, 1)
        out |= m & ~sh
    return out


def shadow_cast(m, dx, dy, length):
    """Ombre portée d'un masque, étirée dans la direction (dx, dy) sur « length » pixels."""
    out = np.zeros_like(m, dtype=float)
    for k in range(1, length + 1):
        sh = np.roll(np.roll(m, int(round(dy * k)), 0), int(round(dx * k)), 1)
        out = np.maximum(out, sh * (1 - k / (length + 1)) ** 0.6)
    return out


def quantize(rgb, levels=28, dither=1.0):
    """Ramène à une palette discrète par tramage ordonné (pixels nets, dégradés tramés)."""
    h, w, _ = rgb.shape
    b = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w][..., None]
    q = np.floor(np.clip(rgb, 0, 1) * (levels - 1) + 0.5 + b * dither) / (levels - 1)
    return np.clip(q, 0, 1)


def save(rgb, a, path, levels=28, dither=1.0):
    q = quantize(rgb, levels, dither)
    im = np.zeros(rgb.shape[:2] + (4,), np.uint8)
    im[..., :3] = (q * 255).astype(np.uint8)
    im[..., 3] = (np.clip(a, 0, 1) > 0.5).astype(np.uint8) * 255
    Image.fromarray(im, "RGBA").save(path)


def bezier(pts, n=60):
    t = np.linspace(0, 1, n)[:, None]
    P = [np.array(p, float) for p in pts]
    if len(P) == 3:
        return (1 - t) ** 2 * P[0] + 2 * (1 - t) * t * P[1] + t * t * P[2]
    return (1 - t) ** 3 * P[0] + 3 * (1 - t) ** 2 * t * P[1] + 3 * (1 - t) * t * t * P[2] + t ** 3 * P[3]


def stroke(cv, pts, w0, w1):
    """Un tracé épais qui s'amincit (branche, racine, tige) → masque."""
    P = bezier(pts, 80) if len(pts) in (3, 4) else np.array(pts, float)
    L, R = [], []
    for j in range(len(P)):
        t = j / (len(P) - 1)
        a, b = P[max(j - 1, 0)], P[min(j + 1, len(P) - 1)]
        d = b - a; n = math.hypot(*d) or 1
        nx, ny = -d[1] / n, d[0] / n
        w = w0 + (w1 - w0) * t
        L.append((P[j][0] + nx * w, P[j][1] + ny * w)); R.append((P[j][0] - nx * w, P[j][1] - ny * w))
    return cv.poly(L + R[::-1])
