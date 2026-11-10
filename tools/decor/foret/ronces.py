"""Ronces de poussière (16 × 10, raccordables) : tiges grises tordues hérissées d'épines,
voile de cendre. Remplacent les épines d'acacia dans la forêt."""
from PIL import Image
import sys, random
im = Image.new("RGBA", (32, 10), (0, 0, 0, 0))
OUT = (22, 18, 16, 255); STEM = [(64, 58, 52, 255), (96, 88, 78, 255), (130, 120, 106, 255)]; TIP = (190, 176, 150, 255)
r = random.Random(2)
import math
for k in range(4):
    ph = r.uniform(0, 6); amp = r.uniform(2, 3.5); base = r.uniform(4, 7)
    for x in range(32):
        y = int(round(base + amp * math.sin(2 * math.pi * x / 32 * (1 + k % 2) + ph)))
        y = max(1, min(9, y))
        im.putpixel((x, y), STEM[k % 3])
        if im.getpixel((x, min(9, y + 1)))[3] == 0: im.putpixel((x, min(9, y + 1)), OUT)
        if x % 5 == k % 5 and y > 1:
            im.putpixel((x, y - 1), TIP)
            if y > 2: im.putpixel((x, y - 2), TIP if r.random() < 0.5 else STEM[2])
for x in range(32): im.putpixel((x, 9), OUT if x % 3 else STEM[0])
im.save(sys.argv[1])
im.resize((256, 80), Image.NEAREST).save("/tmp/shots/ronces.png")
