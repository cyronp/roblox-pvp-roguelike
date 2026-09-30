local Projection = require("../src/client/UpgradeCardProjection")

local function close(actual: number, expected: number)
	assert(math.abs(actual - expected) < 0.00001, `{actual} does not match {expected}`)
end

for _, angle in { 0, math.pi * 2 } do
	local rect = Projection.rect(0.5, 0.3785, 0.826, 0.409, angle)
	close(rect.x, 0.5)
	close(rect.y, 0.3785)
	close(rect.width, 0.826)
	close(rect.height, 0.409)
	assert(rect.visible, "Front content must return to its original alignment after one turn")
end
for _, angle in { math.pi / 2, math.pi, math.pi * 1.5 } do
	assert(not Projection.rect(0.5, 0.3785, 0.826, 0.409, angle).visible,
		"Front artwork must not appear on the edge or back")
end
local tilted = Projection.rect(0.5, 0.3785, 0.826, 0.409, math.pi / 3)
assert(tilted.visible and tilted.width < 0.5, "Artwork must narrow during the horizontal spin")
assert(math.abs(tilted.height - 0.409) < 0.01, "A horizontal spin must preserve the center's vertical scale")
for degree = 0, 360 do
	local rect = Projection.rect(0.5, 0.703, 0.81, 0.154, math.rad(degree))
	assert(rect.width >= 0 and rect.width < 2 and rect.height > 0 and rect.height < 1)
	assert(rect.x == rect.x and rect.y == rect.y, "Projection must stay finite throughout the turn")
end
print("PASS: horizontal Y-axis projection, foreshortening, edge/back visibility, and full-turn alignment")
