"""Branche morte (16 × 10, raccordable) : bois gris et sec, fendillé — elle casse sous le poids."""
from PIL import Image
import sys
im = Image.new("RGBA", (16, 10), (0, 0, 0, 0))
OUT = (20, 15, 12, 255); C = [(52, 44, 38, 255), (78, 68, 58, 255), (108, 96, 82, 255), (140, 128, 110, 255)]
for x in range(16):
    im.putpixel((x, 0), OUT)
    im.putpixel((x, 1), C[3] if x % 5 else C[2])
    im.putpixel((x, 2), C[2])
    im.putpixel((x, 3), C[2] if x % 4 else C[1])
    im.putpixel((x, 4), C[1])
    im.putpixel((x, 5), C[1] if x % 6 else C[0])
    im.putpixel((x, 6), C[0])
    im.putpixel((x, 7), OUT)
for (x, y) in ((3, 2), (4, 3), (5, 3), (11, 4), (12, 4), (13, 5)):   # fentes
    im.putpixel((x, y), OUT)
im.putpixel((8, 8), C[0]); im.putpixel((8, 9), OUT)                    # un brindille qui pend
im.save(sys.argv[1])
