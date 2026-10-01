# Simplified cartoon artwork

Created with the built-in imagegen tool on 2026-09-30, using
`heavy-hitter-art.png` as the edit target. Saved as `heavy-hitter-cartoon.png`.
The original edit target is retained in Git history.

## Original cartoon prompt

Use case: style-transfer. Edit target: the supplied revolver illustration used in the artwork window of a Roblox upgrade card. Keep one western revolver as the subject, with brown grip and barrel pointing to the upper right, fully inside the image. Redesign it to match a colorful, simple, friendly cartoon game: chunky toy-like proportions, large clean shapes, smooth blue-gray gunmetal, warm orange-brown grip, thick tidy dark outlines and only two or three flat cel-shaded tones per surface. Replace the detailed fiery painterly backdrop with a clean light sky-blue background and one simple orange/yellow comic impact burst behind the weapon. A few large graphic rays, ample empty space, no tiny particles, distressed paint, scratches, smoke, realistic metallic reflections or intricate details. Crisp polished game icon illustration that reads clearly at small sizes, landscape 4:3 composition. No text, borders, numbers, logos, people, hands or extra weapons. This is the inset illustration only, not an entire card.

## Orange card-color revision

Edited with the built-in imagegen tool on 2026-09-30. Replaced the sky-blue
background with the Heavy Hitter card's orange accent (`#F77B39`), preserving
the revolver and comic burst. The revised source replaces
`heavy-hitter-cartoon.png`. The uploaded revision uses image ID
`103713376246452`, configured in `UpgradeCardModel.luau`.

### Complete edit prompt

```text
Use case: precise-object-edit.
Asset type: Heavy Hitter artwork inset for an existing Roblox upgrade card.
Input image 1: edit target, the current Heavy Hitter cartoon revolver illustration.
Primary request: recolor only the background to match the orange Heavy Hitter card accent, RGB (247, 123, 57), hex #F77B39. Replace the sky-blue backdrop with a clean warm saturated orange backdrop. Keep the yellow/orange comic impact burst and its broad rays visible against the orange background; use the existing bright yellow center and slightly lighter golden-orange burst edges for clean contrast.
Invariants: preserve the exact western revolver, its blue-gray metal, warm brown grip, dark outlines, highlights, proportions, placement, angle and scale. Preserve the existing cartoon cel-shaded visual style and overall composition. Do not recolor the gun. Preserve the landscape 4:3 dimensions and framing.
Constraints: artwork only, no card border, text, lettering, numbers, logos, watermarks, additional props, people or hands. Opaque background. The result should look like the same image with its background changed to the card's orange rather than blue.
```
