"""Build an editable 3D trading card, studio render, and Roblox-oriented exports."""

from pathlib import Path
import json
import math
import sys

import bpy
from mathutils import Matrix, Vector

PROJECT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT / "assets" / "cards"
sys.path.insert(0, str(Path(__file__).resolve().parent))
from card_controls import apply_content, linear_color

CONFIG = json.loads((ASSETS / "card-config.json").read_text())


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def move_to(obj, destination, parent=True):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    destination.objects.link(obj)
    if parent:
        obj.parent = ROOT
    return obj


def material(name, color, metallic=0, roughness=0.5, control=None, darker=False):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    result.diffuse_color = linear_color(color)
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = result.diffuse_color
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = 0.15
    if control:
        for index in range(4):
            for destination, path in ((shader.inputs["Base Color"], "default_value"), (result, "diffuse_color")):
                driver = destination.driver_add(path, index).driver
                driver.type = "SCRIPTED"
                driver.expression = "tone"
                variable = driver.variables.new()
                variable.name = "tone"
                variable.type = "SINGLE_PROP"
                variable.targets[0].id = ROOT
                variable.targets[0].data_path = f'["{control}"][{index}]'
                if darker and index < 3:
                    shade = driver.variables.new()
                    shade.name = "shade"
                    shade.type = "SINGLE_PROP"
                    shade.targets[0].id = ROOT
                    shade.targets[0].data_path = '["BorderShade"]'
                    driver.expression = "tone * shade"
    return result


def contour(width, height, radius, segments=8):
    points = []
    for x, y, angle in ((width / 2 - radius, height / 2 - radius, 0),
                        (-width / 2 + radius, height / 2 - radius, 90),
                        (-width / 2 + radius, -height / 2 + radius, 180),
                        (width / 2 - radius, -height / 2 + radius, 270)):
        for step in range(segments + 1):
            theta = math.radians(angle + step * 90 / segments)
            points.append((x + radius * math.cos(theta), y + radius * math.sin(theta)))
    return points


def mesh_object(name, vertices, faces, mat, destination=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    (destination or GEOMETRY).objects.link(obj)
    obj.parent = ROOT
    obj.data.materials.append(mat)
    return obj


def plate(name, width, height, radius, x, y, z, thickness, mat):
    points = contour(width, height, radius)
    count = len(points)
    vertices = [(px + x, py + y, z + dz) for dz in (-thickness / 2, thickness / 2) for px, py in points]
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    faces += [(index, (index + 1) % count, (index + 1) % count + count, index + count) for index in range(count)]
    obj = mesh_object(name, vertices, faces, mat)
    bevel = obj.modifiers.new("Soft manufactured edges", "BEVEL")
    bevel.width = min(0.008, thickness / 3)
    bevel.segments = 2
    bevel.affect = "EDGES"
    return obj


def rim(name, width, height, radius, inset, x, y, z, thickness, mat):
    outside = contour(width, height, radius)
    inside = contour(width - inset * 2, height - inset * 2, max(0.015, radius - inset))
    count = len(outside)
    vertices = [(px + x, py + y, z + dz) for dz in (-thickness / 2, thickness / 2) for loop in (outside, inside) for px, py in loop]
    faces = []
    for index in range(count):
        nxt = (index + 1) % count
        faces.extend(((index, nxt, nxt + count, index + count),
                      (index + 2 * count, index + 3 * count, nxt + 3 * count, nxt + 2 * count),
                      (index, index + 2 * count, nxt + 2 * count, nxt),
                      (index + count, nxt + count, nxt + 3 * count, index + 3 * count)))
    return mesh_object(name, vertices, [tuple(reversed(face)) for face in faces], mat)


def text(name, body, x, y, z, size, mat, font, align="LEFT", back=False):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.font = font
    curve.size = size
    curve.align_x = align
    curve.space_line = 1.2
    curve.extrude = 0
    curve.resolution_u = 5
    obj = bpy.data.objects.new(name, curve)
    TEXT.objects.link(obj)
    obj.parent = ROOT
    obj.location = (x, y, z)
    if back:
        obj.rotation_euler.x = math.pi
    obj.data.materials.append(mat)
    obj.visible_shadow = False
    return obj


def star(name, x, y, z, radius, mat, points=4):
    vertices = []
    for index in range(points * 2):
        angle = math.pi / 2 + index * math.pi / points
        distance = radius if index % 2 == 0 else radius * 0.36
        vertices.append((x + math.cos(angle) * distance, y + math.sin(angle) * distance, z))
    order = tuple(range(len(vertices)))
    return mesh_object(name, vertices, [tuple(reversed(order)) if z < 0 else order], mat)


def artwork(path):
    mat = material("Card_Artwork", "#FFFFFF", roughness=0.82)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Specular IOR Level"].default_value = 0.08
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.name = "ArtworkImage"
    node.image = bpy.data.images.load(str(path))
    node.image.pack()
    mat.node_tree.links.new(node.outputs["Color"], shader.inputs["Base Color"])
    mat.node_tree.links.new(node.outputs["Color"], shader.inputs["Emission Color"])
    shader.inputs["Emission Strength"].default_value = 0.12
    width, height, center = 2.10, 1.45, 0.43
    points = contour(width, height, 0.07)
    obj = mesh_object("Card_Artwork_Image", [(x, y + center, 0.102) for x, y in points], [tuple(range(len(points)))], mat, ARTWORK)
    uv = obj.data.uv_layers.new(name="ArtworkUV")
    ratio = node.image.size[0] / node.image.size[1]
    u_scale = min(1, width / height / ratio)
    v_scale = min(1, ratio / (width / height))
    for loop in obj.data.loops:
        px, py, _ = obj.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (0.5 + px / width * u_scale, 0.5 + (py - center) / height * v_scale)


def area_light(name, position, energy, size, color):
    light = bpy.data.lights.new(name, "AREA")
    light.energy = energy
    light.shape = "DISK"
    light.size = size
    light.color = color
    obj = bpy.data.objects.new(name, light)
    STUDIO.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector((0, 0, 0)) - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_studio():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
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
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 1500
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.12, 0.16, 0.24, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.3
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.18))
    plane = bpy.context.object
    plane.name = "Studio_Backdrop"
    plane.data.materials.append(material("Studio_Midnight", "#222F41", roughness=0.93))
    move_to(plane, STUDIO, parent=False)
    area_light("Studio_Key", (-3.5, 4.5, 7), 550, 5, (1.0, 0.90, 0.77))
    area_light("Studio_Fill", (4, 1, 5), 320, 4, (0.70, 0.84, 1.0))
    area_light("Studio_Edge", (-1, -4, 4), 250, 3, (1.0, 0.75, 0.47))
    camera = bpy.data.cameras.new("Card_Preview_Camera")
    camera.type = "ORTHO"
    camera.ortho_scale = 4.35
    obj = bpy.data.objects.new(camera.name, camera)
    STUDIO.objects.link(obj)
    obj.location = (1.8, -2.5, 14)
    direction = (-obj.location).normalized()
    right = direction.cross(Vector((0, 1, 0))).normalized()
    up = right.cross(direction).normalized()
    obj.rotation_euler = Matrix((right, up, -direction)).transposed().to_euler()
    scene.camera = obj


def exports():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in GEOMETRY.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["Card_Body"]
    bpy.ops.export_scene.fbx(filepath=str(ASSETS / "card-shell.fbx"), use_selection=True,
                             object_types={"MESH"}, bake_anim=False, add_leaf_bones=False,
                             apply_scale_options="FBX_SCALE_UNITS", axis_forward="Z", axis_up="Y")
    for obj in TEXT.objects:
        obj.select_set(True)
    for obj in ARTWORK.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ASSETS / "card-complete.glb"), export_format="GLB",
                             use_selection=True, export_animations=False, export_extras=True)


# Only remove the known starter objects and collections created by this builder.
for name in ("Cube", "Camera", "Light"):
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)
for name in ("01_Card_Geometry", "02_Editable_Text", "03_Artwork", "90_Render_Studio"):
    previous = bpy.data.collections.get(name)
    if previous:
        for obj in list(previous.objects):
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if data and data.users == 0:
                bpy.data.batch_remove(ids=(data,))
        bpy.data.collections.remove(previous)
previous_root = bpy.data.objects.get("Card_Controls")
if previous_root:
    bpy.data.objects.remove(previous_root, do_unlink=True)
for mat in list(bpy.data.materials):
    if mat.users == 0 and mat.name.startswith(("Card_", "Studio_")):
        bpy.data.materials.remove(mat)
GEOMETRY = collection("01_Card_Geometry")
TEXT = collection("02_Editable_Text")
ARTWORK = collection("03_Artwork")
STUDIO = collection("90_Render_Studio")
ROOT = bpy.data.objects.new("Card_Controls", None)
GEOMETRY.objects.link(ROOT)
ROOT.empty_display_type = "PLAIN_AXES"
ROOT.empty_display_size = 0.2
ROOT["Title"] = CONFIG["title"]
ROOT["Description"] = CONFIG["description"]
ROOT["Buff"] = CONFIG["buff"]
ROOT["BuffLabel"] = CONFIG["buff_label"]
ROOT["Artwork"] = "//cards/" + CONFIG["artwork"]
ROOT["BorderShade"] = CONFIG["border_shade"]
ROOT.id_properties_ui("BorderShade").update(min=0.05, max=0.85, description="Border brightness relative to the main color")
for prop, key in (("AccentColor", "accent_color"), ("FaceColor", "face_color"), ("InkColor", "ink_color")):
    ROOT[prop] = linear_color(CONFIG[key])
    ROOT.id_properties_ui(prop).update(subtype="COLOR", min=0.0, max=1.0)

BORDER = material("Card_Border_Color", CONFIG["accent_color"], roughness=0.65, control="AccentColor", darker=True)
ACCENT = material("Card_Accent_Color", CONFIG["accent_color"], roughness=0.65, control="AccentColor")
FACE = material("Card_Face_Color", CONFIG["face_color"], roughness=0.82, control="FaceColor")
INK = material("Card_Ink_Color", CONFIG["ink_color"], roughness=0.8, control="InkColor")
WHITE = material("Card_Light_Text", "#FFFFFF", roughness=0.8)
FONT_BOLD = bpy.data.fonts.load("C:/Windows/Fonts/segoeuib.ttf")
FONT_BOLD.pack()

plate("Card_Body", 2.54, 3.54, 0.16, 0, 0, 0, 0.10, BORDER)
plate("Card_Colored_Face", 2.40, 3.40, 0.13, 0, 0, 0.059, 0.018, ACCENT)
rim("Card_Outer_Border", 2.53, 3.53, 0.16, 0.055, 0, 0, 0.061, 0.025, BORDER)
plate("Card_Description_Panel", 2.20, 0.68, 0.10, 0, -0.72, 0.085, 0.014, FACE)
rim("Card_Artwork_Frame", 2.20, 1.55, 0.12, 0.044, 0, 0.43, 0.091, 0.018, BORDER)
artwork(ASSETS / CONFIG["artwork"])
plate("Card_Buff_Panel", 2.20, 0.43, 0.10, 0, -1.35, 0.090, 0.014, BORDER)

text("Card_Title", CONFIG["title"], 0, 1.355, 0.087, 0.25, WHITE, FONT_BOLD, align="CENTER")
outline = text("Card_Title_Outline", CONFIG["title"], 0, 1.355, 0.085, 0.25, INK, FONT_BOLD, align="CENTER")
outline.data.offset = 0.007
text("Card_Description", CONFIG["description"], 0, -0.66, 0.096, 0.25, INK, FONT_BOLD, align="CENTER")
text("Card_Buff", CONFIG["buff"], 0, 0, 0.105, 0.28, WHITE, FONT_BOLD)
text("Card_BuffLabel", CONFIG["buff_label"], 0, 0, 0.105, 0.28, WHITE, FONT_BOLD)

plate("Card_Back_Face", 2.36, 3.36, 0.12, 0, 0, -0.057, 0.012, ACCENT)
star("Card_Back_Sigil", 0, 0.12, -0.067, 0.48, WHITE)
text("Card_Back_Title", "UPGRADE", 0, -0.48, -0.07, 0.20, WHITE, FONT_BOLD, align="CENTER", back=True)

setup_studio()
bpy.context.scene["Card_Instructions"] = "Run the embedded CardControls.py text to enable the Upgrade Card sidebar. Colors update live; Apply text and artwork updates content."
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(PROJECT / "assets" / "cards.blend"))
apply_content()
controls = bpy.data.texts.get("CardControls.py") or bpy.data.texts.new("CardControls.py")
controls.clear()
controls.write((PROJECT / "tools" / "card_controls.py").read_text())
exports()
bpy.ops.object.select_all(action="DESELECT")
ROOT.select_set(True)
bpy.context.view_layer.objects.active = ROOT
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_perspective = "CAMERA"
            area.spaces.active.shading.type = "MATERIAL"
        elif area.type == "TEXT_EDITOR":
            area.spaces.active.text = controls
bpy.context.scene.render.filepath = str(ASSETS / "card-preview.png")
bpy.ops.wm.save_as_mainfile(filepath=str(PROJECT / "assets" / "cards.blend"))
bpy.ops.render.render(write_still=True)
print("CARD_BUILD_COMPLETE", str(PROJECT / "assets" / "cards.blend"))
