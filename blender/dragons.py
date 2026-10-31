"""Baby dragons (one per species) and the Elder Dragon. Face -Y.

    python blender/dragons.py [output_dir] [Name ...]

Baby dragon parts: Body, WingL, WingR  (the client flaps the wings)
ElderDragon parts: Body, WingL, WingR
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

R = math.radians

# Species look. Names must match src/shared/Config/Dragons.luau.
SPECIES = {
    # Common
    "Mossling": dict(body=(0.32, 0.62, 0.24), belly=(0.86, 0.82, 0.55), wing=(0.55, 0.75, 0.35), horn=(0.9, 0.85, 0.7),
                     horns="nubs", extra="leaves"),
    "Pebblewing": dict(body=(0.5, 0.5, 0.52), belly=(0.75, 0.72, 0.66), wing=(0.42, 0.42, 0.46), horn=(0.3, 0.3, 0.32),
                       horns="nubs", extra="pebbles", wing_size=0.8),
    # Uncommon
    "Emberkit": dict(body=(0.92, 0.42, 0.12), belly=(1.0, 0.8, 0.4), wing=(0.85, 0.25, 0.1), horn=(0.25, 0.15, 0.1),
                     horns="long", extra="flametail"),
    "Reedscale": dict(body=(0.15, 0.55, 0.55), belly=(0.7, 0.9, 0.8), wing=(0.25, 0.7, 0.6), horn=(0.9, 0.9, 0.8),
                      horns="fins", extra=None),
    # Rare
    "Frostfang": dict(body=(0.55, 0.78, 0.95), belly=(0.92, 0.97, 1.0), wing=(0.7, 0.88, 1.0), horn=(0.95, 0.98, 1.0),
                      horns="long", extra="ice"),
    "Thornback": dict(body=(0.12, 0.35, 0.15), belly=(0.55, 0.65, 0.3), wing=(0.2, 0.45, 0.15), horn=(0.55, 0.3, 0.12),
                      horns="curled", extra="thorns", spikes=1.6),
    # Epic
    "Magmaw": dict(body=(0.18, 0.08, 0.06), belly=(1.0, 0.45, 0.08), wing=(0.65, 0.12, 0.05), horn=(0.12, 0.1, 0.1),
                   horns="curled", extra="lava", style="lava"),
    "Stormtail": dict(body=(0.38, 0.22, 0.62), belly=(0.95, 0.85, 0.35), wing=(0.25, 0.15, 0.5), horn=(1.0, 0.9, 0.3),
                      horns="bolt", extra="bolt_tail"),
    # Legendary
    "Solaris": dict(body=(1.0, 0.62, 0.08), belly=(1.0, 0.96, 0.82), wing=(1.0, 0.65, 0.2), horn=(1.0, 1.0, 0.95),
                    horns="crown", extra="halo"),
    "Glacius": dict(body=(0.12, 0.25, 0.75), belly=(0.75, 0.9, 1.0), wing=(0.3, 0.6, 1.0), horn=(0.9, 0.97, 1.0),
                    horns="crown", extra="ice", spikes=1.4),
    # Mythic
    "Voidwyrm": dict(body=(0.08, 0.05, 0.12), belly=(0.45, 0.2, 0.65), wing=(0.25, 0.08, 0.35), horn=(0.75, 0.35, 1.0),
                     horns="long", extra="void", style="void"),
    "Aurora": dict(body=(0.3, 0.9, 0.75), belly=(1.0, 0.95, 1.0), wing=(0.8, 0.45, 1.0), horn=(1.0, 1.0, 1.0),
                   horns="crown", extra="halo", style="aurora"),
    # Celestial (event only)
    "Starborn": dict(body=(0.05, 0.07, 0.22), belly=(0.95, 0.9, 0.7), wing=(0.15, 0.12, 0.4), horn=(1.0, 0.92, 0.6),
                     horns="crown", extra="stars", style="stars"),
}


def body_material(name, look):
    style = look.get("style")
    if style == "lava":
        return c.veins(name, base=look["body"], glow=(1.0, 0.5, 0.05), scale=3.5)
    if style == "void":
        return c.veins(name, base=look["body"], glow=(0.75, 0.35, 1.0), scale=3.5)
    if style == "aurora":
        return c.gradient(name, (0.25, 0.85, 0.8), (0.7, 0.4, 1.0), axis="Y", lo=-1.5, hi=1.5)
    if style == "stars":
        return c.starry(name)
    return c.scales(name, color=look["body"])


def wing(side, mat, bone_mat, span=2.2, height=1.5, root=(0.55, 0.25, 1.85), name="Wing"):
    """A bat wing on one side (side = 1 for +X). Root at the shoulder."""
    x0, y0, z0 = root
    s = side
    # Membrane outline in the wing's own plane (x outward, z up, y back).
    tip = (x0 + s * span, y0 + 0.5, z0 + height)
    verts = [
        (x0, y0 - 0.15, z0 + 0.15),            # 0 shoulder front
        (x0 + s * span * 0.55, y0 - 0.1, z0 + height * 0.75),  # 1 elbow
        tip,                                   # 2 tip
        (x0 + s * span * 0.85, y0 + 0.65, z0 + height * 0.25),  # 3 finger 1 end
        (x0 + s * span * 0.55, y0 + 0.75, z0 - 0.05),  # 4 scallop
        (x0 + s * span * 0.35, y0 + 0.8, z0 + 0.1),   # 5 finger 2 end
        (x0, y0 + 0.75, z0 - 0.1),             # 6 shoulder back
    ]
    faces = [(0, 1, 5, 6), (1, 2, 3, 4, 5)] if s > 0 else [(6, 5, 1, 0), (5, 4, 3, 2, 1)]
    membrane = c.paint(c.mesh_from(verts, faces, name + "Membrane", thickness=0.06), mat)
    parts = [membrane]
    # Bones along the leading edge and fingers.
    for a, b, r in ((verts[0], verts[1], 0.09), (verts[1], verts[2], 0.07), (verts[1], verts[3], 0.05), (verts[1], verts[5], 0.05)):
        parts.append(c.paint(c.curve_tube([(a, 1), (b, 0.6)], r, name + "Bone"), bone_mat))
    parts.append(c.paint(c.sphere(0.13, verts[1], segments=8, rings=6), bone_mat))
    return c.join(parts, name)


def horns(kind, mat, head):
    hx, hy, hz = head
    out = []
    if kind == "nubs":
        for s in (1, -1):
            out.append(c.paint(c.cylinder(0.14, 0.35, (hx + 0.32 * s, hy + 0.15, hz + 0.6), rot=(R(-25), R(12 * s), 0), verts=8, top_radius=0.05), mat))
    elif kind == "long":
        for s in (1, -1):
            out.append(c.paint(c.curve_tube([((hx + 0.3 * s, hy + 0.1, hz + 0.5), 1.0), ((hx + 0.42 * s, hy + 0.55, hz + 1.0), 0.6),
                                             ((hx + 0.45 * s, hy + 1.0, hz + 1.2), 0.1)], 0.13, "Horn"), mat))
    elif kind == "curled":
        for s in (1, -1):
            out.append(c.paint(c.curve_tube([((hx + 0.35 * s, hy + 0.1, hz + 0.45), 1.0), ((hx + 0.75 * s, hy + 0.5, hz + 0.75), 0.75),
                                             ((hx + 0.85 * s, hy + 0.3, hz + 0.25), 0.45), ((hx + 0.65 * s, hy - 0.05, hz + 0.2), 0.1)], 0.15, "Horn"), mat))
    elif kind == "fins":
        for s in (1, -1):
            fin = c.mesh_from([(hx + 0.35 * s, hy - 0.1, hz + 0.3), (hx + 0.95 * s, hy + 0.5, hz + 0.75), (hx + 0.4 * s, hy + 0.55, hz + 0.1)],
                              [(0, 1, 2)], "Fin", thickness=0.05)
            out.append(c.paint(fin, mat))
    elif kind == "bolt":
        for s in (1, -1):
            pts = [((hx + 0.3 * s, hy + 0.1, hz + 0.5), 1), ((hx + 0.45 * s, hy + 0.3, hz + 0.85), 0.8),
                   ((hx + 0.3 * s, hy + 0.5, hz + 0.95), 0.7), ((hx + 0.5 * s, hy + 0.75, hz + 1.35), 0.15)]
            out.append(c.paint(c.curve_tube(pts, 0.12, "Horn"), mat))
    elif kind == "crown":
        for i in range(5):
            a = R(-50 + i * 25)
            x = math.sin(a) * 0.4
            out.append(c.paint(c.cylinder(0.09, 0.55 if i != 2 else 0.75, (hx + x, hy + 0.2, hz + 0.75), rot=(R(-20), a * 0.6, 0),
                                          verts=8, top_radius=0.01), mat))
    return out


def baby_dragon(name, look, out):
    c.reset()
    body_mat = body_material(name + "Scales", look)
    belly = c.banded(name + "Belly", look["belly"], tuple(x * 0.82 for x in look["belly"]), count=9, wobble=0.3)
    wing_mat = c.skin(name + "WingSkin", color=look["wing"], blotch=0.18)
    bone = c.scales(name + "Bone", color=tuple(x * 0.8 for x in look["body"]), size=25) if not look.get("style") else body_mat
    horn = c.metal(name + "Horn", color=look["horn"], scratches=0.12)
    eye_white = c.solid("EyeWhite", (0.98, 0.98, 0.95), 0.2)
    pupil = c.solid("Pupil", (0.03, 0.03, 0.05), 0.1)
    shine = c.solid("Shine", (1, 1, 1), 0.1)
    blush = c.solid("Blush", (1.0, 0.55, 0.55), 0.6)

    head = (0, -1.05, 2.35)
    parts = [
        c.paint(c.sphere(1.0, (0, 0.1, 1.2), scale=(0.95, 1.15, 0.88), segments=24, rings=16), body_mat),
        c.paint(c.sphere(0.85, (0, -0.42, 1.12), scale=(0.85, 0.7, 0.85), segments=20, rings=12), belly),
        c.paint(c.sphere(0.48, (0, -0.65, 1.85), scale=(0.9, 0.9, 1.1)), body_mat),          # neck
        c.paint(c.sphere(0.78, head, scale=(1.0, 0.95, 0.9), segments=24, rings=16), body_mat),
        c.paint(c.sphere(0.48, (0, -1.68, 2.12), scale=(0.95, 1.0, 0.72), segments=18, rings=10), body_mat),  # snout
    ]
    # Big cute eyes.
    for s in (1, -1):
        parts.append(c.paint(c.sphere(0.27, (0.36 * s, -1.6, 2.55), segments=14, rings=10), eye_white))
        parts.append(c.paint(c.sphere(0.17, (0.38 * s, -1.79, 2.55), segments=12, rings=8), pupil))
        parts.append(c.paint(c.sphere(0.06, (0.33 * s, -1.9, 2.64), segments=8, rings=6), shine))
        parts.append(c.paint(c.sphere(0.12, (0.52 * s, -1.6, 2.15), scale=(1, 0.5, 0.6), segments=8, rings=6), blush))
        parts.append(c.paint(c.sphere(0.05, (0.16 * s, -2.12, 2.2), segments=6, rings=4), pupil))  # nostril
    parts += horns(look["horns"], horn, head)

    # Legs and feet.
    for s in (1, -1):
        for y, z in ((-0.55, 0.45), (0.65, 0.45)):
            parts.append(c.paint(c.cylinder(0.26, 0.6, (0.55 * s, y, z), verts=10), body_mat))
            parts.append(c.paint(c.sphere(0.3, (0.58 * s, y - 0.12, 0.14), scale=(1, 1.25, 0.55), segments=12, rings=8), body_mat))
            for t in (-1, 0, 1):
                parts.append(c.paint(c.cylinder(0.06, 0.16, (0.58 * s + t * 0.13, y - 0.48, 0.1), rot=(R(80), 0, 0), verts=6, top_radius=0.0), horn))
        # Little arms.
        parts.append(c.paint(c.sphere(0.2, (0.62 * s, -0.95, 1.25), scale=(0.8, 1.1, 0.8)), body_mat))

    # Tail.
    tail_pts = [((0, 1.05, 1.0), 1.0), ((0, 1.9, 0.6), 0.7), ((0.35, 2.6, 0.55), 0.45), ((0.55, 3.1, 0.85), 0.2)]
    parts.append(c.paint(c.curve_tube(tail_pts, 0.42, "Tail"), body_mat))
    tip = (0.6, 3.25, 0.95)
    extra = look.get("extra")
    if extra == "flametail":
        flame = c.solid("Flame", (1.0, 0.6, 0.1), 0.4)
        core = c.solid("FlameCore", (1.0, 0.95, 0.5), 0.4)
        parts.append(c.paint(c.cylinder(0.32, 0.9, (tip[0], tip[1], tip[2] + 0.35), verts=10, top_radius=0.0), flame))
        parts.append(c.paint(c.cylinder(0.17, 0.55, (tip[0], tip[1] - 0.05, tip[2] + 0.25), verts=8, top_radius=0.0), core))
    elif extra == "bolt_tail":
        bolt = c.solid("Bolt", (1.0, 0.9, 0.25), 0.3)
        pts = [(0, 0), (0.35, 0.3), (0.12, 0.38), (0.45, 0.8), (-0.05, 0.4), (0.15, 0.32)]
        parts.append(c.paint(c.mesh_from([(tip[0] + x, tip[1], tip[2] + z) for x, z in pts], [tuple(range(6))], "Bolt", 0.12), bolt))
    else:
        spade = c.mesh_from([(tip[0] - 0.05, tip[1] - 0.3, tip[2]), (tip[0] + 0.4, tip[1] + 0.1, tip[2] + 0.05),
                             (tip[0], tip[1] + 0.55, tip[2] + 0.1), (tip[0] - 0.42, tip[1] + 0.08, tip[2] + 0.05)],
                            [(0, 1, 2, 3)], "Spade", 0.1)
        parts.append(c.paint(spade, horn))

    # Back spikes.
    spike = look.get("spikes", 1.0)
    for i, (y, z) in enumerate(((-0.75, 2.95), (-0.35, 2.2), (0.05, 2.1), (0.45, 2.0), (0.85, 1.7), (1.4, 1.2), (2.0, 0.95))):
        h = 0.32 * spike * (1.0 - i * 0.07)
        parts.append(c.paint(c.cylinder(0.13 * spike, h, (0, y, z + h * 0.3), rot=(R(25), 0, 0), verts=6, top_radius=0.0), horn))

    # Species extras.
    if extra == "leaves":
        leaf = c.leaves("Leaf", color=(0.25, 0.55, 0.15))
        for s in (1, -1):
            parts.append(c.paint(c.sphere(0.3, (0.62 * s, -0.95, 2.95), scale=(0.35, 1.0, 0.55), segments=10, rings=6), leaf))
        parts.append(c.paint(c.sphere(0.35, (0, 0.35, 2.05), scale=(1.4, 1.0, 0.35), segments=12, rings=8), leaf))
    elif extra == "pebbles":
        rock = c.stone("Pebble", (0.6, 0.58, 0.55))
        for x, y, z, r in ((0.3, 0.2, 2.0, 0.22), (-0.35, 0.5, 1.9, 0.2), (0.0, 0.8, 1.75, 0.25), (0.2, -0.3, 2.05, 0.17)):
            parts.append(c.paint(c.sphere(r, (x, y, z), scale=(1, 1, 0.7), segments=8, rings=6), rock))
    elif extra == "ice":
        ice = c.crystal("Ice", bright=(0.95, 1.0, 1.0), deep=(0.35, 0.65, 0.95))
        for x, y, z, h, tilt in ((0.25, 0.1, 2.0, 0.7, 15), (-0.25, 0.4, 1.95, 0.6, -15), (0.05, 0.75, 1.75, 0.55, 5), (0.0, -0.25, 2.1, 0.5, 0)):
            parts.append(c.paint(c.cylinder(0.15, h, (x, y, z + h / 2), rot=(R(20), R(tilt), 0), verts=5, top_radius=0.0), ice))
    elif extra == "thorns":
        thorn = c.wood("Thorn", light=(0.5, 0.3, 0.12), dark=(0.25, 0.12, 0.05))
        for s in (1, -1):
            for y in (-0.2, 0.3, 0.8):
                parts.append(c.paint(c.cylinder(0.08, 0.35, (0.8 * s, y, 1.35), rot=(0, R(70 * s), 0), verts=6, top_radius=0.0), thorn))
    elif extra == "lava":
        rock = c.stone("LavaRock", (0.15, 0.12, 0.12))
        for s in (1, -1):
            parts.append(c.paint(c.sphere(0.22, (0.45 * s, 0.3, 1.9), scale=(1, 1, 0.6), segments=8, rings=6), rock))
    elif extra == "halo":
        gold = c.metal("Halo", color=(1.0, 0.85, 0.35), scratches=0.08)
        parts.append(c.paint(c.torus(0.5, 0.06, (0, -0.95, 3.65), rot=(R(10), 0, 0)), gold))
    elif extra == "void":
        glow = c.crystal("VoidGem", bright=(0.95, 0.7, 1.0), deep=(0.35, 0.05, 0.6))
        parts.append(c.paint(c.sphere(0.18, (0, -1.55, 3.0), scale=(0.8, 0.5, 1.2), segments=8, rings=6), glow))
        for s in (1, -1):
            parts.append(c.paint(c.sphere(0.12, (0.4 * s, 0.2, 1.95), segments=8, rings=6), glow))
    elif extra == "stars":
        star = c.solid("Star", (1.0, 0.92, 0.55), 0.3)
        for x, y, z in ((0.0, -0.9, 3.75), (0.5, 0.4, 2.1), (-0.45, 0.6, 1.95)):
            pts = [(x + 0.22 * math.sin(R(i * 36)) * (1 if i % 2 == 0 else 0.45), y, z + 0.22 * math.cos(R(i * 36)) * (1 if i % 2 == 0 else 0.45)) for i in range(10)]
            parts.append(c.paint(c.mesh_from(pts, [tuple(range(10))], "Star", 0.08), star))

    c.join(parts, "Body")
    size = look.get("wing_size", 1.0)
    for s, n in ((-1, "WingL"), (1, "WingR")):
        wing(s, wing_mat, bone, span=2.2 * size, height=1.5 * size, name=n)
    c.bake_and_export(name, out, texture_size=1024, preview=dict(camera=(5.5, -7.5, 4.5), target=(0, 0, 1.6)))


def elder_dragon(out):
    """The big hazard dragon that sweeps the valley. Mean-looking, long."""
    c.reset()
    body_mat = c.scales("ElderScales", color=(0.42, 0.08, 0.06), size=8)
    belly = c.banded("ElderBelly", (0.85, 0.6, 0.3), (0.6, 0.4, 0.2), count=12, wobble=0.3)
    wing_mat = c.skin("ElderWing", color=(0.35, 0.06, 0.05), blotch=0.25)
    horn = c.metal("ElderHorn", color=(0.2, 0.18, 0.16), scratches=0.2)
    eye = c.solid("ElderEye", (1.0, 0.8, 0.1), 0.2)
    pupil = c.solid("ElderPupil", (0.02, 0.02, 0.02), 0.1)
    mouth = c.solid("Mouth", (0.35, 0.03, 0.03), 0.6)
    tooth = c.solid("Tooth", (0.95, 0.92, 0.85), 0.4)

    parts = [
        c.paint(c.sphere(1.6, (0, 0, 3), scale=(1.0, 2.2, 0.9), segments=24, rings=16), body_mat),
        c.paint(c.sphere(1.3, (0, -0.6, 2.6), scale=(0.9, 1.8, 0.7), segments=20, rings=12), belly),
        c.paint(c.curve_tube([((0, -3.0, 3.4), 1.0), ((0, -4.4, 4.4), 0.8), ((0, -5.4, 4.8), 0.7)], 0.85, "Neck"), body_mat),
        c.paint(c.sphere(1.0, (0, -6.0, 5.0), scale=(0.9, 1.3, 0.75), segments=20, rings=12), body_mat),
        c.paint(c.box((1.1, 1.8, 0.4), (0, -7.3, 4.85)), body_mat),       # upper jaw
        c.paint(c.box((0.95, 1.6, 0.3), (0, -7.0, 4.2), rot=(R(-18), 0, 0)), body_mat),  # lower jaw (open)
        c.paint(c.box((0.85, 1.5, 0.3), (0, -7.05, 4.5), rot=(R(-9), 0, 0)), mouth),
    ]
    for s in (1, -1):
        parts.append(c.paint(c.sphere(0.22, (0.55 * s, -6.6, 5.35), scale=(1, 0.8, 0.6)), eye))
        parts.append(c.paint(c.box((0.06, 0.1, 0.22), (0.6 * s, -6.78, 5.35)), pupil))
        parts.append(c.paint(c.box((0.4, 0.2, 0.08), (0.5 * s, -6.6, 5.6), rot=(0, R(-20 * s), 0)), horn))  # brow
        parts.append(c.paint(c.curve_tube([((0.5 * s, -5.7, 5.5), 1), ((0.9 * s, -4.9, 6.2), 0.6), ((1.0 * s, -4.0, 6.5), 0.1)], 0.22, "Horn"), horn))
        for i in range(4):
            parts.append(c.paint(c.cylinder(0.08, 0.3, (0.4 * s, -7.9 + i * 0.35, 4.55), rot=(R(180), 0, 0), verts=6, top_radius=0), tooth))
        for y in (-1.5, 1.8):
            parts.append(c.paint(c.curve_tube([((1.0 * s, y, 2.4), 1), ((1.3 * s, y - 0.3, 1.2), 0.8), ((1.35 * s, y - 0.8, 0.5), 0.6)], 0.38, "Leg"), body_mat))
            for t in (-1, 0, 1):
                parts.append(c.paint(c.cylinder(0.1, 0.5, (1.35 * s + t * 0.22, y - 1.2, 0.4), rot=(R(80), 0, 0), verts=6, top_radius=0), horn))
    parts.append(c.paint(c.curve_tube([((0, 3.2, 3.0), 1.0), ((0, 5.5, 2.6), 0.7), ((0.8, 7.8, 2.8), 0.45), ((1.6, 9.8, 3.6), 0.15)], 0.95, "Tail"), body_mat))
    for i in range(10):
        y = -5.2 + i * 1.45
        z = 6.0 - abs(i - 2) * 0.35 if i < 4 else 4.6 - (i - 4) * 0.25
        parts.append(c.paint(c.cylinder(0.28, 0.9 - i * 0.05, (0, y, z), rot=(R(30), 0, 0), verts=6, top_radius=0), horn))
    c.join(parts, "Body")
    bone = c.scales("ElderBone", color=(0.3, 0.06, 0.05), size=20)
    for s, n in ((-1, "WingL"), (1, "WingR")):
        wing(s, wing_mat, bone, span=8.5, height=5.0, root=(1.1, -1.0, 3.8), name=n)
    c.bake_and_export("ElderDragon", out, texture_size=1024, preview=dict(camera=(16, -20, 12), target=(0, -1, 3), size=(800, 560)))


if __name__ == "__main__":
    out = c.out_dir()
    wanted = sys.argv[2:]
    for name, look in SPECIES.items():
        if not wanted or name in wanted:
            baby_dragon(name, look, out)
    if not wanted or "ElderDragon" in wanted:
        elder_dragon(out)
