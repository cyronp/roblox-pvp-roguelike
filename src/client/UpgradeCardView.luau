local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local CardModel = require(script.Parent.UpgradeCardModel)
local CardFace = require(script.Parent.UpgradeCardFace)
local Offer = require(script.Parent.UpgradeOfferState)
local e = React.createElement
local INK = Color3.fromRGB(36, 51, 73)

type Props = {
	id: string,
	title: string,
	index: number,
	width: number,
	mode: string,
	touch: boolean,
	onChoose: (number) -> (),
}

return function(props: Props)
	local groupRef = React.useRef(nil)
	local scaleRef = React.useRef(nil)
	local fadeValue = React.useRef(nil)
	local fade, setFade = React.useBinding(1)
	local entered = React.useRef(false)
	local style = CardModel.Styles[props.id]
	local height = props.width * CardModel.Height / CardModel.Width

	React.useEffect(function()
		-- Fade native UI directly to keep small text crisp and avoid an extra
		-- CanvasGroup render texture around each 3D viewport.
		local value = Instance.new("NumberValue")
		value.Value = 1
		fadeValue.current = value
		local connection = value.Changed:Connect(setFade)
		return function()
			connection:Disconnect()
			value:Destroy()
		end
	end, {})

	React.useEffect(function()
		local group = groupRef.current
		local scale = scaleRef.current
		local tweens: { Tween } = {}
		local function tween(target: Instance, info: TweenInfo, values)
			local animation = TweenService:Create(target, info, values)
			table.insert(tweens, animation)
			animation:Play()
		end
		local first = not entered.current
		entered.current = true
		if first then
			group.Position = UDim2.new(0.5, 0, 0.5, 64)
			group.Rotation = -10 + props.index * 2
			scale.Scale = 0.86
		end
		if props.mode == "chosen" then
			-- The card face handles its horizontal 3D spin while the whole card lifts away.
			tween(group, TweenInfo.new(Offer.SELECTION_DURATION - 0.06, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 0.5, -52),
				Rotation = 0,
			})
			tween(scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 })
			tween(fadeValue.current, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, Offer.SELECTION_DURATION - 0.26), { Value = 1 })
		elseif props.mode == "dismissed" then
			local exitInfo = TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(group, exitInfo, {
				Position = UDim2.new(0.5, 0, 0.5, 70),
				Rotation = 5,
			})
			tween(fadeValue.current, exitInfo, { Value = 1 })
			tween(scale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Scale = 0.82,
			})
		else
			local delay = if first then (props.index - 1) * 0.07 else 0
			tween(group, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay), {
				Position = UDim2.fromScale(0.5, 0.5), Rotation = 0,
			})
			tween(fadeValue.current, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay), { Value = 0 })
			tween(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay), {
				Scale = if props.mode == "waiting" then 1.04 else 1,
			})
		end
		return function()
			for _, animation in tweens do
				animation:Cancel()
				animation:Destroy()
			end
		end
	end, { props.mode })

	return e("Frame", {
		LayoutOrder = props.index,
		Size = UDim2.fromOffset(props.width, height + 38),
		BackgroundTransparency = 1,
		Active = false,
	}, {
		Animated = e("Frame", {
			ref = groupRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Active = false,
		}, {
			Scale = e("UIScale", { ref = scaleRef }),
			Face = e("Frame", {
				Size = UDim2.fromOffset(props.width, height),
				BackgroundTransparency = 1,
				Active = false,
			}, { Content = e(CardFace, { id = props.id, title = props.title, fade = fade, spinning = props.mode == "chosen" }) }),
			Key = e(if props.touch then "TextButton" else "TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromOffset(if props.touch then 64 else 38, 32),
				BackgroundColor3 = if props.mode == "chosen" then style.color else INK,
				BackgroundTransparency = fade,
				BorderSizePixel = 0,
				Active = props.touch,
				Selectable = false,
				FontFace = UIFonts.ExtraBold,
				Text = if props.mode == "chosen" then "✓" else tostring(props.index),
				TextSize = 21,
				TextColor3 = Color3.new(1, 1, 1),
				TextTransparency = fade,
				[React.Event.Activated] = if props.touch then function(_, input: InputObject)
					if input.UserInputType == Enum.UserInputType.Touch then
						props.onChoose(props.index)
					end
				end else nil,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 9) }),
			}),
		}),
	})
end
