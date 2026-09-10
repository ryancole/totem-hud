# Totem HUD logo: four shaman totems standing in the ground, one per
# element (earth, fire, water, air), with a countdown badge at the top
# right showing a digit in the addon's font. Drawn at 4x and downsampled.
#
# Writes into ../assets:
#   logo.png  1024x1024, project art (repo-only, not shipped)
#   logo.tga  64x64 addon-list icon (## IconTexture in the .toc)
# TGA because the anniversary client loads it on every build; PNG garbled.
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

OUT = 1024
S = 4
W = OUT * S
ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
FONT = os.path.join(ASSETS, "CascadiaMono.ttf")

def P(x, y):  # design coords in 0..1024 -> canvas
    return (x * S, y * S)

def glow(size, shapes, color, blur):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for kind, args in shapes:
        getattr(d, kind)(*args, fill=color)
    return layer.filter(ImageFilter.GaussianBlur(blur * S))

def lighter(col, k):
    return tuple(min(255, int(c + (255 - c) * k)) for c in col)

def darker(col, k):
    return tuple(int(c * (1 - k)) for c in col)

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))

# --- background: rounded square, deep teal with a lighter radial core
grad = Image.radial_gradient("L").resize((W, W))            # 0 center -> 255 edge
inner = Image.new("RGBA", (W, W), (32, 78, 84, 255))
outer = Image.new("RGBA", (W, W), (10, 26, 34, 255))
bg = Image.composite(outer, inner, grad)
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle([P(0, 0), P(1024, 1024)], radius=190 * S, fill=255)
bg.putalpha(mask)
img.alpha_composite(bg)

# --- ground: a dark mound the totems are planted in
img.alpha_composite(glow((W, W), [("ellipse", ([P(120, 770), P(904, 900)],))], (0, 0, 0, 150), 24))
d = ImageDraw.Draw(img)
d.ellipse([P(140, 780), P(884, 880)], fill=(52, 40, 28, 255))
d.ellipse([P(180, 792), P(844, 850)], fill=(66, 50, 34, 255))

# --- the totems: a wooden post each, with a carved element head on top.
# Left to right in the HUD's order: earth, fire, water, air. Heights are
# staggered so the row reads as separate posts rather than a fence.
WOOD = (122, 80, 46)
totems = [  # (center x, top y, element color)
    (232, 330, (86, 160, 52)),    # earth
    (412, 250, (232, 92, 40)),    # fire
    (592, 290, (52, 128, 232)),   # water
    (772, 370, (154, 116, 230)),  # air
]
POST_W = 120
HEAD_H = 150
BASE_Y = 830

for cx, top, col in totems:
    l, r = cx - POST_W / 2, cx + POST_W / 2
    # post shadow on the ground
    img.alpha_composite(glow((W, W), [("ellipse", ([P(l - 30, BASE_Y - 30), P(r + 30, BASE_Y + 30)],))], (0, 0, 0, 120), 12))
    d = ImageDraw.Draw(img)
    # post, with a highlight strip on the left and a shadow on the right
    d.rounded_rectangle([P(l, top + HEAD_H - 20), P(r, BASE_Y)], radius=18 * S, fill=WOOD)
    d.rounded_rectangle([P(l + 12, top + HEAD_H), P(l + 34, BASE_Y - 24)], radius=10 * S, fill=lighter(WOOD, 0.18))
    d.rounded_rectangle([P(r - 34, top + HEAD_H), P(r - 12, BASE_Y - 24)], radius=10 * S, fill=darker(WOOD, 0.25))
    # two carved bands down the post
    for by in (top + HEAD_H + 90, top + HEAD_H + 200):
        d.rounded_rectangle([P(l - 6, by), P(r + 6, by + 22)], radius=8 * S, fill=darker(WOOD, 0.35))
    # element head: a glowing carved block, a shade wider than the post
    hl, hr = l - 22, r + 22
    box = [P(hl, top), P(hr, top + HEAD_H)]
    img.alpha_composite(glow((W, W), [("rounded_rectangle", (box,))], col + (120,), 20))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=26 * S, fill=col)
    d.rounded_rectangle([P(hl, top), P(hr, top + 30)], radius=15 * S, fill=lighter(col, 0.35))
    # carved face
    ey = top + HEAD_H * 0.45
    d.ellipse([P(cx - 46, ey - 14), P(cx - 18, ey + 14)], fill=(20, 16, 12, 230))
    d.ellipse([P(cx + 18, ey - 14), P(cx + 46, ey + 14)], fill=(20, 16, 12, 230))
    d.rounded_rectangle([P(cx - 28, top + HEAD_H * 0.7), P(cx + 28, top + HEAD_H * 0.7 + 16)], radius=8 * S, fill=(20, 16, 12, 200))
    # a small knob on top
    d.ellipse([P(cx - 34, top - 34), P(cx + 34, top + 30)], fill=lighter(WOOD, 0.1))

# --- countdown badge: dark disc in a gold ring, a digit in the HUD font.
# "9" reads as "under ten", the warning threshold.
bx, by, br = 812, 212, 150
img.alpha_composite(glow((W, W), [("ellipse", ([P(bx - br, by - br), P(bx + br, by + br)],))], (255, 200, 90, 150), 30))
d = ImageDraw.Draw(img)
d.ellipse([P(bx - br, by - br), P(bx + br, by + br)], fill=(18, 22, 30, 255), outline=(255, 226, 150, 255), width=10 * S)
# remaining-time arc inside the ring, most of the way round
d.arc([P(bx - br + 26, by - br + 26), P(bx + br - 26, by + br - 26)], start=-90, end=200, fill=(240, 176, 52, 255), width=14 * S)
font = ImageFont.truetype(FONT, int(190 * S))
digit = "9"
bbox = d.textbbox((0, 0), digit, font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
tx, ty = bx * S - tw / 2 - bbox[0], by * S - th / 2 - bbox[1]
d.text((tx, ty), digit, font=font, fill=(255, 246, 214, 255), stroke_width=int(6 * S), stroke_fill=(240, 176, 52, 255))

final = img.resize((OUT, OUT), Image.LANCZOS)
final.save(os.path.join(ASSETS, "logo.png"))

# uncompressed 32-bit, top-left origin, same layout as the stock icons
final.resize((64, 64), Image.LANCZOS).save(os.path.join(ASSETS, "logo.tga"), format="TGA", rle=False, orientation=-1)
print("ok")
