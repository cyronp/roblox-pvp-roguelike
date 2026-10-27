"""Build the revolver arena as a Roblox XML model that Rojo syncs into Workspace.

The layout is a TF2 "orange" style free-for-all test map: flat orange floors,
grey blocks, and four identical quarters rotated around the center so no area
is favored. Spawns are invisible SpawnLocations spread over the whole map;
Roblox picks one at random for each neutral player.
Run `python tools/build_arena.py`, then sync or rebuild the place.
Pass `--check` to only validate the layout without writing the model.
"""

from pathlib import Path
import math
import sys

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/arena/Arena.rbxmx"

HALF = 130  # Playable floor spans -HALF..HALF on X and Z.
WALL_HEIGHT = 32
WALL_THICKNESS = 4
TILE = 20
DECK_HEIGHT = 12
DECK_START = 78  # Corner decks cover DECK_START..HALF on both axes.
SPAWN_FORCEFIELD_SECONDS = 2
# Mirrors TrainingDummy.server.luau, which places dummies in front of the first spawn it finds.
DUMMY_DISTANCE = 24
DUMMY_SPACING = 10

SMOOTH_PLASTIC = 272

FLOOR_A = (232, 125, 45)
FLOOR_B = (214, 110, 34)
WALL = (196, 196, 200)
COVER = (116, 118, 125)
PLATFORM = (212, 212, 216)
POINT = (246, 241, 230)
DECK = (240, 148, 66)
RAMP = (247, 178, 90)

QUARTERS = ["A", "B", "C", "D"]

IDENTITY = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
GROUPS = ["Spawns", "Floor", "Walls", "Center", "Cover", "Decks", "Ramps"]


def part(group, name, center, size, color, *, rot=IDENTITY, axis_aligned=True, cls="Part", material=SMOOTH_PLASTIC, shape=None, solid=True, extra=None):
    return {
        "group": group,
        "name": name,
        "center": tuple(center),
        "size": tuple(size),
        "rot": rot,
        "axis_aligned": axis_aligned,
        "class": cls,
        "color": color,
        "material": material,
        "shape": shape,
        "solid": solid,
        "extra": extra or [],
    }


def box(group, name, low, high, color, **kwargs):
    center = [(a + b) / 2 for a, b in zip(low, high)]
    size = [b - a for a, b in zip(low, high)]
    return part(group, name, center, size, color, **kwargs)


def matmul(a, b):
    return tuple(tuple(sum(a[r][k] * b[k][c] for k in range(3)) for c in range(3)) for r in range(3))


def apply(m, v):
    return tuple(sum(m[r][k] * v[k] for k in range(3)) for r in range(3))


def yaw(quarter):
    # Same matrix as CFrame.Angles(0, quarter * 90 degrees, 0).
    angle = quarter * math.pi / 2
    c, s = round(math.cos(angle)), round(math.sin(angle))
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def normalize(v):
    length = math.sqrt(sum(x * x for x in v))
    return tuple(x / length for x in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def ramp(name, bottom, top, width, thickness=1, extend=1.5):
    """A tilted slab whose top surface runs from `bottom` (on the floor) to `top` (a ledge edge)."""
    back = normalize([t - b for b, t in zip(bottom, top)])
    up = normalize(cross(back, cross((0, 1, 0), back)))
    right = cross(up, back)
    rot = tuple((right[r], up[r], back[r]) for r in range(3))
    length = math.dist(bottom, top) + extend
    # Extend only below the floor so the top end stays flush with the ledge.
    top_mid = [(b + t) / 2 - d * extend / 2 for b, t, d in zip(bottom, top, back)]
    center = [m - n * thickness / 2 for m, n in zip(top_mid, up)]
    return part("Ramps", name, center, (width, thickness, length), RAMP, rot=rot, axis_aligned=False)


def spawn(name, x, y, z):
    """An invisible SpawnLocation facing the arena center, standing on height `y`."""
    back = normalize((x, 0, z))
    right = (back[2], 0, -back[0])
    rot = tuple((right[r], (0, 1, 0)[r], back[r]) for r in range(3))
    return part("Spawns", name, (x, y + 0.5, z), (6, 1, 6), POINT, rot=rot, axis_aligned=False, cls="SpawnLocation", solid=False, extra=[
        ("float", "Transparency", "1"),
        ("bool", "CanCollide", "false"),
        ("bool", "CanQuery", "false"),
        ("bool", "CanTouch", "false"),
        ("int", "Duration", str(SPAWN_FORCEFIELD_SECONDS)),
        ("bool", "Neutral", "true"),
        ("bool", "AllowTeamChangeOnTouch", "false"),
        ("bool", "Enabled", "true"),
    ])


def quarter_parts(q):
    """One quarter in local space: the +Z lane, the corner deck at +X +Z, and their spawns."""
    parts = []
    add = parts.append

    # Spawns go first so TrainingDummy, which takes the first SpawnLocation, uses the lane spawn.
    add(spawn(f"{q}SpawnLane", 0, 0, 118))
    add(spawn(f"{q}SpawnCourtyard", -28, 0, 56))
    add(spawn(f"{q}SpawnRamp", 40, 0, 102))
    add(spawn(f"{q}SpawnUnderDeck", 118, 0, 90))
    add(spawn(f"{q}SpawnDeck", 92, DECK_HEIGHT, 118))

    edge = HALF + WALL_THICKNESS
    add(box("Walls", f"{q}Perimeter", (-HALF, -4, HALF), (edge, WALL_HEIGHT, edge), WALL))

    add(ramp(f"{q}CenterRamp", (0, 0, 30), (0, 4, 16), 10))
    add(box("Center", f"{q}PlatformCover", (9, 4, 9), (13, 7, 13), COVER))
    add(box("Cover", f"{q}CourtyardPillar", (40, 0, 40), (46, 16, 46), COVER))

    add(box("Cover", f"{q}LowWall", (-14, 0, 78), (14, 3.5, 80), COVER))
    add(box("Cover", f"{q}BlockNear", (20, 0, 56), (28, 8, 64), COVER))
    add(box("Cover", f"{q}BlockFar", (-50, 0, 82), (-40, 8, 88), COVER))
    add(box("Cover", f"{q}CrateBig", (-62, 0, 60), (-56, 6, 66), COVER))
    add(box("Cover", f"{q}CrateStep", (-61, 0, 56), (-57, 3, 60), COVER))
    # The screen shields the lane spawn from the center platform.
    add(box("Cover", f"{q}LaneScreen", (-8, 0, 104), (16, 8, 106), COVER))
    add(box("Cover", f"{q}WallCrate", (-34, 0, 112), (-28, 4, 118), COVER))

    deck = f"{q}Deck"
    add(box("Decks", f"{deck}Floor", (DECK_START, DECK_HEIGHT - 2, DECK_START), (HALF, DECK_HEIGHT, HALF), DECK))
    # The corner column also blocks the long diagonal between neighboring lanes.
    add(box("Cover", f"{deck}Column", (DECK_START - 6, 0, DECK_START - 6), (DECK_START + 2, DECK_HEIGHT + 4, DECK_START + 2), COVER))
    add(box("Cover", f"{deck}SupportRamp", (79, 0, 112), (83, DECK_HEIGHT - 2, 116), COVER))
    add(box("Cover", f"{deck}SupportSide", (112, 0, 79), (116, DECK_HEIGHT - 2, 83), COVER))
    add(box("Cover", f"{deck}RailRamp", (DECK_START, DECK_HEIGHT, 80), (DECK_START + 1, DECK_HEIGHT + 3.5, 118), COVER))
    add(box("Cover", f"{deck}RailSide", (80, DECK_HEIGHT, DECK_START), (HALF, DECK_HEIGHT + 3.5, DECK_START + 1), COVER))
    add(box("Cover", f"{deck}Crate", (104, DECK_HEIGHT, 96), (110, DECK_HEIGHT + 6, 102), COVER))
    add(ramp(f"{deck}Ramp", (48, 0, 124), (DECK_START, DECK_HEIGHT, 124), 12))
    return parts


def rotate(p, quarter):
    m = yaw(quarter)
    rotated = dict(p)
    rotated["center"] = apply(m, p["center"])
    if p["axis_aligned"] and quarter % 2 == 1:
        # A box turned 90 degrees is the same box with X and Z swapped; keeps Orientation at 0.
        x, y, z = p["size"]
        rotated["size"] = (z, y, x)
    elif not p["axis_aligned"]:
        rotated["rot"] = matmul(m, p["rot"])
    return rotated


def build_parts():
    parts = []
    for i in range(-HALF, HALF, TILE):
        for j in range(-HALF, HALF, TILE):
            color = FLOOR_A if ((i + j) // TILE) % 2 == 0 else FLOOR_B
            parts.append(box("Floor", "Tile", (i, -4, j), (i + TILE, 0, j + TILE), color))

    parts.append(box("Center", "Platform", (-16, 0, -16), (16, 4, 16), PLATFORM))
    disc_rot = ((0, -1, 0), (1, 0, 0), (0, 0, 1))  # Cylinder axis points up.
    parts.append(part("Center", "Point", (0, 4.1, 0), (0.2, 16, 16), POINT, rot=disc_rot, axis_aligned=False, shape=2, solid=False))

    for quarter, name in enumerate(QUARTERS):
        parts.extend(rotate(p, quarter) for p in quarter_parts(name))
    return parts


def bounds(p):
    half = [s / 2 for s in p["size"]]
    extent = [sum(abs(p["rot"][r][k]) * half[k] for k in range(3)) for r in range(3)]
    return [c - e for c, e in zip(p["center"], extent)], [c + e for c, e in zip(p["center"], extent)]


def overlaps(a, b, margin=0.01):
    return all(a[0][k] < b[1][k] - margin and b[0][k] < a[1][k] - margin for k in range(3))


def validate(parts):
    errors = []
    names = [p["name"] for p in parts if p["name"] != "Tile"]
    duplicates = {n for n in names if names.count(n) > 1}
    if duplicates:
        errors.append(f"duplicate names: {sorted(duplicates)}")

    cover = [(p["name"], bounds(p)) for p in parts if p["group"] in ("Cover", "Center") and p["solid"] and p["name"] != "Platform"]
    for i, (name_a, a) in enumerate(cover):
        for name_b, b in cover[i + 1:]:
            if overlaps(a, b):
                errors.append(f"{name_a} overlaps {name_b}")

    # Everything a player can stand in front of; ramps are checked only against cover.
    solids = [(p["name"], bounds(p)) for p in parts if p["solid"] and p["group"] not in ("Floor", "Ramps")]
    ramps = [(p["name"], bounds(p)) for p in parts if p["group"] == "Ramps"]
    for ramp_name, r in ramps:
        for name, b in cover:
            if overlaps(r, b):
                errors.append(f"{ramp_name} overlaps {name}")

    spawns = [p for p in parts if p["class"] == "SpawnLocation"]
    # Random spawning needs enough points that 8-10 players rarely share or crowd one.
    if len(spawns) < 16:
        errors.append(f"only {len(spawns)} spawns for 8-10 players")
    for i, spawn in enumerate(spawns):
        sx, sy, sz = spawn["center"]
        base = sy - spawn["size"][1] / 2
        standing = ((sx - 2, base + 0.5, sz - 2), (sx + 2, base + 5.5, sz + 2))
        for name, b in solids + ramps:
            if overlaps(standing, b):
                errors.append(f"{spawn['name']} is blocked by {name}")
        for other in spawns[i + 1:]:
            if math.dist(spawn["center"], other["center"]) < 30:
                errors.append(f"{spawn['name']} is too close to {other['name']}")

    first = spawns[0]
    look = apply(first["rot"], (0, 0, -1))
    right = (-look[2], 0, look[0])
    for offset in (0, -DUMMY_SPACING, DUMMY_SPACING):
        x = first["center"][0] + look[0] * DUMMY_DISTANCE + right[0] * offset
        z = first["center"][2] + look[2] * DUMMY_DISTANCE + right[2] * offset
        dummy = ((x - 2.5, 0.5, z - 2.5), (x + 2.5, 64, z + 2.5))
        for name, b in solids + ramps:
            if overlaps(dummy, b):
                errors.append(f"training dummy in front of {first['name']} is blocked by {name}")
    return errors


def number(value):
    text = f"{value:.5f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def color3uint8(rgb):
    r, g, b = rgb
    return str(0xFF000000 | (r << 16) | (g << 8) | b)


class Writer:
    def __init__(self):
        self.lines = []
        self.referent = 0

    def open(self, cls, depth):
        self.referent += 1
        pad = "\t" * depth
        self.lines.append(f'{pad}<Item class="{cls}" referent="RBX{self.referent:05d}">')
        self.lines.append(f"{pad}\t<Properties>")

    def prop(self, kind, name, value, depth):
        self.lines.append("\t" * (depth + 2) + f'<{kind} name="{name}">{value}</{kind}>')

    def end_props(self, depth):
        self.lines.append("\t" * depth + "\t</Properties>")

    def close(self, depth):
        self.lines.append("\t" * depth + "</Item>")

    def write_part(self, p, depth):
        self.open(p["class"], depth)
        self.prop("string", "Name", p["name"], depth)
        self.prop("bool", "Anchored", "true", depth)
        x, y, z = (number(v) for v in p["center"])
        rot = "".join(f"<R{r}{c}>{number(p['rot'][r][c])}</R{r}{c}>" for r in range(3) for c in range(3))
        self.lines.append("\t" * (depth + 2) + f'<CoordinateFrame name="CFrame"><X>{x}</X><Y>{y}</Y><Z>{z}</Z>{rot}</CoordinateFrame>')
        sx, sy, sz = (number(v) for v in p["size"])
        self.lines.append("\t" * (depth + 2) + f'<Vector3 name="size"><X>{sx}</X><Y>{sy}</Y><Z>{sz}</Z></Vector3>')
        self.prop("Color3uint8", "Color3uint8", color3uint8(p["color"]), depth)
        self.prop("token", "Material", str(p["material"]), depth)
        self.prop("token", "TopSurface", "0", depth)
        self.prop("token", "BottomSurface", "0", depth)
        if p["shape"] is not None:
            self.prop("token", "shape", str(p["shape"]), depth)
        if not p["solid"] and p["class"] == "Part":
            self.prop("bool", "CanCollide", "false", depth)
            self.prop("bool", "CanQuery", "false", depth)
            self.prop("bool", "CanTouch", "false", depth)
        for kind, name, value in p["extra"]:
            self.prop(kind, name, value, depth)
        self.end_props(depth)
        self.close(depth)

    def write_folder(self, name, parts, depth):
        self.open("Folder", depth)
        self.prop("string", "Name", name, depth)
        self.end_props(depth)
        for p in parts:
            self.write_part(p, depth + 1)
        self.close(depth)


def write_model(parts):
    writer = Writer()
    writer.lines.append('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')
    writer.open("Model", 1)
    writer.prop("string", "Name", "Arena", 1)
    writer.end_props(1)
    for group in GROUPS:
        writer.write_folder(group, [p for p in parts if p["group"] == group], 2)
    writer.close(1)
    writer.lines.append("</roblox>")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(writer.lines) + "\n", encoding="utf-8", newline="\n")


def main():
    parts = build_parts()
    errors = validate(parts)
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
    print(f"{len(parts)} parts, {sum(p['class'] == 'SpawnLocation' for p in parts)} spawns: layout OK")
    if "--check" not in sys.argv:
        write_model(parts)
        print(f"wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
