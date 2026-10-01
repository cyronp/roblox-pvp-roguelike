local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local CardModel = require(script.Parent.UpgradeCardModel)
local Projection = require(script.Parent.UpgradeCardProjection)
local Offer = require(script.Parent.UpgradeOfferState)
local e = React.createElement
local INK = Color3.fromRGB(36, 51, 73)

local function project(angle, x: number, y: number, width: number, height: number)
	local bounds = angle:map(function(value: number)
		return Projection.rect(x, y, width, height, value)
	end)
	return {
		position = bounds:map(function(rect) return UDim2.fromScale(rect.x, rect.y) end),
		size = bounds:map(function(rect) return UDim2.fromScale(rect.width, rect.height) end),
		visible = bounds:map(function(rect) return rect.visible end),
	}
end

local function label(text: string, bounds, maxSize: number, color: Color3, fade, outline: number?)
	return e("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = bounds.position,
		Size = bounds.size,
		Visible = bounds.visible,
		BackgroundTransparency = 1,
		Active = false,
		FontFace = UIFonts.ExtraBold,
		Text = text,
		TextColor3 = color,
		TextTransparency = fade,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 3,
	}, {
		Bounds = e("UITextSizeConstraint", { MinTextSize = 4, MaxTextSize = maxSize }),
		Stroke = if outline then e("UIStroke", { Color = INK, Thickness = outline, Transparency = fade }) else nil,
	})
end

return function(props)
	local viewportRef = React.useRef(nil)
	local setCameraAngle = React.useRef(nil)
	local angle, setAngle = React.useBinding(0)
	local style = CardModel.Styles[props.id]
	local fade = props.fade or 0
	React.useEffect(function()
		local cleanup, updateCamera = CardModel.mount(viewportRef.current, style.color)
		setCameraAngle.current = updateCamera
		return cleanup
	end, { props.id })

	React.useEffect(function()
		if not props.spinning then
			return
		end
		local rotation = Instance.new("NumberValue")
		local connection = rotation.Changed:Connect(function(value: number)
			setCameraAngle.current(value)
			setAngle(value)
		end)
		-- A scalar angle preserves the full revolution; tweening two equivalent
		-- CFrames at 0 and 360 degrees would produce no rotation.
		local tween = TweenService:Create(rotation,
			TweenInfo.new(Offer.SELECTION_DURATION - 0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Value = math.pi * 2 })
		tween:Play()
		return function()
			tween:Cancel()
			tween:Destroy()
			connection:Disconnect()
			rotation:Destroy()
		end
	end, { props.spinning == true })

	local artwork = project(angle, 0.5, 0.3785, 0.826, 0.409)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
	}, {
		Shell = e("ViewportFrame", {
			ref = viewportRef,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ImageTransparency = fade,
			Active = false,
			Ambient = Color3.fromRGB(210, 210, 210),
			LightColor = Color3.fromRGB(255, 250, 240),
			LightDirection = Vector3.new(-1, -1, -2),
		}),
		-- Project each UI region onto the rotating front, hiding it on the back.
		Title = label(string.upper(props.title), project(angle, 0.5, 0.113, 0.81, 0.11), 22, Color3.new(1, 1, 1), fade, if props.compact then 0.65 else 1.2),
		Art = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = artwork.position,
			Size = artwork.size,
			Visible = artwork.visible,
			BackgroundColor3 = style.color,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
			Image = style.image,
			ImageTransparency = fade,
			ScaleType = if props.spinning then Enum.ScaleType.Stretch else Enum.ScaleType.Crop,
			Active = false,
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.055, 0) }),
		}),
		Description = label(style.description, project(angle, 0.5, 0.703, 0.81, 0.154), 19, INK, fade),
		Buff = label(props.buff or style.buff, project(angle, 0.5, 0.881, 0.81, 0.095), 21, Color3.new(1, 1, 1), fade),
	})
end
