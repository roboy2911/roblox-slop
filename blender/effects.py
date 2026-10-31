"""Particle images (white or full color, 128x128 PNG with alpha). Uses Pillow, not Blender.

    python blender/effects.py [output_dir]

FxGlow  soft round glow          FxSpark  four-point twinkle
FxFlame teardrop flame            FxSmoke  soft puffy cloud
FxStar  five-point star           FxCoin   gold coin
"""

import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

SIZE = 128


def radial(fn):
    img = Image.new("RGBA", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = (x - SIZE / 2 + 0.5) / (SIZE / 2), (y - SIZE / 2 + 0.5) / (SIZE / 2)
            px[x, y] = fn(dx, dy)
    return img


def glow():
    def f(dx, dy):
        d = math.hypot(dx, dy)
        a = max(0.0, 1 - d) ** 2
        return (255, 255, 255, int(a * 255))
    return radial(f)


def spark():
    def f(dx, dy):
        d = math.hypot(dx, dy)
        ray = max(0.0, 1 - abs(dx) * 14) * max(0.0, 1 - abs(dy)) + max(0.0, 1 - abs(dy) * 14) * max(0.0, 1 - abs(dx))
        core = max(0.0, 1 - d * 3) ** 2
        a = min(1.0, ray * 0.9 + core)
        return (255, 255, 255, int(a * 255))
    return radial(f)


def flame():
    def f(dx, dy):
        # Teardrop: round at the bottom, pointed at the top.
        y = (dy + 1) / 2  # 0 top, 1 bottom
        width = 0.62 * math.sqrt(max(0.0, y)) * (1 - max(0.0, y - 0.75) * 2.4)
        if width <= 0:
            return (0, 0, 0, 0)
        edge = abs(dx) / width
        if edge >= 1:
            return (0, 0, 0, 0)
        a = (1 - edge ** 2) * min(1.0, y * 2.5)
        heat = (1 - edge) * y
        r, g, b = 255, int(140 + 115 * heat), int(40 + 180 * max(0.0, heat - 0.4))
        return (r, min(255, g), min(255, b), int(a * 255))
    return radial(f)


def smoke():
    random.seed(3)
    img = Image.new("RGBA", (SIZE, SIZE))
    d = ImageDraw.Draw(img)
    for _ in range(9):
        r = random.randint(22, 36)
        x, y = random.randint(32, 96), random.randint(36, 92)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, 120))
    img = img.filter(ImageFilter.GaussianBlur(9))
    mask = glow().split()[3]
    alpha = Image.composite(img.split()[3], Image.new("L", img.size, 0), mask)
    img.putalpha(alpha)
    return img


def star():
    img = Image.new("RGBA", (SIZE * 2, SIZE * 2))
    d = ImageDraw.Draw(img)
    c = SIZE
    pts = []
    for i in range(10):
        r = (SIZE * 0.9) if i % 2 == 0 else (SIZE * 0.38)
        a = math.radians(i * 36 - 90)
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d.polygon(pts, fill=(255, 255, 255, 255))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def coin():
    img = Image.new("RGBA", (SIZE * 2, SIZE * 2))
    d = ImageDraw.Draw(img)
    s = SIZE * 2
    d.ellipse((8, 8, s - 8, s - 8), fill=(196, 128, 20, 255))
    d.ellipse((24, 24, s - 24, s - 24), fill=(255, 205, 60, 255))
    d.ellipse((44, 44, s - 44, s - 44), outline=(214, 150, 30, 255), width=10)
    # A little dragon-claw mark: three slashes.
    for i in (-1, 0, 1):
        x = s / 2 + i * 26
        d.line((x - 14, s / 2 - 40, x + 14, s / 2 + 40), fill=(196, 128, 20, 255), width=12)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


IMAGES = {"FxGlow": glow, "FxSpark": spark, "FxFlame": flame, "FxSmoke": smoke, "FxStar": star, "FxCoin": coin}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out")
    os.makedirs(out, exist_ok=True)
    for name, make in IMAGES.items():
        make().save(os.path.join(out, name + ".png"))
        print("wrote", name)
