# Totem HUD logo: a carved wooden totem stack with a band per element (earth,
# fire, water, air, bottom to top) and a gold timer ring at its shoulder.
# Drawn at 4x and downsampled.
#
# Writes into ../assets:
#   logo.png  1024x1024, project art (repo-only, not shipped)
#   logo.tga  64x64 addon-list icon (## IconTexture in the .toc)
# TGA because the anniversary client loads it on every build; PNG garbled.
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = 1024
S = 4
W = OUT * S

def P(x, y):  # design coords in 0..1024 -> canvas
    return (x * S, y * S)

def glow(size, shapes, color, blur):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for kind, args in shapes:
        getattr(d, kind)(*args, fill=color)
    return layer.filter(ImageFilter.GaussianBlur(blur * S))

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

# --- ground: a dark mound the totem is planted in
img.alpha_composite(glow((W, W), [("ellipse", ([P(212, 800), P(812, 900)],))], (0, 0, 0, 140), 20))
d = ImageDraw.Draw(img)
d.ellipse([P(232, 806), P(792, 882)], fill=(56, 42, 30, 255))

# --- the pole: wood, with four element bands and a carved top knob
px, pw = 512, 250
top, bot = 200, 850
d.rounded_rectangle([P(px - pw / 2, top), P(px + pw / 2, bot)], radius=40 * S, fill=(120, 78, 44, 255))
# wood highlight down the left and shadow down the right
d.rounded_rectangle([P(px - pw / 2 + 18, top + 18), P(px - pw / 2 + 52, bot - 40)], radius=16 * S, fill=(150, 102, 62, 255))
d.rounded_rectangle([P(px + pw / 2 - 52, top + 18), P(px + pw / 2 - 18, bot - 40)], radius=16 * S, fill=(92, 58, 32, 255))

bands = [  # bottom to top
    ("Earth", (86, 160, 52)),
    ("Fire",  (232, 92, 40)),
    ("Water", (52, 128, 232)),
    ("Air",   (154, 116, 230)),
]
band_h, band_gap = 110, 24
y = bot - 70 - band_h
for name, col in bands:
    box = [P(px - pw / 2 - 22, y), P(px + pw / 2 + 22, y + band_h)]
    img.alpha_composite(glow((W, W), [("rounded_rectangle", (box,))], col + (110,), 16))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=22 * S, fill=col + (255,))
    # a lighter top lip so each band reads as a carved ring
    d.rounded_rectangle([P(px - pw / 2 - 22, y), P(px + pw / 2 + 22, y + 26)], radius=13 * S,
                        fill=tuple(min(255, c + 60) for c in col) + (255,))
    # a simple carved glyph per band: two eyes and a mouth
    ey = y + band_h * 0.42
    d.ellipse([P(px - 60, ey - 14), P(px - 32, ey + 14)], fill=(20, 16, 12, 230))
    d.ellipse([P(px + 32, ey - 14), P(px + 60, ey + 14)], fill=(20, 16, 12, 230))
    d.rounded_rectangle([P(px - 34, y + band_h * 0.66), P(px + 34, y + band_h * 0.66 + 16)], radius=8 * S, fill=(20, 16, 12, 200))
    y -= band_h + band_gap

# --- top knob
d.ellipse([P(px - 70, top - 50), P(px + 70, top + 60)], fill=(140, 92, 52, 255))
d.ellipse([P(px - 44, top - 34), P(px + 10, top + 10)], fill=(170, 120, 74, 255))

# --- timer ring at the shoulder: gold arc, three quarters left
cx, cy, r = 780, 300, 118
img.alpha_composite(glow((W, W), [("ellipse", ([P(cx - r, cy - r), P(cx + r, cy + r)],))], (255, 200, 90, 130), 26))
d = ImageDraw.Draw(img)
d.ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=(18, 22, 30, 255), outline=(255, 226, 150, 255), width=8 * S)
d.pieslice([P(cx - r + 26, cy - r + 26), P(cx + r - 26, cy + r - 26)], start=-90, end=180, fill=(240, 176, 52, 255))
d.ellipse([P(cx - 14, cy - 14), P(cx + 14, cy + 14)], fill=(255, 246, 214, 255))

final = img.resize((OUT, OUT), Image.LANCZOS)
ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
final.save(os.path.join(ASSETS, "logo.png"))

# uncompressed 32-bit, top-left origin, same layout as the stock icons
final.resize((64, 64), Image.LANCZOS).save(os.path.join(ASSETS, "logo.tga"), format="TGA", rle=False, orientation=-1)
print("ok")
