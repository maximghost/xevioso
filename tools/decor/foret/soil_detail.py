"""Texture de détail de la terre (128 × 128, raccordable, en gris neutre autour de 0.5) :
strates ondulées, mottes, cailloux éclairés par le haut, radicelles. Multipliée par la couleur
des tuiles dans soil_depth.gdshader, elle marche pour la forêt sèche comme pour la forêt verte.
Aussi : foret_depth.png, la carte des profondeurs (distance de chaque tuile au vide).

Utilisation : python3 soil_detail.py DOSSIER_TUILES"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

N = 128
rng = np.random.default_rng(3)


def periodic_noise(scale, seed):
    r = np.random.default_rng(seed)
    f = np.fft.fft2(r.standard_normal((N, N)))
    ky, kx = np.meshgrid(np.fft.fftfreq(N), np.fft.fftfreq(N), indexing="ij")
    k = np.sqrt(kx ** 2 + ky ** 2) + 1e-6
    f *= np.exp(-(k * scale) ** 2)
    out = np.real(np.fft.ifft2(f))
    return (out - out.min()) / (np.ptp(out) + 1e-9)


def detail():
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    n1, n2, n3 = periodic_noise(14, 1), periodic_noise(5, 2), periodic_noise(2, 3)
    # strates : une vague par 32 px (4 par tuile de texture : raccord vertical exact)
    strata = 0.5 + 0.5 * np.sin(2 * np.pi * (yy / 32.0) + 5.0 * (n1 - 0.5) * 2)
    v = 0.5 + 0.10 * (strata - 0.5) + 0.12 * (n2 - 0.5) + 0.06 * (n3 - 0.5)
    v -= 0.10 * (n1 > 0.68)                                   # poches sombres
    img = np.stack([v, v, v], -1)
    def wrap(y, x): return y % N, x % N
    # cailloux
    for _ in range(26):
        cx, cy = rng.integers(0, N, 2)
        rx = int(rng.choice([1, 2, 2, 3, 4])); ry = max(1, int(rx * 0.7))
        for dy in range(-ry - 1, ry + 2):
            for dx in range(-rx - 1, rx + 2):
                q = (dx / (rx + 0.5)) ** 2 + (dy / (ry + 0.5)) ** 2
                y, x = wrap(cy + dy, cx + dx)
                if q <= 1:
                    img[y, x] = 0.62 - 0.12 * (dy / (ry + 0.5)) - 0.04 * dx / (rx + 0.5)
                elif q <= 1.6 and dy > 0:
                    img[y, x] *= 0.75                          # ombre portée sous le caillou
    # radicelles (fines, sombres, qui serpentent)
    for _ in range(9):
        x, y = rng.uniform(0, N, 2); a = rng.uniform(0, np.pi)
        for k in range(int(rng.integers(14, 40))):
            a += rng.normal(0, 0.25)
            x += np.cos(a); y += abs(np.sin(a)) * 0.8 + 0.2
            yi, xi = wrap(int(y), int(x))
            img[yi, xi] = img[yi, xi] * 0.7
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB")


def depth_map(solid):
    s = np.array(solid, bool)
    d = ndimage.distance_transform_edt(s)                   # en tuiles, depuis la case vide la plus proche
    d = np.clip((d - 1.0) / 7.0, 0, 1)
    return Image.fromarray((d * 255).astype(np.uint8), "L")


if __name__ == "__main__":
    out = sys.argv[1]
    detail().save(os.path.join(out, "soil_detail.png"))
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import layout_foret as L
    depth_map(L.solid).save(os.path.join(out, "foret_depth.png"))
    print("soil_detail.png, foret_depth.png", L.COLS, L.ROWS)
