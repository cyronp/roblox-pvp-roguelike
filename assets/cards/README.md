# Editable 3D upgrade card

Open `assets/cards.blend` in Blender. The sample is **Heavy Hitter**, with original
cartoon revolver artwork, an editable title, a large bold description, and a buff.
The card has a rounded solid body, a bright recolorable face, a light description
panel, and simple borders and buff panel that automatically use a darker shade
of the face color. The former small labels, level badge, pips, gold trim, and corner
ornaments have been removed. The original viewing angle is preserved.
The title has a dark outline linked to the ink color. The larger description is
centered inside its panel, and the buff value and label share a font size and
baseline, with the combined phrase centered in its box. Content edits preserve
this alignment; the title outline follows title changes automatically.
Earlier Blender versions and the original detailed illustration are retained in
Git history rather than the working tree.

## Edit in Blender

1. Open the **Scripting** workspace. In the Text Editor dropdown, select the
   embedded **CardControls.py**, then click **Run Script** (or Alt+P with the cursor
   in the editor). This registers the controls for the current Blender session.
2. Return to **Layout**, press **N** in the 3D viewport, and open **Upgrade Card**.
3. Change the accent, description panel, or ink color. Colors update immediately.
   The borders, body, and buff panel follow the accent automatically. Use
   **Border brightness** to adjust how much darker they appear.
   Damage, Ammo, FireRate, Health, and Reload buttons provide accent presets.
4. Edit Title, Description, Buff, BuffLabel, or Artwork, then
   click **Apply text and artwork**. Type `\n` in Description for a line break.
   Short descriptions of two lines work best. Preset buttons change colors only.
5. Save the blend file. Render with **F12**; materials are visible in Material
   Preview or Rendered viewport mode.

All colors are also available on the **Card_Controls** object under
**Object Properties > Custom Properties**, without running the sidebar script.
Material drivers link those color pickers to the model. The artwork is a separate
image material, so changing the frame color preserves the illustration. Title,
description, and buff remain editable Blender Text objects.

The Artwork path defaults to `//cards/heavy-hitter-cartoon.png`, relative to the blend
file. Replacement images are packed into the blend file and cropped to fill the
artwork window without stretching. Fonts are also packed, so the finished blend
does not require the Windows font files to remain installed.

## Files

- `card-preview.png`: rendered sample with readable front content and visible depth.
- `card-green-preview.png`: the same model rendered with the Health accent preset.
- `card-shell.fbx`: mesh geometry and colorable sections, without baked text/art.
- `card-complete.glb`: the complete sample, including text geometry and artwork.
- `card-config.json`: source content and palette for rebuilding the sample.
- `heavy-hitter-cartoon.png`: revised Heavy Hitter illustration with its orange card-color background.
- `extra-round-cartoon.png`: extra ammo illustration with a cylinder and one additional cartridge.
- `quick-trigger-cartoon.png`: faster firing illustration with a revolver and lightning bolt.
- `vitality-cartoon.png`: healing illustration with a heart and protective shield.
- `fast-hands-cartoon.png`: faster reloading illustration with a gloved hand and speedloader.
- `artwork-cartoon-prompt.md`: current image-generation provenance and prompt.
- `artwork-prompt.md`: original image-generation provenance and prompt.
- `artwork-upgrades-prompts.md`: generation prompts and upload notes for the four remaining upgrades.

In Roblox, import through Studio's 3D Importer. The shell is intended for reusable
cards with runtime text/image UI; its separately named MeshParts can be recolored.
To reproduce the linked border effect in Roblox, apply the main color to
`Card_Colored_Face` and `Card_Back_Face`, and a darker version to `Card_Body`,
`Card_Outer_Border`, `Card_Artwork_Frame`, and `Card_Buff_Panel`.
The complete GLB is a static sample with its current lettering converted to meshes
during export. Blender drivers and its sidebar do not transfer into Roblox.
`UpgradeCard.rbxm` is the Studio-imported shell (model ID `83993627838046`).
Rojo maps it to `ReplicatedStorage.Assets.UpgradeCard`. The game clones this
model into ViewportFrames and overlays runtime text and each card's uploaded
illustration. Each upgrade recolors the named parts, keeping its border
darker than its center. The front-facing HUD camera keeps the overlay aligned;
the whole card slides, scales, tilts, and fades during entrance and selection.
Each upgrade's style includes its own uploaded image ID; `UpgradeCardFace.luau`
uses that image in both the choice row and owned inventory. Heavy Hitter uses
`103713376246452`, Extra Round `108344419348133`, Quick Trigger `104341592990847`,
Vitality `79870903578934`, and Fast Hands `110052819157016`. Change visuals in
`src/client/UpgradeCardModel.luau`; no separate colored uploads are required.

Heavy Hitter's uploaded illustration uses its orange card color as the background.

Exports represent the default sample at build time. After manual edits, export
again with the studio collection excluded. For the reusable shell, select only
the mesh objects in `01_Card_Geometry`; for the full card, also select the text and
artwork collections. Use FBX or glTF/GLB with **Selected Objects** enabled.

## Rebuild and validate

From the repository root in PowerShell:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background assets/cards.blend --python-exit-code 1 --python tools/build_card.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background assets/cards.blend --python-exit-code 1 --python tools/validate_card.py
```

Rebuilding regenerates the card from `card-config.json`, replacing the builder's
card/studio collections. It does not preserve manual edits inside those collections.
The color renderer can produce a variant without changing the saved blend:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background assets/cards.blend --python-exit-code 1 --python tools/card_controls.py -- --theme Health --render assets/cards/card-green-preview.png
```
