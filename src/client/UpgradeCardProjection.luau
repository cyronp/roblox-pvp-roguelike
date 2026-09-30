-- Match the viewport camera when projecting the editable front content.
local Projection = { Width = 2.54, Height = 3.54, FieldOfView = 12 }
local tangent = math.tan(math.rad(Projection.FieldOfView / 2))
Projection.Distance = Projection.Height / (2 * tangent) + 0.1

function Projection.rect(x: number, y: number, width: number, height: number, angle: number)
	local sine, cosine = math.sin(angle), math.cos(angle)
	local function projectX(normalizedX: number): number
		local localX = (normalizedX - 0.5) * Projection.Width
		local rotatedX = localX * cosine + 0.1 * sine
		local depth = -localX * sine + 0.1 * cosine
		local aspect = Projection.Width / Projection.Height
		return 0.5 + rotatedX / (2 * (Projection.Distance - depth) * tangent * aspect)
	end
	local left = projectX(x - width / 2)
	local right = projectX(x + width / 2)
	local centerDepth = -(x - 0.5) * Projection.Width * sine + 0.1 * cosine
	local perspective = (Projection.Distance - 0.1) / (Projection.Distance - centerDepth)
	return {
		x = (left + right) / 2,
		y = 0.5 + (y - 0.5) * perspective,
		width = math.abs(right - left),
		height = height * perspective,
		-- The real mesh shows its back; front UI disappears at the edge.
		visible = cosine > 0.08,
	}
end

return Projection
