"""Outils communs de dessin des décors de la forêt (tramage, écorce, touffes, contours)."""

import math, random, sys
import numpy as np
from PIL import Image, ImageDraw

OUT = "."
BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
OUTLINE = (12, 9, 8)


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


BARK = [hexc(c) for c in ("130e0b", "1f1712", "2c211a", "3b2d23", "4c3a2d", "5f4a3a", "75604d")]
LEAF = {True: [hexc(c) for c in ("12261a", "1c3824", "28502f", "3a6c3c", "54884c", "76a662")],
        False: [hexc(c) for c in ("2a2926", "3a3834", "4d4a44", "625e56", "7a756b", "948e82")]}
MOSS = {True: [hexc(c) for c in ("1d3a1f", "2b5229", "3c6e33")], False: [hexc(c) for c in ("3a3733", "4a4640", "5a554d")]}
CAP = {True: [hexc(c) for c in ("5a2a16", "8a4420", "b8662e", "e0a060", "f0d8a8")],
       False: [hexc(c) for c in ("3c3832", "55504a", "6e685e", "8c8578", "a8a090")]}


class Sprite:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3), np.uint8)
        self.a = np.zeros((h, w), bool)
        self.yy, self.xx = np.mgrid[0:h, 0:w]

    def mask(self, fn):
        im = Image.new("L", (self.w, self.h), 0)
        fn(ImageDraw.Draw(im))
        return np.array(im) > 127

    def paint(self, m, val, pal):
        bay = BAY[self.yy % 4, self.xx % 4]
        idx = np.clip(np.floor(val * (len(pal) - 1) + bay), 0, len(pal) - 1).astype(int)
        for i, c in enumerate(pal):
            self.rgb[m & (idx == i)] = c
        self.a |= m

    def across(self, m):
        u = np.zeros(m.shape)
        for y in range(self.h):
            row = np.nonzero(m[y])[0]
            if len(row):
                for run in np.split(row, np.nonzero(np.diff(row) > 1)[0] + 1):
                    u[y, run] = (run - run[0]) / max(1, run[-1] - run[0])
        return u

    def outline(self):
        a = self.a
        o = np.zeros_like(a)
        o[1:] |= a[:-1]; o[:-1] |= a[1:]; o[:, 1:] |= a[:, :-1]; o[:, :-1] |= a[:, 1:]
        o &= ~a
        self.rgb[o] = OUTLINE
        self.a |= o

    def save(self, path):
        im = np.zeros((self.h, self.w, 4), np.uint8)
        im[..., :3] = self.rgb
        im[..., 3] = self.a * 255
        Image.fromarray(im, "RGBA").save(path)


def bark(s, m, phase=0.0, fan=None):
    u = s.across(m)
    fx, fy = fan if fan else (s.w / 2, -200)
    ang = np.arctan2(s.xx - fx, s.yy - fy)
    ridge = np.sin(ang * 90 + phase + 0.6 * np.sin(s.yy * 0.05))
    val = 0.12 + 0.55 * (1 - u) ** 1.3 + 0.13 * ridge + 0.15 * (u < 0.05)
    val[ridge < -0.8] = 0.0
    s.paint(m, val, BARK)


def tuft(s, x, y, r, pal, seed):
    """Touffe de feuillage ronde, dentelée, éclairée en haut à gauche."""
    rr = random.Random(seed)
    ang = np.arctan2(s.yy - y, s.xx - x)
    jag = 0.2 * np.sin(ang * rr.choice((5, 6, 7)) + rr.uniform(0, 6))
    d = np.hypot((s.xx - x) / r, (s.yy - y) / (r * 0.8))
    m = d < 1 + jag
    lit = -((s.xx - x) + (s.yy - y)) / (2 * r)
    val = 0.4 + 0.35 * lit
    val = np.where(d > 0.8 + jag, val - 0.25, val)
    s.paint(m, val, pal)


def dust(s, healthy, amount=0.06, seed=0):
    """La poussière d'Adaka : un voile de points gris sur la forêt malade."""
    if healthy:
        return
    rr = np.random.default_rng(seed)
    sel = s.a & (rr.random(s.a.shape) < amount)
    s.rgb[sel] = (120, 114, 104)


