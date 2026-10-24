# Draws Media/Logo.tga for Puzatik Defensive Planner: a blue "P" on navy inside an orange
# hexagon. Run from the repo root: python3 tools/bake-logo.py
import math
from PIL import Image, ImageDraw, ImageFont

root = 'addon/PuzatikDefensivePlanner/Media/'
S = 512  # drawn large, then scaled down to 64x64 for smooth edges
img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

def hexagon(r):
    c = S / 2
    return [(c + r * math.cos(math.radians(60 * i - 90)), c + r * math.sin(math.radians(60 * i - 90))) for i in range(6)]

d.polygon(hexagon(S * 0.49), fill=(245, 144, 0, 255))
d.polygon(hexagon(S * 0.43), fill=(255, 170, 0, 255))
d.polygon(hexagon(S * 0.37), fill=(3, 16, 31, 255))
font = ImageFont.truetype(root + 'Fonts/URWGothic-Demi.ttf', int(S * 0.5))
box = d.textbbox((0, 0), 'P', font=font)
x = (S - (box[2] - box[0])) / 2 - box[0]
y = (S - (box[3] - box[1])) / 2 - box[1]
d.text((x + S * 0.012, y + S * 0.012), 'P', font=font, fill=(0, 149, 229, 255))
d.text((x, y), 'P', font=font, fill=(0, 130, 211, 255))
img.resize((64, 64), Image.LANCZOS).save(root + 'Logo.tga')
