"""Le champignon qui fait bondir (24 × 18) : un gros chapeau orangé, tacheté de crème, sur un
pied trapu. Il est vivant même dans la forêt malade (la poussière n'a pas prise sur lui)."""
from PIL import Image, ImageDraw
import sys
OUT = (30, 14, 10, 255)
CAP = [(120, 44, 20, 255), (170, 70, 28, 255), (214, 108, 44, 255), (240, 150, 70, 255)]
SPOT = (246, 226, 180, 255)
STEM = [(150, 132, 104, 255), (196, 180, 148, 255), (226, 214, 186, 255)]
im = Image.new("RGBA", (24, 18), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.rectangle((8, 9, 15, 17), fill=STEM[1], outline=OUT)
d.line((9, 10, 9, 16), fill=STEM[2]); d.line((14, 10, 14, 16), fill=STEM[0])
d.pieslice((0, 0, 23, 18), 180, 360, fill=CAP[1], outline=OUT)
d.line((1, 9, 22, 9), fill=OUT)
d.arc((3, 2, 20, 16), 200, 300, fill=CAP[3]); d.arc((2, 3, 21, 17), 290, 350, fill=CAP[2])
for x in range(2, 22): d.point((x, 8), fill=CAP[0])
for (x, y) in ((6, 4), (7, 4), (12, 2), (13, 2), (17, 5), (10, 6), (4, 7), (19, 7)):
    d.point((x, y), fill=SPOT)
im.save(sys.argv[1])
im.resize((144, 108), Image.NEAREST).save("/tmp/shots/mush.png")
