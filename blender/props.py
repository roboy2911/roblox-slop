"""Castle pieces, base props and valley decorations. Base at z=0, front faces -Y.

    python blender/props.py [output_dir] [Name ...]

Part names the game looks for:
    FusionAltar: Base, Crystal   (the client spins the crystal)
    Club: Handle                 (the bonk tool)
Everything else is a single part named after the model.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402

R = math.radians


def castle_stone():
    return c.stone("CastleStone", (0.6, 0.57, 0.52))


def bricks(name="Bricks", color=(0.62, 0.58, 0.52)):
    """Stone blocks with mortar lines (made with the planks pattern, on two axes)."""
    mat, nodes, links, bsdf = c._new_material(name)
    vec = c._coords(nodes, links, (1, 1, 1))
    brick = nodes.new("ShaderNodeTexBrick")
    brick.inputs["Scale"].default_value = 0.6
    brick.inputs["Mortar Size"].default_value = 0.03
    brick.inputs["Color1"].default_value = (*color, 1)
    brick.inputs["Color2"].default_value = (*(x * 0.82 for x in color), 1)
    brick.inputs["Mortar"].default_value = (0.32, 0.3, 0.28, 1)
    sep = nodes.new("ShaderNodeSeparateXYZ")
    comb = nodes.new("ShaderNodeCombineXYZ")
    links.new(vec, sep.inputs["Vector"])
    # Use (x + y, z) so bricks run around every side of a box.
    add = nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    links.new(sep.outputs["X"], add.inputs[0])
    links.new(sep.outputs["Y"], add.inputs[1])
    links.new(add.outputs[0], comb.inputs["X"])
    links.new(sep.outputs["Z"], comb.inputs["Y"])
    links.new(comb.outputs["Vector"], brick.inputs["Vector"])
    noise = c._ramp(nodes, links, c._noise(nodes, links, vec, 3), [(0.3, (0.8, 0.8, 0.8)), (0.7, (1, 1, 1))])
    links.new(c._mix(nodes, links, brick.outputs["Color"], noise, 1.0, blend="MULTIPLY"), bsdf.inputs["Base Color"])
    return mat


# ------------------------------------------------------------------ castle


def castle_wall():
    """A 12 x 3 x 14 wall segment with battlements."""
    b = bricks()
    parts = [c.paint(c.box((12, 3, 12), (0, 0, 6)), b)]
    for i in range(6):
        if i % 2 == 0:
            parts.append(c.paint(c.box((2, 3.2, 2), (-5 + i * 2, 0, 13)), b))
    parts.append(c.paint(c.box((12.4, 3.4, 0.6), (0, 0, 12.1)), castle_stone()))
    c.join(parts, "CastleWall")


def castle_tower():
    """A round tower 9 wide, 24 tall, with a pointy red roof."""
    b = bricks()
    roof = c.planks("Roof", light=(0.7, 0.16, 0.12), dark=(0.42, 0.08, 0.06), plank_axis="Z", planks_per_unit=3)
    wood = c.wood("Trim", light=(0.42, 0.28, 0.15), dark=(0.22, 0.13, 0.06))
    window = c.solid("Window", (0.08, 0.06, 0.05), 0.9)
    parts = [
        c.paint(c.cylinder(4.5, 16, (0, 0, 8), verts=20), b),
        c.paint(c.cylinder(5.0, 1.0, (0, 0, 16.5), verts=20), castle_stone()),
        c.paint(c.cylinder(5.4, 8, (0, 0, 21), verts=20, top_radius=0.2), roof),
        c.paint(c.cylinder(0.12, 2.5, (0, 0, 26), verts=6), wood),
    ]
    for a in (0, 120, 240):
        x, y = math.sin(R(a)) * 4.45, -math.cos(R(a)) * 4.45
        parts.append(c.paint(c.box((1.2, 0.4, 2.2), (x, y, 11), rot=(0, 0, R(a))), window))
    c.join(parts, "CastleTower")


def gatehouse():
    """Gate arch, 18 wide, 16 tall. Opening is 10 wide, 11 tall."""
    b = bricks()
    wood = c.planks("GateWood", light=(0.45, 0.3, 0.16), dark=(0.22, 0.13, 0.06), plank_axis="Z")
    iron = c.metal("Iron", color=(0.25, 0.25, 0.27))
    parts = [
        c.paint(c.box((4, 4, 14), (-7, 0, 7)), b),
        c.paint(c.box((4, 4, 14), (7, 0, 7)), b),
        c.paint(c.box((10.2, 3.8, 3.2), (0, 0, 12.4)), b),
    ]
    for i in range(5):
        parts.append(c.paint(c.box((2, 4.2, 2), (-8 + i * 4, 0, 15)), b))
    # Open gate doors folded back against the inside.
    for s in (1, -1):
        parts.append(c.paint(c.box((0.5, 5, 10), (5.3 * s, 4.4, 5)), wood))
        for z in (2.5, 7.5):
            parts.append(c.paint(c.box((0.6, 5.1, 0.4), (5.3 * s, 4.4, z)), iron))
    c.join(parts, "Gatehouse")


# ------------------------------------------------------------------ base props


def perch():
    """Stone column with a straw nest on top. 4 wide, 3 tall."""
    stone = castle_stone()
    gold = c.metal("Gold", color=(0.92, 0.72, 0.25), scratches=0.12)
    hay = c.straw("Nest", axis="X")
    parts = [
        c.paint(c.cylinder(2.0, 0.5, (0, 0, 0.25), verts=16), stone),
        c.paint(c.cylinder(1.4, 2.0, (0, 0, 1.5), verts=12, top_radius=1.2), stone),
        c.paint(c.cylinder(1.9, 0.35, (0, 0, 2.6), verts=16), gold),
        c.paint(c.torus(1.55, 0.45, (0, 0, 3.0), major_segments=20, minor_segments=8), hay),
        c.paint(c.cylinder(1.5, 0.3, (0, 0, 2.85), verts=16), hay),
    ]
    c.join(parts, "Perch")


def wild_nest():
    """A messy twig nest for the valley. 5 wide."""
    random.seed(4)
    twig = c.wood("Twig", light=(0.45, 0.32, 0.18), dark=(0.25, 0.16, 0.08), grain_axis="X")
    hay = c.straw("Hay", light=(0.75, 0.62, 0.35), dark=(0.45, 0.35, 0.16))
    parts = [c.paint(c.torus(2.0, 0.6, (0, 0, 0.5), major_segments=20), hay),
             c.paint(c.cylinder(2.0, 0.3, (0, 0, 0.15), verts=16), hay)]
    for i in range(14):
        a = R(i * 360 / 14 + random.uniform(-10, 10))
        parts.append(c.paint(c.cylinder(0.08, 2.6, (math.cos(a) * 2.1, math.sin(a) * 2.1, 0.75),
                                        rot=(R(random.uniform(-20, 20)), R(90), a + R(90)), verts=5), twig))
    c.join(parts, "WildNest")


def fusion_altar():
    """Fuse three dragons here. Base 10 wide; a floating crystal on top."""
    stone = c.stone("AltarStone", (0.35, 0.33, 0.42))
    rune = c.veins("Rune", base=(0.3, 0.28, 0.38), glow=(0.55, 0.9, 1.0), scale=2)
    gold = c.metal("AltarGold", color=(0.9, 0.7, 0.25), scratches=0.1)
    gem = c.crystal("AltarGem", bright=(0.85, 1.0, 1.0), deep=(0.15, 0.45, 0.9))
    parts = [
        c.paint(c.cylinder(5.0, 1.0, (0, 0, 0.5), verts=6), stone),
        c.paint(c.cylinder(4.2, 0.6, (0, 0, 1.3), verts=6), rune),
        c.paint(c.cylinder(1.2, 3.0, (0, 0, 3.1), verts=6, top_radius=0.8), stone),
        c.paint(c.torus(1.0, 0.15, (0, 0, 4.6), major_segments=16), gold),
    ]
    for i in range(3):
        a = R(i * 120 + 90)
        x, y = math.cos(a) * 3.3, math.sin(a) * 3.3
        parts.append(c.paint(c.cylinder(0.6, 1.6, (x, y, 2.4), verts=6), stone))
        parts.append(c.paint(c.sphere(0.35, (x, y, 3.35), segments=8, rings=6), gem))
    c.join(parts, "Base")
    crystal = c.paint(c.cylinder(0.9, 2.6, (0, 0, 6.6), verts=6, top_radius=0.0), gem)
    bottom = c.paint(c.cylinder(0.9, 1.2, (0, 0, 4.7), rot=(R(180), 0, 0), verts=6, top_radius=0.0), gem)
    c.join([crystal, bottom], "Crystal")


def treasure_chest():
    """Open chest overflowing with gold. 5 wide."""
    wood = c.planks("ChestWood", light=(0.55, 0.32, 0.15), dark=(0.28, 0.15, 0.06), plank_axis="X")
    iron = c.metal("ChestIron", color=(0.3, 0.3, 0.32))
    gold = c.metal("Coins", color=(1.0, 0.78, 0.2), scratches=0.08)
    parts = [
        c.paint(c.box((5, 3, 2.4), (0, 0, 1.2)), wood),
        c.paint(c.box((5.1, 3.1, 0.3), (0, 0, 0.3)), iron),
        c.paint(c.box((5.1, 3.1, 0.3), (0, 0, 2.2)), iron),
        c.paint(c.cylinder(1.5, 5, (0, 2.2, 3.6), rot=(R(-30), R(90), 0), verts=12), wood),
        c.paint(c.sphere(2.2, (0, 0, 2.3), scale=(1.05, 0.62, 0.38), segments=16, rings=10), gold),
    ]
    random.seed(2)
    for _ in range(14):
        parts.append(c.paint(c.cylinder(0.3, 0.08, (random.uniform(-2, 2), random.uniform(-1.6, -0.6), random.uniform(2.4, 3.1)),
                                        rot=(R(random.uniform(-40, 40)), R(random.uniform(-40, 40)), 0), verts=10), gold))
    for s in (1, -1):
        parts.append(c.paint(c.box((0.3, 3.2, 2.5), (2.2 * s, 0, 1.25)), iron))
    c.join(parts, "TreasureChest")


def lock_pad():
    """A round stone button with a glowing lock rune. 6 wide."""
    stone = castle_stone()
    rune = c.veins("LockRune", base=(0.25, 0.25, 0.3), glow=(1.0, 0.75, 0.2), scale=1.5)
    iron = c.metal("LockIron", color=(0.85, 0.65, 0.25))
    parts = [
        c.paint(c.cylinder(3.0, 0.5, (0, 0, 0.25), verts=20), stone),
        c.paint(c.cylinder(2.5, 0.3, (0, 0, 0.6), verts=20), rune),
        c.paint(c.box((1.2, 0.3, 1.0), (0, 0, 0.85)), iron),
        c.paint(c.torus(0.45, 0.14, (0, 0, 1.6), rot=(R(90), 0, 0), major_segments=14), iron),
    ]
    c.join(parts, "LockPad")


def shelter():
    """Rock arch to hide under when the dragon breathes. 16 wide, 10 tall, 10 deep."""
    rock = c.stone("ShelterRock", (0.48, 0.44, 0.4))
    moss = c.leaves("Moss", color=(0.25, 0.45, 0.18))
    parts = [
        c.paint(c.sphere(3.0, (-6, 0, 3.5), scale=(0.75, 1.5, 1.3), segments=10, rings=8), rock),
        c.paint(c.sphere(3.0, (6, 0, 3.5), scale=(0.75, 1.5, 1.3), segments=10, rings=8), rock),
        c.paint(c.sphere(4.0, (0, 0, 8.3), scale=(2.1, 1.25, 0.45), segments=14, rings=8), rock),
        c.paint(c.sphere(3.0, (0, 0, 9.6), scale=(2.3, 1.3, 0.2), segments=12, rings=6), moss),
    ]
    c.join(parts, "Shelter")


def zone_sign():
    """A wooden sign on two posts. Board 8 x 3."""
    wood = c.wood("SignWood", light=(0.55, 0.38, 0.2), dark=(0.3, 0.18, 0.08), grain_axis="X")
    post = c.wood("Post", grain_axis="Z")
    parts = [c.paint(c.box((0.4, 0.4, 6), (s * 3.4, 0, 3)), post) for s in (1, -1)]
    c.join(parts, "SignPosts")
    c.join([c.paint(c.box((8, 0.4, 3), (0, -0.2, 4.6)), wood)], "Board")


def tablet():
    """Stone tablet for the leaderboard. 14 wide, 16 tall."""
    stone = c.stone("TabletStone", (0.42, 0.4, 0.46))
    gold = c.metal("TabletGold", color=(0.9, 0.7, 0.25))
    parts = [
        c.paint(c.box((16, 4, 1.5), (0, 0, 0.75)), stone),
        c.paint(c.box((14, 1.4, 14), (0, 0.6, 8.5)), stone),
        c.paint(c.cylinder(7, 1.4, (0, 0.6, 15.5), rot=(R(90), 0, 0), verts=24), stone),
        c.paint(c.box((14.4, 1.0, 0.5), (0, 0.4, 1.7)), gold),
    ]
    c.join(parts, "Tablet")


def club():
    """The bonk club, 4.5 long, along +Z (handle at the bottom)."""
    wood = c.wood("ClubWood", light=(0.6, 0.42, 0.24), dark=(0.32, 0.2, 0.1), grain_axis="Z")
    wrap = c.cloth("Wrap", color=(0.55, 0.15, 0.12), weave=90)
    iron = c.metal("Studs", color=(0.5, 0.5, 0.52))
    parts = [
        c.paint(c.cylinder(0.22, 4.5, (0, 0, 2.25), verts=10, top_radius=0.5), wood),
        c.paint(c.sphere(0.62, (0, 0, 4.2), scale=(1, 1, 1.3), segments=12, rings=8), wood),
        c.paint(c.cylinder(0.26, 1.3, (0, 0, 0.8), verts=10), wrap),
    ]
    for i in range(6):
        a = R(i * 60)
        parts.append(c.paint(c.cylinder(0.1, 0.35, (math.cos(a) * 0.62, math.sin(a) * 0.62, 4.2), rot=(0, R(90), a), verts=6, top_radius=0), iron))
    c.join(parts, "Handle")


# ------------------------------------------------------------------ nature


def pine_tree():
    bark = c.bark("PineBark")
    needles = c.leaves("Needles", color=(0.12, 0.32, 0.16))
    parts = [c.paint(c.cylinder(0.6, 5, (0, 0, 2.5), verts=8, top_radius=0.4), bark)]
    for i, (r, z) in enumerate(((4.0, 5.0), (3.2, 8.0), (2.3, 10.8), (1.4, 13.2))):
        parts.append(c.paint(c.cylinder(r, 4.0 - i * 0.4, (0, 0, z), verts=10, top_radius=0.2), needles))
    c.join(parts, "PineTree")


def oak_tree():
    bark = c.bark("OakBark")
    leaf = c.leaves("OakLeaves", color=(0.3, 0.55, 0.18))
    parts = [c.paint(c.cylinder(0.9, 6, (0, 0, 3), verts=8, top_radius=0.6), bark)]
    for x, y, z, r in ((0, 0, 8, 3.6), (2.2, 0.5, 7, 2.5), (-2.2, -0.4, 7.2, 2.6), (0.4, 2, 7.4, 2.4), (-0.3, -2, 7.6, 2.3)):
        parts.append(c.paint(c.sphere(r, (x, y, z), segments=10, rings=8), leaf))
    c.join(parts, "OakTree")


def boulder():
    rock = c.stone("Boulder", (0.5, 0.48, 0.45))
    b = c.sphere(2.5, (0, 0, 1.6), scale=(1.2, 1.0, 0.75), segments=9, rings=7)
    random.seed(7)
    for v in b.data.vertices:
        v.co *= random.uniform(0.85, 1.12)
    c.join([c.paint(b, rock)], "Boulder")


def lava_rock():
    rock = c.veins("LavaRock", base=(0.1, 0.08, 0.08), glow=(1.0, 0.4, 0.05), scale=2.5)
    random.seed(11)
    parts = []
    for x, y, z, r in ((0, 0, 1.4, 2.0), (1.6, 0.6, 0.8, 1.2), (-1.4, -0.4, 0.9, 1.3)):
        s = c.sphere(r, (x, y, z), scale=(1.1, 1, 0.8), segments=8, rings=6)
        for v in s.data.vertices:
            v.co *= random.uniform(0.85, 1.15)
        parts.append(c.paint(s, rock))
    c.join(parts, "LavaRock")


def ice_spire():
    ice = c.crystal("IceSpire", bright=(0.95, 1.0, 1.0), deep=(0.4, 0.7, 0.95))
    parts = []
    for x, y, h, tilt in ((0, 0, 9, 0), (1.5, 0.5, 5.5, 15), (-1.4, 0.3, 6, -12), (0.3, -1.4, 4.5, 8)):
        parts.append(c.paint(c.cylinder(1.0 if h > 8 else 0.7, h, (x, y, h / 2 - 0.3), rot=(R(tilt * 0.5), R(tilt), 0), verts=6, top_radius=0), ice))
    c.join(parts, "IceSpire")


def void_crystal():
    gem = c.crystal("VoidCrystal", bright=(0.95, 0.7, 1.0), deep=(0.3, 0.02, 0.5))
    rock = c.stone("VoidRock", (0.15, 0.12, 0.2))
    parts = [c.paint(c.sphere(2.2, (0, 0, 0.5), scale=(1.2, 1.1, 0.5), segments=10, rings=6), rock)]
    for x, y, h, tx, ty in ((0, 0, 7, 0, 0), (1.3, 0.4, 4.5, 0, 25), (-1.2, 0.5, 5, 0, -22), (0.2, -1.2, 4, -25, 0), (0.3, 1.2, 3.5, 25, 5)):
        parts.append(c.paint(c.cylinder(0.75, h, (x, y, h / 2 + 0.5), rot=(R(tx), R(ty), 0), verts=6, top_radius=0.05), gem))
    c.join(parts, "VoidCrystal")


def flower_bush():
    leaf = c.leaves("BushLeaves", color=(0.28, 0.55, 0.2))
    petals = [c.solid("Pink", (1.0, 0.5, 0.7), 0.6), c.solid("Yellow", (1.0, 0.88, 0.25), 0.6), c.solid("White", (0.97, 0.97, 0.95), 0.6)]
    random.seed(5)
    parts = [c.paint(c.sphere(1.6, (0, 0, 1.0), scale=(1.2, 1.1, 0.75), segments=12, rings=8), leaf)]
    for i in range(10):
        a = random.uniform(0, math.tau)
        r = random.uniform(0.6, 1.6)
        parts.append(c.paint(c.sphere(0.22, (math.cos(a) * r, math.sin(a) * r, 1.0 + math.sqrt(max(0.0, 1 - (r / 1.95) ** 2)) * 1.2 + 0.05), segments=6, rings=4), petals[i % 3]))
    c.join(parts, "FlowerBush")


def mushroom():
    stem = c.solid("Stem", (0.92, 0.88, 0.78), 0.8)
    cap = c.speckled("Cap", base=(0.8, 0.15, 0.12), spot=(1.0, 0.97, 0.9), scale=5, amount=0.62)
    parts = [c.paint(c.cylinder(0.5, 2.2, (0, 0, 1.1), verts=10, top_radius=0.4), stem),
             c.paint(c.sphere(1.5, (0, 0, 2.3), scale=(1, 1, 0.6), segments=14, rings=8), cap)]
    c.join(parts, "Mushroom")


PROPS = {
    "CastleWall": castle_wall, "CastleTower": castle_tower, "Gatehouse": gatehouse,
    "Perch": perch, "WildNest": wild_nest, "FusionAltar": fusion_altar, "TreasureChest": treasure_chest,
    "LockPad": lock_pad, "Shelter": shelter, "ZoneSign": zone_sign, "Tablet": tablet, "Club": club,
    "PineTree": pine_tree, "OakTree": oak_tree, "Boulder": boulder, "LavaRock": lava_rock,
    "IceSpire": ice_spire, "VoidCrystal": void_crystal, "FlowerBush": flower_bush, "Mushroom": mushroom,
}

PREVIEW = {
    "CastleWall": dict(camera=(14, -20, 12), target=(0, 0, 6)),
    "CastleTower": dict(camera=(18, -24, 16), target=(0, 0, 11)),
    "Gatehouse": dict(camera=(16, -24, 12), target=(0, 0, 7)),
    "FusionAltar": dict(camera=(9, -12, 8), target=(0, 0, 3)),
    "Shelter": dict(camera=(14, -20, 10), target=(0, 0, 4)),
    "Tablet": dict(camera=(14, -20, 10), target=(0, 0, 8)),
    "PineTree": dict(camera=(14, -20, 10), target=(0, 0, 7)),
    "OakTree": dict(camera=(14, -20, 10), target=(0, 0, 6)),
    "IceSpire": dict(camera=(10, -14, 7), target=(0, 0, 4)),
    "VoidCrystal": dict(camera=(9, -12, 6), target=(0, 0, 3)),
}


if __name__ == "__main__":
    out = c.out_dir()
    wanted = sys.argv[2:]
    for name, make in PROPS.items():
        if wanted and name not in wanted:
            continue
        c.reset()
        make()
        c.bake_and_export(name, out, texture_size=1024 if name.startswith("Castle") or name in ("Gatehouse", "Shelter") else 512,
                          preview=PREVIEW.get(name, dict(camera=(6, -8, 5), target=(0, 0, 1.5))))
