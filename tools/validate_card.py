"""Check the generated Blender asset, color controls, content, framing, and exports."""

from pathlib import Path
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from card_controls import apply_content, linear_color, register

PROJECT = Path(__file__).resolve().parents[1]
ROOT = bpy.data.objects["Card_Controls"]
scene = bpy.context.scene
register()
assert bpy.ops.card.set_theme(theme="Health") == {"FINISHED"}
expected = linear_color("#42C78D")
shader = bpy.data.materials["Card_Accent_Color"].node_tree.nodes.get("Principled BSDF")
assert all(abs(actual - target) < 0.00001 for actual, target in zip(shader.inputs["Base Color"].default_value, expected)), "Accent driver did not update"
border = bpy.data.materials["Card_Border_Color"].node_tree.nodes.get("Principled BSDF")
assert all(abs(border.inputs["Base Color"].default_value[index] - expected[index] * ROOT["BorderShade"]) < 0.00001 for index in range(3)), "Border must follow the accent in a darker shade"
assert bpy.data.objects.get("Card_Category") is None
assert bpy.data.objects.get("Card_Level") is None
assert bpy.data.objects.get("Card_Collection_Number") is None
assert not any(obj.name.startswith(("Card_Level_", "Card_Corner_")) for obj in bpy.data.objects)
assert bpy.data.objects["Card_Description"].data.size >= 0.18

ROOT["Title"] = "A VERY LONG CUSTOM CARD TITLE"
ROOT["Description"] = "First line\\nSecond line"
ROOT["Buff"] = "+10"
ROOT["BuffLabel"] = "MAX HEALTH"
apply_content()
assert bpy.data.objects["Card_Title"].dimensions.x <= 2.101
assert bpy.data.objects["Card_Description"].data.body == "First line\nSecond line"
assert bpy.data.objects["Card_BuffLabel"].data.body == "MAX HEALTH"
assert bpy.data.materials["Card_Artwork"].node_tree.nodes["ArtworkImage"].image.packed_file
assert bpy.data.objects["Card_Title"].data.font.packed_file
assert "CardControls.py" in bpy.data.texts

shell_triangles = 0
depsgraph = bpy.context.evaluated_depsgraph_get()
for obj in bpy.data.collections["01_Card_Geometry"].objects:
    if obj.type != "MESH":
        continue
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    shell_triangles += len(mesh.loop_triangles)
    assert len(mesh.loop_triangles) < 10000
    evaluated.to_mesh_clear()
    for corner in obj.bound_box:
        projected = world_to_camera_view(scene, scene.camera, obj.matrix_world @ Vector(corner))
        assert 0.01 < projected.x < 0.99 and 0.01 < projected.y < 0.99, f"Camera clips {obj.name}"
    if "Border" in obj.name or "Frame" in obj.name:
        top = max(vertex.co.z for vertex in obj.data.vertices)
        for polygon in obj.data.polygons:
            if all(abs(obj.data.vertices[index].co.z - top) < 0.00001 for index in polygon.vertices):
                assert polygon.normal.z > 0.99, f"Inverted front face: {obj.name}"

for file in ("card-shell.fbx", "card-complete.glb", "card-preview.png"):
    assert (PROJECT / "assets" / "cards" / file).stat().st_size > 1000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(PROJECT / "assets" / "cards" / "card-shell.fbx"))
assert any(obj.name == "Card_Body" for obj in bpy.data.objects)
assert not any(obj.type in {"LIGHT", "CAMERA"} for obj in bpy.data.objects)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(PROJECT / "assets" / "cards" / "card-complete.glb"))
assert any(obj.name == "Card_Title" for obj in bpy.data.objects)
assert any(obj.name == "Card_Artwork_Image" for obj in bpy.data.objects)
assert any(image.packed_file for image in bpy.data.images)
print(f"PASS: {shell_triangles} shell triangles; darker linked borders, simplified layout, readable editable text, packed art/fonts, complete framing, FBX and GLB import")
