"""La fourmi corrompue (forêt des irokos) : une grosse fourmi magnan grisée par la poussière
d'Adaka, yeux de braise. 4 images de marche (24 × 20), tournée vers la gauche."""
from PIL import Image, ImageDraw
import sys
OUT = (18, 14, 14, 255)
BODY = (78, 72, 68, 255); DARK = (52, 47, 45, 255); LIGHT = (118, 110, 102, 255); DUST = (150, 142, 128, 255)
EYE = (255, 170, 60, 255); EYE_C = (255, 80, 40, 255)
W, H = 24, 20
def ant(f):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    bob = (0, -1, 0, -1)[f]
    # pattes : trois paires, en tripode alterné
    hips = [(8, 12), (11, 12), (14, 12)]
    for i, (hx, hy) in enumerate(hips):
        up = (i + f) % 2
        for side, dx in ((0, -3), (1, 3)):
            fx = hx + dx + (1 if up else -1)
            fy = 18 - (1 if up and side == 0 else 0)
            d.line((hx, hy + bob, hx + dx // 2, 15 + bob, fx, fy), fill=OUT if side else DARK, width=1)
    # abdomen (arrière, à droite), thorax, tête (gauche)
    d.ellipse((13, 5 + bob, 23, 14 + bob), fill=BODY, outline=OUT)
    d.ellipse((8, 8 + bob, 14, 13 + bob), fill=BODY, outline=OUT)
    d.ellipse((1, 6 + bob, 9, 13 + bob), fill=BODY, outline=OUT)
    # mandibules et antennes
    d.line((1, 11 + bob, 0, 13 + bob), fill=OUT); d.line((3, 12 + bob, 2, 14 + bob), fill=OUT)
    d.line((4, 6 + bob, 2, 2 + bob + (f % 2)), fill=OUT); d.line((6, 6 + bob, 7, 2 + bob - (f % 2)), fill=OUT)
    # volume : reflet en haut, ombre en bas
    for x0, x1, y in ((15, 20, 7), (9, 12, 9), (3, 6, 7)):
        d.line((x0, y + bob, x1, y + bob), fill=LIGHT)
    d.line((15, 12 + bob, 21, 12 + bob), fill=DARK); d.line((3, 12 + bob, 7, 12 + bob), fill=DARK)
    # rayures de l'abdomen, poussière grise
    for x in (17, 20):
        d.line((x, 6 + bob, x, 13 + bob), fill=DARK)
    for (x, y) in ((16, 9), (21, 8), (19, 11), (10, 10)):
        d.point((x, y + bob), fill=DUST)
    # œil de braise
    d.rectangle((3, 8 + bob, 4, 9 + bob), fill=EYE); d.point((3, 9 + bob), fill=EYE_C)
    return im
sheet = Image.new("RGBA", (W * 4, H))
for f in range(4): sheet.paste(ant(f), (f * W, 0))
sheet.save(sys.argv[1])
sheet.resize((W * 4 * 6, H * 6), Image.NEAREST).save("/tmp/shots/ant.png")
