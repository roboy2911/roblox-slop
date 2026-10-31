"""Dragon eggs, one per rarity. Upright, base at z=0.

    python blender/eggs.py [output_dir] [Name ...]

Parts: Egg
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

R = math.radians


def common_egg():
    return c.speckled("Shell", base=(0.93, 0.88, 0.74), spot=(0.5, 0.32, 0.15), scale=6, amount=0.57), []


def uncommon_egg():
    return c.speckled("Shell", base=(0.4, 0.72, 0.3), spot=(0.12, 0.32, 0.08), scale=4, amount=0.56), []


def rare_egg():
    return c.banded("Shell", (0.15, 0.45, 0.9), (0.8, 0.92, 1.0), count=1.6, wobble=2), []


def epic_egg():
    shell = c.banded("Shell", (0.42, 0.1, 0.68), (0.95, 0.5, 0.95), count=1.8, wobble=5)
    gem = c.crystal("Gem", bright=(1.0, 0.75, 1.0), deep=(0.45, 0.05, 0.6))
    extras = []
    for i in range(4):
        a = R(i * 90 + 45)
        extras.append(c.paint(c.sphere(0.13, (math.cos(a) * 0.95, math.sin(a) * 0.98, 1.35), scale=(0.6, 0.6, 1)), gem))
    return shell, extras


def legendary_egg():
    shell = c.speckled("Shell", base=(1.0, 0.78, 0.22), spot=(1.0, 0.95, 0.7), scale=5, amount=0.6)
    gold = c.metal("Gold", color=(0.95, 0.72, 0.2), scratches=0.1)
    ruby = c.crystal("Ruby", bright=(1.0, 0.6, 0.6), deep=(0.7, 0.02, 0.05))
    extras = [c.paint(c.torus(0.98, 0.07, (0, 0, 1.3), major_segments=32), gold),
              c.paint(c.torus(0.62, 0.06, (0, 0, 2.45), major_segments=28), gold)]
    for i in range(6):
        a = R(i * 60)
        extras.append(c.paint(c.sphere(0.1, (math.cos(a) * 1.04, math.sin(a) * 1.04, 1.3)), ruby))
    return shell, extras


def mythic_egg():
    shell = c.veins("Shell", base=(0.1, 0.05, 0.16), glow=(0.8, 0.35, 1.0), scale=3)
    crystal = c.crystal("Crystal", bright=(0.95, 0.75, 1.0), deep=(0.4, 0.05, 0.7))
    extras = []
    for i in range(5):
        a = R(i * 72)
        extras.append(c.paint(c.cylinder(0.14, 0.6, (math.cos(a) * 0.85, math.sin(a) * 0.85, 0.35),
                                         rot=(R(35) * math.sin(a), -R(35) * math.cos(a), 0), verts=5, top_radius=0), crystal))
    return shell, extras


def celestial_egg():
    shell = c.starry("Shell")
    star = c.solid("Star", (1.0, 0.9, 0.5), 0.3)
    ring = c.metal("Ring", color=(1.0, 0.92, 0.65), scratches=0.05)
    pts = [(0.35 * math.sin(R(i * 36)) * (1 if i % 2 == 0 else 0.42), 0, 3.3 + 0.35 * math.cos(R(i * 36)) * (1 if i % 2 == 0 else 0.42)) for i in range(10)]
    extras = [c.paint(c.mesh_from(pts, [tuple(range(10))], "Star", 0.12), star),
              c.paint(c.torus(1.35, 0.05, (0, 0, 1.3), rot=(R(20), R(10), 0), major_segments=40), ring)]
    return shell, extras


EGGS = {
    "EggCommon": common_egg,
    "EggUncommon": uncommon_egg,
    "EggRare": rare_egg,
    "EggEpic": epic_egg,
    "EggLegendary": legendary_egg,
    "EggMythic": mythic_egg,
    "EggCelestial": celestial_egg,
}


def build(name, make, out):
    c.reset()
    shell, extras = make()
    egg = c.paint(c.egg_shape(1.0, (0, 0, 0), segments=28, rings=18), shell)
    c.join([egg] + extras, "Egg")
    c.bake_and_export(name, out, texture_size=512, preview=dict(camera=(3.5, -5, 3), target=(0, 0, 1.2), size=(400, 400)))


if __name__ == "__main__":
    out = c.out_dir()
    wanted = sys.argv[2:]
    for name, make in EGGS.items():
        if not wanted or name in wanted:
            build(name, make, out)
