"""Shared helpers for the Blender model scripts.

Every model is made of simple shapes with procedural materials (wood grain,
straw, fur, cloth...). bake_and_export() unwraps all parts into one shared
texture, bakes the materials' colors into it, and writes:
    <out>/<Name>.fbx   the mesh(es), with UVs
    <out>/<Name>.png   the texture (our own, no Roblox materials)
    <out>/<Name>_preview.png   a render to check how it looks
"""

import math
import os
import sys

import bpy

# ---------------------------------------------------------------- scene


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16


def out_dir(default_name="out"):
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), default_name)
    os.makedirs(path, exist_ok=True)
    return path


# ---------------------------------------------------------------- shapes


def _active():
    return bpy.context.active_object


def sphere(radius, loc, scale=(1, 1, 1), segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=loc)
    obj = _active()
    obj.scale = scale
    return obj


def cylinder(radius, depth, loc, rot=(0, 0, 0), verts=12, top_radius=None):
    if top_radius is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=top_radius, depth=depth, location=loc, rotation=rot)
    return _active()


def box(size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    obj = _active()
    obj.scale = size
    return obj


def torus(major, minor, loc, rot=(0, 0, 0), major_segments=24, minor_segments=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=major_segments, minor_segments=minor_segments)
    return _active()


def curve_tube(points, bevel, name="Curve"):
    """A tapering tube along a curve. points = [((x, y, z), radius), ...]"""
    curve = bpy.data.curves.new(name, type="CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = bevel
    curve.bevel_resolution = 2
    curve.resolution_u = 8
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, (co, radius) in zip(spline.bezier_points, points):
        bp.co = co
        bp.radius = radius
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return _active()


def paint(obj, mat):
    """Gives a shape a material (before joining)."""
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def join(objs, name):
    """Joins shapes into one part. Each keeps its own material."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = _active()
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_flat()
    return obj


# ---------------------------------------------------------------- materials
# Each returns a material whose Base Color is procedural. Colors are RGB 0-1.


def _new_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat, nodes, mat.node_tree.links, bsdf


def _coords(nodes, links, scale=(1, 1, 1)):
    tex = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = scale
    links.new(tex.outputs["Object"], mapping.inputs["Vector"])
    return mapping.outputs["Vector"]


def _ramp(nodes, links, fac, stops):
    ramp = nodes.new("ShaderNodeValToRGB")
    elements = ramp.color_ramp.elements
    elements[0].position, elements[0].color = stops[0][0], (*stops[0][1], 1)
    elements[1].position, elements[1].color = stops[-1][0], (*stops[-1][1], 1)
    for pos, color in stops[1:-1]:
        e = elements.new(pos)
        e.color = (*color, 1)
    links.new(fac, ramp.inputs["Fac"])
    return ramp.outputs["Color"]


def _noise(nodes, links, vector, scale, detail=4, roughness=0.6, distortion=0.0):
    n = nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = roughness
    n.inputs["Distortion"].default_value = distortion
    links.new(vector, n.inputs["Vector"])
    return n.outputs["Fac"]


def _mix(nodes, links, a, b, fac_value=0.5, fac_socket=None, blend="MIX"):
    m = nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = blend
    m.inputs[0].default_value = fac_value
    if fac_socket is not None:
        links.new(fac_socket, m.inputs[0])
    links.new(a, m.inputs[6])
    links.new(b, m.inputs[7])
    return m.outputs[2]


def wood(name, light=(0.55, 0.36, 0.2), dark=(0.3, 0.18, 0.09), grain_axis="Z", scale=4.0):
    """Wood grain running along grain_axis."""
    mat, nodes, links, bsdf = _new_material(name)
    stretch = {"X": (0.15, 1, 1), "Y": (1, 0.15, 1), "Z": (1, 1, 0.15)}[grain_axis]
    vec = _coords(nodes, links, stretch)
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "RINGS"
    wave.inputs["Scale"].default_value = scale
    wave.inputs["Distortion"].default_value = 6
    wave.inputs["Detail"].default_value = 3
    links.new(vec, wave.inputs["Vector"])
    grain = _ramp(nodes, links, wave.outputs["Fac"], [(0.0, dark), (0.55, light), (1.0, light)])
    speck = _noise(nodes, links, _coords(nodes, links, (1, 1, 1)), 40, detail=2)
    color = _mix(nodes, links, grain, _ramp(nodes, links, speck, [(0.3, dark), (0.7, light)]), 0.2)
    links.new(color, bsdf.inputs["Base Color"])
    return mat


def planks(name, light=(0.5, 0.33, 0.18), dark=(0.25, 0.15, 0.07), plank_axis="X", planks_per_unit=2.0):
    """Wooden boards with dark gaps between them."""
    mat, nodes, links, bsdf = _new_material(name)
    vec = _coords(nodes, links)
    # Measure across the boards along a slanted direction, so no face of a
    # box sees a constant value (which would make it all gap or all board).
    across = nodes.new("ShaderNodeVectorMath")
    across.operation = "DOT_PRODUCT"
    across.inputs[1].default_value = {"X": (0, 1, 1), "Y": (1, 0, 1), "Z": (1, 1, 0)}[plank_axis]
    links.new(vec, across.inputs[0])
    mult = nodes.new("ShaderNodeMath")
    mult.operation = "MULTIPLY"
    mult.inputs[1].default_value = planks_per_unit
    links.new(across.outputs["Value"], mult.inputs[0])
    frac = nodes.new("ShaderNodeMath")
    frac.operation = "FRACT"
    links.new(mult.outputs[0], frac.inputs[0])
    gaps = _ramp(nodes, links, frac.outputs[0], [(0.0, (0, 0, 0)), (0.05, (1, 1, 1)), (0.95, (1, 1, 1)), (1.0, (0, 0, 0))])
    grain_vec = _coords(nodes, links, {"X": (0.1, 2, 2), "Y": (2, 0.1, 2), "Z": (2, 2, 0.1)}[plank_axis])
    grain = _ramp(nodes, links, _noise(nodes, links, grain_vec, 6, distortion=2), [(0.3, dark), (0.65, light)])
    color = _mix(nodes, links, grain, gaps, 1.0, blend="MULTIPLY")
    links.new(color, bsdf.inputs["Base Color"])
    return mat


def straw(name, light=(0.86, 0.72, 0.38), dark=(0.55, 0.42, 0.17), axis="Z"):
    """Stalks of straw/hay running along axis."""
    mat, nodes, links, bsdf = _new_material(name)
    stretch = {"X": (1, 30, 30), "Y": (30, 1, 30), "Z": (30, 30, 1)}[axis]
    stalks = _noise(nodes, links, _coords(nodes, links, stretch), 3, detail=6, roughness=0.7)
    color = _ramp(nodes, links, stalks, [(0.35, dark), (0.5, light), (0.62, (1.0, 0.9, 0.6))])
    links.new(color, bsdf.inputs["Base Color"])
    return mat


def cloth(name, color=(0.5, 0.4, 0.3), weave=60.0, variation=0.25):
    """Woven fabric: a fine crosshatch with some blotchy variation."""
    mat, nodes, links, bsdf = _new_material(name)
    vec = _coords(nodes, links)
    wx = nodes.new("ShaderNodeTexWave")
    wx.wave_type = "BANDS"
    wx.bands_direction = "X"
    wx.inputs["Scale"].default_value = weave
    links.new(vec, wx.inputs["Vector"])
    wy = nodes.new("ShaderNodeTexWave")
    wy.wave_type = "BANDS"
    wy.bands_direction = "Z"
    wy.inputs["Scale"].default_value = weave
    links.new(vec, wy.inputs["Vector"])
    both = nodes.new("ShaderNodeMath")
    both.operation = "MULTIPLY"
    links.new(wx.outputs["Fac"], both.inputs[0])
    links.new(wy.outputs["Fac"], both.inputs[1])
    dark = tuple(c * 0.7 for c in color)
    light = tuple(min(1, c * 1.15) for c in color)
    weave_color = _ramp(nodes, links, both.outputs[0], [(0.0, dark), (1.0, light)])
    blotch = _ramp(nodes, links, _noise(nodes, links, vec, 3), [(0.3, tuple(c * (1 - variation) for c in color)), (0.7, light)])
    links.new(_mix(nodes, links, weave_color, blotch, 0.5), bsdf.inputs["Base Color"])
    return mat


def fur(name, color=(0.3, 0.25, 0.22), streak_axis="Y"):
    """Short fur: fine streaks with darker and lighter patches."""
    mat, nodes, links, bsdf = _new_material(name)
    stretch = {"X": (1, 12, 12), "Y": (12, 1, 12), "Z": (12, 12, 1)}[streak_axis]
    streaks = _noise(nodes, links, _coords(nodes, links, stretch), 6, detail=8, roughness=0.75)
    patches = _noise(nodes, links, _coords(nodes, links), 2.5)
    dark = tuple(c * 0.6 for c in color)
    light = tuple(min(1, c * 1.35) for c in color)
    a = _ramp(nodes, links, streaks, [(0.35, dark), (0.5, color), (0.65, light)])
    b = _ramp(nodes, links, patches, [(0.35, dark), (0.65, light)])
    links.new(_mix(nodes, links, a, b, 0.35), bsdf.inputs["Base Color"])
    return mat


def skin(name, color=(0.86, 0.6, 0.48), blotch=0.12):
    """Skin or smooth leather: soft, slightly uneven."""
    mat, nodes, links, bsdf = _new_material(name)
    n = _noise(nodes, links, _coords(nodes, links), 5, detail=3)
    color_out = _ramp(nodes, links, n, [(0.3, tuple(c * (1 - blotch) for c in color)), (0.7, tuple(min(1, c * (1 + blotch)) for c in color))])
    links.new(color_out, bsdf.inputs["Base Color"])
    return mat


def metal(name, color=(0.55, 0.56, 0.58), scratches=0.25):
    """Worn metal with streaky scratches."""
    mat, nodes, links, bsdf = _new_material(name)
    streaks = _noise(nodes, links, _coords(nodes, links, (1, 1, 25)), 4, detail=6)
    dark = tuple(c * (1 - scratches * 1.5) for c in color)
    light = tuple(min(1, c * (1 + scratches)) for c in color)
    links.new(_ramp(nodes, links, streaks, [(0.3, dark), (0.5, color), (0.7, light)]), bsdf.inputs["Base Color"])
    return mat


def dirt(name, color=(0.42, 0.33, 0.22), pebbles=True):
    """Packed earth with pebbles and darker patches."""
    mat, nodes, links, bsdf = _new_material(name)
    vec = _coords(nodes, links)
    base = _ramp(nodes, links, _noise(nodes, links, vec, 6, detail=8, roughness=0.65),
                 [(0.3, tuple(c * 0.7 for c in color)), (0.5, color), (0.7, tuple(min(1, c * 1.2) for c in color))])
    if pebbles:
        vor = nodes.new("ShaderNodeTexVoronoi")
        vor.inputs["Scale"].default_value = 25
        links.new(vec, vor.inputs["Vector"])
        stones = _ramp(nodes, links, vor.outputs["Distance"], [(0.0, (0.62, 0.58, 0.52)), (0.18, (0.62, 0.58, 0.52)), (0.22, (1, 1, 1)), (1.0, (1, 1, 1))])
        mask = _ramp(nodes, links, _noise(nodes, links, vec, 4), [(0.55, (0, 0, 0)), (0.6, (1, 1, 1))])
        pebbled = _mix(nodes, links, base, stones, 1.0, blend="MULTIPLY")
        base = _mix(nodes, links, base, pebbled, fac_socket=mask)
    links.new(base, bsdf.inputs["Base Color"])
    return mat


def stone(name, color=(0.5, 0.5, 0.5)):
    mat, nodes, links, bsdf = _new_material(name)
    vec = _coords(nodes, links)
    n = _noise(nodes, links, vec, 8, detail=6)
    links.new(_ramp(nodes, links, n, [(0.3, tuple(c * 0.65 for c in color)), (0.7, tuple(min(1, c * 1.2) for c in color))]), bsdf.inputs["Base Color"])
    return mat


def stripes(name, a=(0.6, 0.15, 0.12), b=(0.85, 0.75, 0.6), axis="Z", count=8.0):
    """Painted stripes (rope twists, tent canvas)."""
    mat, nodes, links, bsdf = _new_material(name)
    vec = _coords(nodes, links)
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "DIAGONAL" if axis == "DIAG" else axis
    wave.inputs["Scale"].default_value = count
    wave.inputs["Distortion"].default_value = 1
    links.new(vec, wave.inputs["Vector"])
    links.new(_ramp(nodes, links, wave.outputs["Fac"], [(0.45, a), (0.55, b)]), bsdf.inputs["Base Color"])
    return mat


def bark(name, color=(0.32, 0.22, 0.14)):
    """Tree bark: deep vertical furrows."""
    mat, nodes, links, bsdf = _new_material(name)
    furrows = _noise(nodes, links, _coords(nodes, links, (6, 6, 0.6)), 3, detail=6, roughness=0.7, distortion=1.5)
    dark = tuple(c * 0.45 for c in color)
    light = tuple(min(1, c * 1.3) for c in color)
    links.new(_ramp(nodes, links, furrows, [(0.35, dark), (0.5, color), (0.65, light)]), bsdf.inputs["Base Color"])
    return mat


def leaves(name, color=(0.22, 0.42, 0.14)):
    """A leafy canopy: clumps of light and dark green."""
    mat, nodes, links, bsdf = _new_material(name)
    vec = _coords(nodes, links)
    vor = nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 6
    links.new(vec, vor.inputs["Vector"])
    clumps = _ramp(nodes, links, vor.outputs["Distance"], [(0.0, tuple(min(1, c * 1.35) for c in color)), (0.5, color), (0.9, tuple(c * 0.5 for c in color))])
    speck = _ramp(nodes, links, _noise(nodes, links, vec, 25, detail=3), [(0.3, tuple(c * 0.7 for c in color)), (0.7, tuple(min(1, c * 1.2) for c in color))])
    links.new(_mix(nodes, links, clumps, speck, 0.35), bsdf.inputs["Base Color"])
    return mat


def crystal(name, bright=(1.0, 0.85, 0.35), deep=(0.85, 0.22, 0.04), mid=None):
    """A glowing gem: bright core fading to deep color, with facet sparkle."""
    mat, nodes, links, bsdf = _new_material(name)
    tex = nodes.new("ShaderNodeTexCoord")
    grad = nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    links.new(tex.outputs["Object"], grad.inputs["Vector"])
    mid = mid or tuple((a + b) / 2 for a, b in zip(bright, deep))
    core = _ramp(nodes, links, grad.outputs["Fac"], [(0.0, deep), (0.6, mid), (1.0, bright)])
    vor = nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 4
    links.new(tex.outputs["Object"], vor.inputs["Vector"])
    sparkle = _ramp(nodes, links, vor.outputs["Distance"], [(0.0, (1, 1, 0.9)), (0.12, (1, 1, 1)), (0.2, (0.75, 0.75, 0.75)), (1.0, (0.75, 0.75, 0.75))])
    links.new(_mix(nodes, links, core, sparkle, 1.0, blend="MULTIPLY"), bsdf.inputs["Base Color"])
    return mat


def solid(name, color, roughness=0.5):
    mat, nodes, links, bsdf = _new_material(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


# ---------------------------------------------------------------- baking


def bake_and_export(name, out, texture_size=1024, preview=None):
    """Unwraps every mesh into one texture, bakes colors, exports FBX + PNG."""
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]

    # One shared UV layout for all parts.
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

    image = bpy.data.images.new(name + "_tex", texture_size, texture_size)
    for o in meshes:
        for mat in o.data.materials:
            node = mat.node_tree.nodes.new("ShaderNodeTexImage")
            node.image = image
            mat.node_tree.nodes.active = node

    scene = bpy.context.scene
    scene.cycles.samples = 4
    scene.render.bake.margin = 8
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_clear=True, margin=8)

    png = os.path.join(out, name + ".png")
    image.filepath_raw = png
    image.file_format = "PNG"
    image.save()

    # Swap to one plain material that shows the baked texture.
    baked = bpy.data.materials.new(name + "_baked")
    baked.use_nodes = True
    bsdf = baked.node_tree.nodes.get("Principled BSDF")
    tex = baked.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    baked.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    for o in meshes:
        o.data.materials.clear()
        o.data.materials.append(baked)

    fbx = os.path.join(out, name + ".fbx")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
    )

    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    print(f"{name}: {len(meshes)} parts, {tris} triangles -> {fbx}")
    if preview:
        render_preview(name, out, **preview)
    return fbx, png


def render_preview(name, out, camera=(6, -8, 4), target=(0, 0, 1.5), size=(640, 480)):
    scene = bpy.context.scene
    scene.cycles.samples = 24
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = os.path.join(out, name + "_preview.png")
    scene.view_settings.view_transform = "Standard"

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.7, 0.85, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world

    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    ground = _active()
    ground.data.materials.append(solid("PreviewGround", (0.25, 0.42, 0.2), 1))

    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(10), math.radians(30)))
    _active().data.energy = 2.6

    bpy.ops.object.camera_add(location=camera)
    cam = _active()
    direction = [t - c for t, c in zip(target, camera)]
    import mathutils
    cam.rotation_euler = mathutils.Vector(direction).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- Dragon Egg Heist additions


def mesh_from(verts, faces, name="Mesh", thickness=0.0):
    """A mesh from raw vertices/faces, optionally given thickness (solidify)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if thickness > 0:
        mod = obj.modifiers.new("Solid", "SOLIDIFY")
        mod.thickness = thickness
        mod.offset = 0
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def egg_shape(radius, loc, height=1.5, taper=0.32, segments=20, rings=14):
    """An egg: a sphere stretched up and narrowed toward the top."""
    obj = sphere(radius, (0, 0, 0), segments=segments, rings=rings)
    for v in obj.data.vertices:
        z = v.co.z / radius
        v.co.z *= height
        k = 1 - taper * max(0.0, z)
        v.co.x *= k
        v.co.y *= k
    obj.location = (loc[0], loc[1], loc[2] + radius * height)
    return obj


def bend_up(obj, amount):
    """Curves an object's far ends up (for wings and tails)."""
    for v in obj.data.vertices:
        v.co.z += amount * (v.co.x ** 2)
    return obj


def scales(name, color=(0.3, 0.6, 0.25), dark=None, light=None, size=14.0):
    """Dragon scales: a cell pattern with darker edges."""
    mat, nodes, links, bsdf = _new_material(name)
    dark = dark or tuple(c * 0.55 for c in color)
    light = light or tuple(min(1, c * 1.25) for c in color)
    vec = _coords(nodes, links)
    vor = nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = size
    links.new(vec, vor.inputs["Vector"])
    edge = _ramp(nodes, links, vor.outputs["Distance"], [(0.0, dark), (0.08, color), (0.3, light)])
    tint = _ramp(nodes, links, _noise(nodes, links, vec, 2.5), [(0.3, tuple(c * 0.85 for c in color)), (0.7, light)])
    links.new(_mix(nodes, links, edge, tint, 0.3), bsdf.inputs["Base Color"])
    return mat


def speckled(name, base=(0.9, 0.85, 0.7), spot=(0.45, 0.3, 0.15), scale=18.0, amount=0.62):
    """Egg shell with spots."""
    mat, nodes, links, bsdf = _new_material(name)
    vec = _coords(nodes, links)
    n = _noise(nodes, links, vec, scale, detail=3)
    spots = _ramp(nodes, links, n, [(amount - 0.02, base), (amount, spot), (1.0, spot)])
    shade = _ramp(nodes, links, _noise(nodes, links, vec, 3), [(0.3, tuple(c * 0.9 for c in base)), (0.7, base)])
    links.new(_mix(nodes, links, spots, shade, 0.25), bsdf.inputs["Base Color"])
    return mat


def banded(name, a, b, count=6.0, wobble=3.0, axis="Z"):
    """Wavy horizontal bands (eggs, banners)."""
    mat, nodes, links, bsdf = _new_material(name)
    vec = _coords(nodes, links)
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = axis
    wave.inputs["Scale"].default_value = count
    wave.inputs["Distortion"].default_value = wobble
    wave.inputs["Detail"].default_value = 1
    links.new(vec, wave.inputs["Vector"])
    links.new(_ramp(nodes, links, wave.outputs["Fac"], [(0.4, a), (0.6, b)]), bsdf.inputs["Base Color"])
    return mat


def veins(name, base=(0.08, 0.05, 0.12), glow=(0.75, 0.3, 1.0), scale=5.0):
    """Dark surface with glowing cracks."""
    mat, nodes, links, bsdf = _new_material(name)
    vec = _coords(nodes, links)
    vor = nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = scale
    links.new(vec, vor.inputs["Vector"])
    cracks = _ramp(nodes, links, vor.outputs["Distance"], [(0.0, glow), (0.012, glow), (0.035, base), (1.0, base)])
    links.new(cracks, bsdf.inputs["Base Color"])
    return mat


def starry(name, sky=(0.05, 0.07, 0.22), star=(1.0, 0.95, 0.75), nebula=(0.35, 0.15, 0.55), scale=30.0):
    """Night sky: deep blue, purple clouds, little stars."""
    mat, nodes, links, bsdf = _new_material(name)
    vec = _coords(nodes, links)
    clouds = _ramp(nodes, links, _noise(nodes, links, vec, 2.5, detail=6), [(0.35, sky), (0.75, nebula)])
    vor = nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = scale
    vor.inputs["Randomness"].default_value = 1
    links.new(vec, vor.inputs["Vector"])
    dots = _ramp(nodes, links, vor.outputs["Distance"], [(0.0, star), (0.06, star), (0.1, (0, 0, 0)), (1.0, (0, 0, 0))])
    links.new(_mix(nodes, links, clouds, dots, 1.0, blend="ADD"), bsdf.inputs["Base Color"])
    return mat


def gradient(name, bottom, top, axis="Z", lo=-1.0, hi=1.0):
    """A smooth fade from bottom to top along an axis (object space)."""
    mat, nodes, links, bsdf = _new_material(name)
    tex = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(tex.outputs["Object"], sep.inputs["Vector"])
    m = nodes.new("ShaderNodeMapRange")
    m.inputs["From Min"].default_value = lo
    m.inputs["From Max"].default_value = hi
    links.new(sep.outputs[axis], m.inputs["Value"])
    links.new(_ramp(nodes, links, m.outputs["Result"], [(0.0, bottom), (1.0, top)]), bsdf.inputs["Base Color"])
    return mat
