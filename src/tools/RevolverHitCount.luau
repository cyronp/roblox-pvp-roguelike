local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local getGradient = require(script.Parent:WaitForChild("StreakColors"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local e = React.createElement

type Props = { count: number }

local function HitCount(props: Props)
	local fireRef = React.useRef(nil)
	local gradientRef = React.useRef(nil)
	local onFire = props.count >= 9

	React.useEffect(function()
		local fire = fireRef.current
		local gradient = gradientRef.current
		if not onFire or not fire or not gradient then
			return
		end

		local tweens: { Tween } = {}
		local shimmer = TweenService:Create(
			gradient,
			TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Offset = Vector2.new(0, 0.18) }
		)
		table.insert(tweens, shimmer)
		shimmer:Play()
		-- Five reusable embers give the text a flame effect without particle assets or frame loops.
		for index, ember in fire:GetChildren() do
			if not ember:IsA("Frame") then
				continue
			end
			local x = (index - 1) * 11 + 4
			ember.Position = UDim2.fromOffset(x, 45)
			ember.BackgroundTransparency = 0.15
			local drift = if index % 2 == 0 then 7 else -7
			local tween = TweenService:Create(
				ember,
				TweenInfo.new(0.55 + index * 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, index * 0.08),
				{ Position = UDim2.fromOffset(x + drift, 5), BackgroundTransparency = 1, Rotation = 95 }
			)
			table.insert(tweens, tween)
			tween:Play()
		end

		return function()
			for _, tween in tweens do
				tween:Cancel()
				tween:Destroy()
			end
			gradient.Offset = Vector2.zero
		end
	end, { onFire })

	local embers = {}
	if onFire then
		for index = 1, 5 do
			embers[`Ember{index}`] = e("Frame", {
				Size = UDim2.fromOffset(3, 7),
				BackgroundColor3 = if index % 2 == 0 then Theme.GoldLight else Theme.Orange,
				BorderSizePixel = 0,
				Rotation = 45,
				ZIndex = 1,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			})
		end
	end

	return e("TextLabel", {
		Size = UDim2.fromOffset(52, 38),
		BackgroundTransparency = 1,
		FontFace = UIFonts.ExtraBold,
		Text = `{props.count}x`,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		ZIndex = 2,
	}, {
		Gradient = e("UIGradient", { ref = gradientRef, Color = getGradient(props.count), Rotation = 90 }),
		Stroke = e("UIStroke", { Color = Theme.Ink, Thickness = Theme.Border, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
		Fire = if onFire then e("Frame", {
			ref = fireRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(55, 60),
			BackgroundTransparency = 1,
			ZIndex = 1,
		}, embers) else nil,
	})
end

return HitCount
