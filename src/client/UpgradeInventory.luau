local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local CardModel = require(script.Parent.UpgradeCardModel)
local CardFace = require(script.Parent.UpgradeCardFace)
local e = React.createElement

type Props = { levels: Config.Levels, width: number }

return function(props: Props)
	local owned = {}
	for _, card in Config.CARDS do
		if (props.levels[card.id] or 0) > 0 then
			table.insert(owned, card)
		end
	end
	local height = props.width * CardModel.Height / CardModel.Width
	local cards = {}
	for index, card in owned do
		local offset = index - (#owned + 1) / 2
		local rotation = if offset == 0 then 0 else (if offset < 0 then -12 else 12)
		cards[card.id] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, offset * props.width * 0.88, 1, if rotation == 0 then -5 else 0),
			Size = UDim2.fromOffset(props.width, height),
			Rotation = rotation,
			BackgroundTransparency = 1,
			Active = false,
			ZIndex = if rotation == 0 then 3 else 2,
		}, {
			Card = e(CardFace, {
				id = card.id,
				title = card.name,
				compact = true,
				buff = Config.getCardBuff(card.id, props.levels[card.id]),
			}),
			Level = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -5),
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Active = false,
				FontFace = UIFonts.ExtraBold,
				Text = `{props.levels[card.id]} LVL`,
				TextSize = 17,
				TextColor3 = CardModel.Styles[card.id].color,
				ZIndex = 4,
			}, {
				Stroke = e("UIStroke", { Color = Color3.fromRGB(20, 28, 43), Thickness = 1.5 }),
			}),
		})
	end
	return e("Frame", {
		Name = "OwnedUpgradeCards",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -42),
		Size = UDim2.fromOffset(props.width * 3.2, height + 40),
		BackgroundTransparency = 1,
		Active = false,
		Visible = #owned > 0,
	}, cards)
end
