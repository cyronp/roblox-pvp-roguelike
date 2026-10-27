"""Build the long-barrel revolver model, a studio render, and Roblox-oriented exports."""

from pathlib import Path
import json
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

PROJECT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT / "assets" / "revolver"

# Profiles are drawn in side view in studs: u points toward the muzzle, v points up, and the
# origin is the middle of the grip. Blender maps u to -Y and v to Z, so the barrel faces -Y and
# the FBX export (forward Z, up Y) turns it into Roblox's -Z look direction.
SIDE = Matrix(((0, 0, -1, 0), (-1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
S = True  # Marks a sharp profile corner; other points get smooth automatic handles.

BORE_V = 0.50
MUZZLE_U = 1.98
CYLINDER_V = 0.40
CYLINDER_RADIUS = 0.17
CYLINDER_START, CYLINDER_END = 0.265, 0.635


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def world(u, v, x=0.0):
    return Vector((x, -u, v))


def material(name, color, metallic, roughness, coat=0.0):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    linear = [((c / 255 + 0.055) / 1.055) ** 2.4 for c in bytes.fromhex(color.lstrip("#"))] + [1]
    result.diffuse_color = linear
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = linear
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Coat Weight"].default_value = coat
    shader.inputs["Coat Roughness"].default_value = 0.2
    return result


def profile(name, outlines, width, bevel, mat, x=0.0, resolution=6):
    """Extrude closed side-view outlines; outlines inside the first one become holes."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "2D"
    curve.fill_mode = "BOTH"
    curve.resolution_u = resolution
    curve.bevel_depth = bevel
    curve.bevel_resolution = 3
    # Keep the drawn outline and width exact: the bevel would otherwise grow the shape outward.
    curve.offset = -bevel
    curve.extrude = max(0.0, width / 2 - bevel)
    for outline in outlines:
        spline = curve.splines.new("BEZIER")
        spline.bezier_points.add(len(outline) - 1)
        spline.use_cyclic_u = True
        spline.use_smooth = True
        for point, (u, v, *sharp) in zip(spline.bezier_points, outline):
            point.co = (u, v, 0)
            point.handle_left_type = point.handle_right_type = "VECTOR" if sharp else "AUTO"
    curve.materials.append(mat)
    obj = bpy.data.objects.new(name, curve)
    PARTS.objects.link(obj)
    obj.matrix_world = Matrix.Translation((x, 0, 0)) @ SIDE
    return obj


def circle(cu, cv, radius, count=12):
    return [(cu + radius * math.cos(i * math.tau / count), cv + radius * math.sin(i * math.tau / count)) for i in range(count)]


def rounded_rect(u0, u1, v0, v1, radius, steps=3):
    points = []
    for cu, cv, start in ((u1 - radius, v1 - radius, 0), (u0 + radius, v1 - radius, 90),
                          (u0 + radius, v0 + radius, 180), (u1 - radius, v0 + radius, 270)):
        for step in range(steps + 1):
            angle = math.radians(start + step * 90 / steps)
            points.append((cu + radius * math.cos(angle), cv + radius * math.sin(angle), S))
    return points


def mesh_part(name, build, matrix, mat=None, destination=None):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    for face in bm.faces:
        face.smooth = True
    bm.to_mesh(mesh)
    bm.free()
    if mat:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    (destination or PARTS).objects.link(obj)
    obj.matrix_world = matrix
    return obj


def tube(name, radius, start, end, v, mat=None, x=0.0, sides=32, destination=None):
    """Cylinder whose axis runs along the gun; local +Z points toward the muzzle."""
    matrix = Matrix.Translation(world((start + end) / 2, v, x)) @ Matrix.Rotation(math.pi / 2, 4, "X")
    return mesh_part(name, lambda bm: bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius, radius2=radius, depth=end - start),
        matrix, mat, destination)


def stud(name, radius, depth, u, v, x, mat, sides=16):
    """Short disc facing sideways, for screw heads and the grip medallion."""
    matrix = Matrix.Translation(world(u, v, x)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    obj = mesh_part(name, lambda bm: bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius, radius2=radius * 0.8, depth=depth),
        matrix, mat)
    if x < 0:
        obj.matrix_world = obj.matrix_world @ Matrix.Rotation(math.pi, 4, "X")
    return obj


def ellipsoid(name, center, axes, radii):
    basis = Matrix([axis * radius for axis, radius in zip(axes, radii)]).transposed().to_4x4()
    return mesh_part(name, lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=10, radius=1),
                     Matrix.Translation(center) @ basis, destination=CUTTERS)


def bevel(obj, width, segments=2, angle=40):
    modifier = obj.modifiers.new("Machined edges", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(angle)
    modifier.harden_normals = True
    return modifier


def subtract(obj, cutters, name):
    group = collection(name)
    bpy.context.scene.collection.children.unlink(group)
    CUTTERS.children.link(group)
    for cutter in cutters:
        CUTTERS.objects.unlink(cutter)
        group.objects.link(cutter)
    modifier = obj.modifiers.new(name, "BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.operand_type = "COLLECTION"
    modifier.collection = group
    modifier.solver = "EXACT"


def build_parts():
    # Barrel, its muzzle crown, and the breech collar that seats into the frame.
    barrel = tube("Barrel", 0.125, 0.70, MUZZLE_U, BORE_V, STEEL)
    bevel(barrel, 0.012)
    subtract(barrel, [tube("Cut_Bore", 0.048, MUZZLE_U - 0.25, MUZZLE_U + 0.05, BORE_V, destination=CUTTERS)], "Cut_Barrel")
    bevel(tube("Barrel_Collar", 0.145, 0.655, 0.765, BORE_V, STEEL), 0.015)

    profile("Barrel_Rib", [[(0.66, 0.58, S), (MUZZLE_U, 0.58, S), (MUZZLE_U, 0.652, S), (0.66, 0.652, S)]],
            0.085, 0.012, STEEL)
    profile("Front_Sight", [[(1.80, 0.64, S), (1.885, 0.725), (1.935, 0.738, S), (1.95, 0.64, S)]],
            0.04, 0.008, STEEL)
    profile("Ejector_Shroud", [[(0.68, 0.50, S), (1.16, 0.50, S), (1.13, 0.40), (1.05, 0.325), (0.90, 0.295),
                                (0.71, 0.295, S), (0.68, 0.34, S)]], 0.15, 0.03, STEEL)

    # Frame with an open window for the cylinder; the lower rear disappears inside the grip.
    profile("Frame", [
        [(0.70, 0.655, S), (0.70, 0.31, S), (0.67, 0.21), (0.58, 0.172, S), (0.25, 0.17, S), (0.19, 0.14),
         (0.13, 0.05), (0.09, -0.05, S), (-0.02, -0.05, S), (-0.02, 0.12), (0.0, 0.28), (0.025, 0.43),
         (0.05, 0.53), (0.09, 0.61), (0.14, 0.648), (0.19, 0.655, S)],
        rounded_rect(0.255, 0.645, 0.212, 0.588, 0.03),
    ], 0.22, 0.022, STEEL)
    profile("Rear_Sight_Base", [[(0.17, 0.64, S), (0.17, 0.675, S), (0.29, 0.675, S), (0.31, 0.64, S)]],
            0.11, 0.01, STEEL)
    for side, x in (("L", 0.036), ("R", -0.036)):
        profile(f"Rear_Sight_{side}", [[(0.17, 0.66, S), (0.17, 0.705, S), (0.24, 0.705, S), (0.27, 0.66, S)]],
                0.032, 0.006, STEEL, x=x)
        for index, (u, v) in enumerate(((0.19, 0.40), (0.15, 0.56))):
            stud(f"Screw_{side}{index + 1}", 0.024, 0.02, u, v, math.copysign(0.111, x), STEEL)

    profile("Hammer", [[(0.145, 0.52, S), (0.152, 0.62), (0.13, 0.685), (0.08, 0.722), (0.02, 0.746),
                        (-0.04, 0.752), (-0.078, 0.735), (-0.07, 0.708), (-0.03, 0.70), (0.02, 0.682),
                        (0.05, 0.64), (0.06, 0.52, S)]], 0.075, 0.012, STEEL)
    profile("Trigger_Guard", [circle(0.32, 0.085, 0.105), circle(0.32, 0.085, 0.068)], 0.08, 0.02, STEEL)
    profile("Trigger", [[(0.345, 0.19, S), (0.356, 0.13), (0.34, 0.075), (0.30, 0.038), (0.283, 0.05),
                         (0.305, 0.085), (0.316, 0.13), (0.305, 0.19, S)]], 0.05, 0.01, STEEL)

    # Six-shot cylinder: chambers line up with the bore at the top, flutes sit between them and
    # break through the front face for the flared star seen on the reference.
    cylinder = tube("Cylinder", CYLINDER_RADIUS, CYLINDER_START, CYLINDER_END, CYLINDER_V, STEEL, sides=48)
    bevel(cylinder, 0.02, segments=3)
    chamber_offset = BORE_V - CYLINDER_V
    flutes, chambers = [], []
    for index in range(6):
        chamber = math.radians(90 + index * 60)
        flute = chamber + math.radians(30)
        radial = Vector((math.cos(flute), 0, math.sin(flute)))
        tangent = Vector((-math.sin(flute), 0, math.cos(flute)))
        center = world(0.48, CYLINDER_V) + radial * (CYLINDER_RADIUS + 0.018)
        flutes.append(ellipsoid(f"Cut_Flute{index + 1}", center, (radial, tangent, Vector((0, 1, 0))), (0.07, 0.048, 0.19)))
        chambers.append(tube(f"Cut_Chamber{index + 1}", 0.04, CYLINDER_END - 0.05, CYLINDER_END + 0.05,
                             CYLINDER_V + math.sin(chamber) * chamber_offset,
                             x=math.cos(chamber) * chamber_offset, sides=20, destination=CUTTERS))
    subtract(cylinder, flutes + chambers, "Cut_Cylinder")
    tube("Cylinder_Pin", 0.032, CYLINDER_END - 0.01, 0.70, CYLINDER_V, STEEL, sides=16)

    profile("Grip", [[(0.20, 0.26, S), (0.205, 0.14), (0.165, 0.0), (0.105, -0.15), (0.055, -0.29), (0.025, -0.37),
                      (-0.04, -0.415), (-0.13, -0.41), (-0.21, -0.36), (-0.25, -0.28), (-0.235, -0.16),
                      (-0.17, -0.02), (-0.09, 0.13), (-0.02, 0.29), (0.0, 0.37), (0.04, 0.41), (0.09, 0.395), (0.15, 0.335)]],
            0.28, 0.05, IVORY, resolution=5)
    for side, x in (("L", 0.14), ("R", -0.14)):
        stud(f"Grip_Medallion_{side}", 0.032, 0.016, -0.03, 0.0, x, STEEL)

    for cutter in CUTTERS.all_objects:
        cutter.display_type = "WIRE"
        cutter.hide_render = True
        cutter.hide_viewport = True


def evaluated_copy(obj, depsgraph):
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), preserve_all_data_layers=True, depsgraph=depsgraph)
    mesh.transform(obj.matrix_world)
    return mesh


def build_exports():
    """Join the evaluated parts into one mesh per material so Roblox imports two MeshParts."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    result = {}
    for mat, name in ((STEEL, "Revolver_Steel"), (IVORY, "Revolver_Grip")):
        bm = bmesh.new()
        for obj in PARTS.objects:
            if obj.type in {"MESH", "CURVE"} and obj.active_material == mat:
                mesh = evaluated_copy(obj, depsgraph)
                bm.from_mesh(mesh)
                bpy.data.meshes.remove(mesh)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0002)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.clear()
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(name, mesh)
        EXPORT.objects.link(obj)
        result[name] = obj
    with bpy.context.temp_override(selected_editable_objects=list(result.values()), object=None, active_object=None):
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(38), keep_sharp_edges=False)
    return result


def write_exports(meshes):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes.values():
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes["Revolver_Steel"]
    bpy.ops.export_scene.fbx(filepath=str(ASSETS / "revolver.fbx"), use_selection=True, object_types={"MESH"},
                             bake_anim=False, add_leaf_bones=False, apply_scale_options="FBX_SCALE_UNITS",
                             axis_forward="Z", axis_up="Y", mesh_smooth_type="OFF")
    bpy.ops.export_scene.gltf(filepath=str(ASSETS / "revolver.glb"), export_format="GLB",
                              use_selection=True, export_animations=False)

    # Roblox recenters a MeshPart on its bounding box, so report attachment points relative to it.
    corners = [obj.matrix_world @ Vector(c) for obj in meshes.values() for c in obj.bound_box]
    low = Vector(min(c[i] for c in corners) for i in range(3))
    high = Vector(max(c[i] for c in corners) for i in range(3))

    def roblox(point, center):
        offset = point - center
        return [round(-offset.x, 3), round(offset.z, 3), round(offset.y, 3)]

    steel = meshes["Revolver_Steel"]
    steel_low = Vector(min((steel.matrix_world @ Vector(c))[i] for c in steel.bound_box) for i in range(3))
    steel_high = Vector(max((steel.matrix_world @ Vector(c))[i] for c in steel.bound_box) for i in range(3))
    steel_center = (steel_low + steel_high) / 2
    grip = meshes["Revolver_Grip"]
    grip_low = Vector(min((grip.matrix_world @ Vector(c))[i] for c in grip.bound_box) for i in range(3))
    grip_high = Vector(max((grip.matrix_world @ Vector(c))[i] for c in grip.bound_box) for i in range(3))
    grip_center = (grip_low + grip_high) / 2
    size = high - low
    info = {
        "units": "studs (import with File Dimensions set to Studs)",
        "axes": "Roblox: barrel along -Z, up +Y",
        "overall_size": [round(size.x, 3), round(size.z, 3), round(size.y, 3)],
        "triangles": {name: len(obj.data.polygons) for name, obj in meshes.items()},
        "relative_to_grip_meshpart_center": {
            "hand_point": roblox(world(0.04, 0.0), grip_center),
            "muzzle": roblox(world(MUZZLE_U, BORE_V), grip_center),
            "steel_meshpart_center": roblox(steel_center, grip_center),
        },
        "relative_to_steel_meshpart_center": {
            "muzzle": roblox(world(MUZZLE_U, BORE_V), steel_center),
        },
    }
    (ASSETS / "revolver-attachments.json").write_text(json.dumps(info, indent=2) + "\n")
    return info


def area_light(name, position, energy, size, color, target):
    light = bpy.data.lights.new(name, "AREA")
    light.energy = energy
    light.shape = "DISK"
    light.size = size
    light.color = color
    obj = bpy.data.objects.new(name, light)
    STUDIO.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_studio():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    preferences = bpy.context.preferences.addons["cycles"].preferences
    try:
        preferences.compute_device_type = "OPTIX"
        preferences.get_devices()
        gpu = False
        for device in preferences.devices:
            device.use = device.type != "CPU"
            gpu = gpu or device.use
        if gpu:
            scene.cycles.device = "GPU"
    except (TypeError, RuntimeError):
        scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.75, 0.78, 0.82, 1)
    background.inputs["Strength"].default_value = 0.35

    target = world(0.88, 0.18)
    mesh = bpy.data.meshes.new("Studio_Backdrop")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material("Studio_Backdrop", "#E9E7E2", 0, 0.9))
    plane = bpy.data.objects.new("Studio_Backdrop", mesh)
    STUDIO.objects.link(plane)
    plane.location = (-0.45, 0, 0)
    plane.rotation_euler = (0, math.pi / 2, 0)

    area_light("Studio_Key", target + Vector((4, 2.5, 4)), 900, 4, (1.0, 0.95, 0.88), target)
    area_light("Studio_Fill", target + Vector((5, -3, 0.5)), 350, 5, (0.85, 0.9, 1.0), target)
    area_light("Studio_Rim", target + Vector((-2, -1, 4)), 600, 2, (1.0, 1.0, 1.0), target)

    camera = bpy.data.cameras.new("Revolver_Preview_Camera")
    camera.type = "ORTHO"
    camera.ortho_scale = 2.55
    obj = bpy.data.objects.new(camera.name, camera)
    STUDIO.objects.link(obj)
    obj.location = target + Vector((8, -1.6, 2.2))
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = obj


# Only remove starter objects and collections created by this builder, so reruns stay clean.
for name in ("Cube", "Camera", "Light"):
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)
for name in ("01_Revolver_Parts", "02_Roblox_Export", "80_Boolean_Cutters", "90_Render_Studio") + tuple(
        c.name for c in bpy.data.collections if c.name.startswith("Cut_")):
    previous = bpy.data.collections.get(name)
    if previous:
        for obj in list(previous.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(previous)
bpy.data.orphans_purge(do_recursive=True)

ASSETS.mkdir(exist_ok=True)
PARTS = collection("01_Revolver_Parts")
EXPORT = collection("02_Roblox_Export")
CUTTERS = collection("80_Boolean_Cutters")
STUDIO = collection("90_Render_Studio")
STEEL = material("Revolver_Steel", "#24272C", 0.85, 0.32, coat=0.35)
IVORY = material("Revolver_Ivory_Grip", "#D9CCA6", 0.0, 0.38, coat=0.5)

build_parts()
meshes = build_exports()
info = write_exports(meshes)
setup_studio()

# Render the joined export meshes so the preview shows exactly what Roblox receives.
for obj in PARTS.objects:
    obj.hide_render = True
PARTS.hide_render = True
bpy.context.view_layer.layer_collection.children[EXPORT.name].hide_viewport = True
bpy.context.view_layer.layer_collection.children[CUTTERS.name].exclude = False
CUTTERS.hide_render = True
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.shading.type = "MATERIAL"
bpy.context.scene["Revolver_Instructions"] = (
    "01_Revolver_Parts holds the editable curve profiles and boolean modifiers. Rerunning "
    "tools/build_revolver.py regenerates every collection from the script, so make lasting shape "
    "changes there; after manual edits here, re-export the parts instead of rerunning the builder.")
bpy.context.preferences.filepaths.save_version = 0
bpy.context.scene.render.filepath = str(ASSETS / "revolver-preview.png")
bpy.ops.wm.save_as_mainfile(filepath=str(PROJECT / "assets" / "revolver.blend"))
bpy.ops.render.render(write_still=True)
print("REVOLVER_INFO", json.dumps(info))
print("REVOLVER_BUILD_COMPLETE", str(PROJECT / "assets" / "revolver.blend"))
