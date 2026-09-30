"""Run inside Blender to enable the Upgrade Card sidebar; also embedded in cards.blend."""

from pathlib import Path
import sys
import argparse

import bpy


THEMES = {
    "Damage": "#F77B39",
    "Ammo": "#F2B92D",
    "FireRate": "#389FEC",
    "Health": "#42C78D",
    "Reload": "#A879E8",
}


def linear_color(value):
    value = value.lstrip("#")
    if len(value) != 6:
        raise ValueError("Colors must contain six hexadecimal digits")
    rgb = [int(value[index:index + 2], 16) / 255 for index in (0, 2, 4)]
    return tuple(channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4 for channel in rgb) + (1.0,)


def fit_text(obj, width):
    obj.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    if obj.dimensions.x > width:
        scale = width / obj.dimensions.x
        obj.scale = (scale, scale, scale)


def text_bounds(obj):
    return (
        min(corner[0] for corner in obj.bound_box),
        max(corner[0] for corner in obj.bound_box),
        min(corner[1] for corner in obj.bound_box),
        max(corner[1] for corner in obj.bound_box),
    )


def center_text(obj, x, y):
    left, right, bottom, top = text_bounds(obj)
    obj.location.x = x - (left + right) * obj.scale.x / 2
    obj.location.y = y - (bottom + top) * obj.scale.y / 2


def align_buff():
    value = bpy.data.objects["Card_Buff"]
    label = bpy.data.objects["Card_BuffLabel"]
    value.scale = label.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    value_left, value_right, value_bottom, value_top = text_bounds(value)
    label_left, label_right, label_bottom, label_top = text_bounds(label)
    gap = 0.10
    width = value_right - value_left + gap + label_right - label_left
    bottom, top = min(value_bottom, label_bottom), max(value_top, label_top)
    scale = min(1, 1.90 / max(width, 0.001), 0.28 / max(top - bottom, 0.001))
    value.scale = label.scale = (scale, scale, scale)
    # Fit the whole phrase together so both fields keep a shared baseline and size.
    value.location.x = -width * scale / 2 - value_left * scale
    label.location.x = (-width / 2 + value_right - value_left + gap - label_left) * scale
    value.location.y = label.location.y = -1.35 - (bottom + top) * scale / 2


def apply_content():
    root = bpy.data.objects["Card_Controls"]
    fields = {
        "Title": ("Card_Title", 2.10),
        "Description": ("Card_Description", 1.96),
    }
    for key, (name, width) in fields.items():
        obj = bpy.data.objects[name]
        obj.data.body = root[key].replace("\\n", "\n")
        fit_text(obj, width)
    description = bpy.data.objects["Card_Description"]
    if description.dimensions.y > 0.49:
        factor = 0.49 / description.dimensions.y
        description.scale *= factor
    center_text(description, 0, -0.72)
    title = bpy.data.objects["Card_Title"]
    outline = bpy.data.objects["Card_Title_Outline"]
    outline.data.body = title.data.body
    outline.scale = title.scale.copy()
    outline.location.x = title.location.x
    outline.location.y = title.location.y
    bpy.data.objects["Card_Buff"].data.body = root["Buff"]
    bpy.data.objects["Card_BuffLabel"].data.body = root["BuffLabel"]
    align_buff()
    path = Path(bpy.path.abspath(root["Artwork"]))
    if not path.is_file():
        raise FileNotFoundError(f"Artwork does not exist: {path}")
    image = bpy.data.images.load(str(path), check_existing=True)
    image.pack()
    node = bpy.data.materials["Card_Artwork"].node_tree.nodes["ArtworkImage"]
    node.image = image
    mesh = bpy.data.objects["Card_Artwork_Image"].data
    left = min(vertex.co.x for vertex in mesh.vertices)
    bottom = min(vertex.co.y for vertex in mesh.vertices)
    width = max(vertex.co.x for vertex in mesh.vertices) - left
    height = max(vertex.co.y for vertex in mesh.vertices) - bottom
    ratio = image.size[0] / image.size[1]
    u_scale = min(1, width / height / ratio)
    v_scale = min(1, ratio / (width / height))
    for loop in mesh.loops:
        x, y, _ = mesh.vertices[loop.vertex_index].co
        mesh.uv_layers.active.data[loop.index].uv = (
            0.5 + ((x - left) / width - 0.5) * u_scale,
            0.5 + ((y - bottom) / height - 0.5) * v_scale,
        )
    root.update_tag()
    bpy.context.view_layer.update()


class CARD_OT_apply(bpy.types.Operator):
    bl_idname = "card.apply_content"
    bl_label = "Apply text and artwork"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        try:
            apply_content()
        except (ValueError, FileNotFoundError) as error:
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}
        return {"FINISHED"}


class CARD_OT_theme(bpy.types.Operator):
    bl_idname = "card.set_theme"
    bl_label = "Set card accent"
    bl_options = {"REGISTER", "UNDO"}
    theme: bpy.props.StringProperty()

    def execute(self, context):
        root = bpy.data.objects["Card_Controls"]
        root["AccentColor"] = linear_color(THEMES[self.theme])
        root.update_tag()
        context.view_layer.update()
        return {"FINISHED"}


class CARD_PT_controls(bpy.types.Panel):
    bl_label = "Upgrade Card"
    bl_idname = "CARD_PT_controls"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Upgrade Card"

    @classmethod
    def poll(cls, context):
        return "Card_Controls" in bpy.data.objects

    def draw(self, context):
        root = bpy.data.objects["Card_Controls"]
        layout = self.layout
        for key in ("AccentColor", "FaceColor", "InkColor"):
            layout.prop(root, f'["{key}"]', text=key.replace("Color", " color"))
        layout.prop(root, '["BorderShade"]', text="Border brightness", slider=True)
        row = layout.row(align=True)
        for theme in THEMES:
            button = row.operator("card.set_theme", text=theme)
            button.theme = theme
        layout.separator()
        for key in ("Title", "Description", "Buff", "BuffLabel", "Artwork"):
            layout.prop(root, f'["{key}"]', text=key)
        layout.operator("card.apply_content")


def register():
    for cls in (CARD_OT_apply, CARD_OT_theme, CARD_PT_controls):
        previous = getattr(bpy.types, cls.__name__, None)
        if previous and getattr(previous, "is_registered", False):
            bpy.utils.unregister_class(previous)
        bpy.utils.register_class(cls)


if __name__ == "__main__":
    if "--" in sys.argv:
        parser = argparse.ArgumentParser()
        parser.add_argument("--accent")
        parser.add_argument("--theme", choices=THEMES)
        parser.add_argument("--output")
        parser.add_argument("--render")
        args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
        root = bpy.data.objects["Card_Controls"]
        if args.accent or args.theme:
            root["AccentColor"] = linear_color(args.accent or THEMES[args.theme])
        apply_content()
        if args.output:
            bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.output).resolve()))
        if args.render:
            bpy.context.scene.render.filepath = str(Path(args.render).resolve())
            bpy.ops.render.render(write_still=True)
    else:
        register()
