-- Reusable pieces of the chunky cartoon HUD style, so every panel, meter, and
-- keycap shares the same outline weight, lip depth, and typography.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local e = React.createElement

local HudKit = {}

-- React props are open-ended tables of Instance properties.
type Props = { [any]: any }

local function merge(defaults: Props, overrides: Props?): Props
	local merged = table.clone(defaults)
	if overrides then
		for key, value in overrides do
			merged[key] = value
		end
	end
	return merged
end

-- Outlined display text. `stroke` is the outline thickness in pixels.
function HudKit.label(props: Props, stroke: number?, children: Props?)
	local content = merge({
		BackgroundTransparency = 1,
		Active = false,
		FontFace = UIFonts.Display,
		TextColor3 = Theme.Text,
	}, props)
	local kids = merge({
		Stroke = e("UIStroke", {
			Color = Theme.Outline,
			Thickness = stroke or 2,
			Transparency = props.TextTransparency,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),
	}, children)
	return e("TextLabel", content, kids)
end

type PanelProps = {
	position: UDim2,
	size: UDim2,
	anchor: Vector2?,
	visible: boolean?,
	scale: number?,
	radius: number?,
	gradient: ColorSequence?,
	lipColor: Color3?,
	children: Props?,
}

-- A rounded panel with a gradient face, thick outline, and a darker lip below.
-- The lip extends Theme.Lip pixels under `size`, so anchor with that in mind.
function HudKit.Panel(props: PanelProps)
	local radius = UDim.new(0, props.radius or Theme.PanelRadius)
	local body = merge({
		Corner = e("UICorner", { CornerRadius = radius }),
		Outline = e("UIStroke", {
			Color = Theme.Outline,
			Thickness = Theme.PanelBorder,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Gradient = e("UIGradient", { Color = props.gradient or Theme.SurfaceGradient, Rotation = 90 }),
	}, props.children)
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		Visible = props.visible,
		BackgroundTransparency = 1,
		Active = false,
	}, {
		Scale = if props.scale then e("UIScale", { Scale = props.scale }) else nil,
		Lip = e("Frame", {
			Position = UDim2.fromOffset(0, Theme.Lip),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = props.lipColor or Theme.SurfaceShadow,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = radius }),
			Outline = e("UIStroke", {
				Color = Theme.Outline,
				Thickness = Theme.PanelBorder,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.White,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, body),
	})
end

type MeterProps = {
	position: UDim2,
	size: UDim2,
	fraction: number,
	gradient: ColorSequence,
	fillRef: any?,
	radius: number?,
	fillTransparency: number?,
	visible: boolean?,
	children: Props?,
}

-- A dark outlined track with a glossy gradient fill. Pass `fillRef` to animate
-- the fill's Size yourself; otherwise it follows `fraction` directly.
function HudKit.Meter(props: MeterProps)
	local radius = UDim.new(0, props.radius or Theme.Radius)
	local track = merge({
		Corner = e("UICorner", { CornerRadius = radius }),
		Outline = e("UIStroke", {
			Color = Theme.Outline,
			Thickness = Theme.Border,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Fill = e("Frame", {
			ref = props.fillRef,
			-- A constant initial size keeps React from overriding the caller's tween.
			Size = if props.fillRef then UDim2.fromScale(0, 1) else UDim2.fromScale(math.clamp(props.fraction, 0, 1), 1),
			BackgroundColor3 = Theme.White,
			BackgroundTransparency = props.fillTransparency or 0,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = radius }),
			Gradient = e("UIGradient", { Color = props.gradient, Rotation = 90 }),
			Shine = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 3),
				Size = UDim2.new(1, -8, 0.22, 0),
				BackgroundColor3 = Theme.White,
				BackgroundTransparency = 0.55 + 0.45 * (props.fillTransparency or 0),
				BorderSizePixel = 0,
			}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		}),
	}, props.children)
	return e("Frame", {
		Position = props.position,
		Size = props.size,
		Visible = props.visible,
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
		Active = false,
	}, track)
end

type KeycapProps = {
	text: string,
	position: UDim2,
	size: UDim2,
	anchor: Vector2?,
	textSize: number?,
	visible: boolean?,
}

-- A small light keycap hint such as SHIFT, drawn with the same lip as panels.
function HudKit.Keycap(props: KeycapProps)
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		Visible = props.visible,
		BackgroundTransparency = 1,
		Active = false,
	}, {
		Lip = e("Frame", {
			Position = UDim2.fromOffset(0, 3),
			Size = UDim2.new(1, 0, 1, -3),
			BackgroundColor3 = Theme.PaperShade,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.SmallRadius) }),
			Outline = e("UIStroke", { Color = Theme.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
		Face = e("TextLabel", {
			Size = UDim2.new(1, 0, 1, -3),
			BackgroundColor3 = Theme.Paper,
			BorderSizePixel = 0,
			FontFace = UIFonts.Display,
			Text = props.text,
			TextColor3 = Theme.Ink,
			TextSize = props.textSize or 12,
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.SmallRadius) }),
			Outline = e("UIStroke", { Color = Theme.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
	})
end

return table.freeze(HudKit)
