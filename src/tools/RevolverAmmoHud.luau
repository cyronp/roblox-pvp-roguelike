local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local StreakHud = require(script.Parent:WaitForChild("StreakHud"))
local e = React.createElement

local MAX_AMMO = 6
local GOLD = Color3.fromRGB(245, 185, 91)
local RELOAD_COLOR = Color3.fromRGB(180, 184, 190)
local EMPTY = Color3.fromRGB(255, 118, 105)
local TEXT = Color3.fromRGB(250, 247, 239)
local OUTLINE = Color3.fromRGB(16, 19, 24)

type Props = {
	tool: Tool,
}

local function readAmmo(tool: Tool): number
	local value = tool:GetAttribute("Ammo")
	if typeof(value) ~= "number" then
		return MAX_AMMO
	end
	return math.clamp(math.floor(value), 0, MAX_AMMO)
end

local function AmmoHud(props: Props)
	local ammo, setAmmo = React.useState(readAmmo(props.tool))
	local reloading, setReloading = React.useState(props.tool:GetAttribute("Reloading") == true)
	local countRef = React.useRef(nil)

	React.useEffect(function()
		local ammoConnection = props.tool:GetAttributeChangedSignal("Ammo"):Connect(function()
			setAmmo(readAmmo(props.tool))
		end)
		local reloadConnection = props.tool:GetAttributeChangedSignal("Reloading"):Connect(function()
			setReloading(props.tool:GetAttribute("Reloading") == true)
		end)
		-- Catch changes that arrived between the first render and subscribing.
		setAmmo(readAmmo(props.tool))
		setReloading(props.tool:GetAttribute("Reloading") == true)

		return function()
			ammoConnection:Disconnect()
			reloadConnection:Disconnect()
		end
	end, { props.tool })

	React.useEffect(function()
		local label = countRef.current
		if not reloading or not label then
			return
		end

		local pulse = TweenService:Create(
			label,
			TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ TextTransparency = 0.45 }
		)
		pulse:Play()

		return function()
			pulse:Cancel()
			pulse:Destroy()
			label.TextTransparency = 0
		end
	end, { reloading })

	local countColor = if reloading then RELOAD_COLOR elseif ammo == 0 then EMPTY elseif ammo <= 2 then GOLD else TEXT

	return e("Frame", {
		Name = "AmmoCount",
		AnchorPoint = Vector2.new(0, 0.5),
		-- Relative to the reticle so movement, visibility, and viewport changes stay in sync.
		Position = UDim2.new(0.5, 32, 0.5, 0),
		Size = UDim2.fromOffset(62, 24),
		BackgroundTransparency = 1,
	}, {
		Count = e("TextLabel", {
			ref = countRef,
			Size = UDim2.fromOffset(30, 24),
			BackgroundTransparency = 1,
			FontFace = UIFonts.Bold,
			Text = string.format("%02d", ammo),
			TextColor3 = countColor,
			TextSize = 20,
			TextStrokeColor3 = OUTLINE,
			TextStrokeTransparency = 0.3,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Separator = e("TextLabel", {
			Position = UDim2.fromOffset(30, 2),
			Size = UDim2.fromOffset(11, 22),
			BackgroundTransparency = 1,
			FontFace = UIFonts.Regular,
			Text = "/",
			TextColor3 = Color3.fromRGB(169, 176, 187),
			TextSize = 14,
			TextStrokeColor3 = OUTLINE,
			TextStrokeTransparency = 0.3,
		}),
		Capacity = e("TextLabel", {
			Position = UDim2.fromOffset(41, 3),
			Size = UDim2.fromOffset(21, 21),
			BackgroundTransparency = 1,
			FontFace = UIFonts.Regular,
			Text = string.format("%02d", MAX_AMMO),
			TextColor3 = Color3.fromRGB(204, 209, 217),
			TextSize = 13,
			TextStrokeColor3 = OUTLINE,
			TextStrokeTransparency = 0.3,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Streak = e(StreakHud, { tool = props.tool }),
	})
end

return AmmoHud
