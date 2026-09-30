local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local CardView = require(script.Parent.UpgradeCardView)
local UpgradeInventory = require(script.Parent.UpgradeInventory)
local useUpgradeOffer = require(script.Parent.useUpgradeOffer)
local e = React.createElement
local ACTION = "ChooseUpgradeCard"
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local KEY_HINTS = { "1", "1 / 2", "1 / 2 / 3" }

local function UpgradeHud()
	local state, choose = useUpgradeOffer()
	local viewportSize, setViewportSize = React.useState(Vector2.new(1280, 720))
	local touch, setTouch = React.useState(UserInputService.TouchEnabled)
	local snapshot = state.displayed
	local hasOffer = #snapshot.choices > 0
	local portrait = viewportSize.Y > viewportSize.X
	local availableWidth = math.min(520, viewportSize.X - 32, viewportSize.X * (if portrait then 0.94 else 0.46))
	local maxCardHeight = math.max(110, viewportSize.Y * 0.45 - (if touch then 70 else 40))
	local cardWidth = math.min((availableWidth - 20) / 3, maxCardHeight * 2.54 / 3.54)
	local cardHeight = cardWidth * 3.54 / 2.54
	local inventoryWidth = math.clamp(viewportSize.X * 0.075, 56, 88)
	local inventoryHeight = inventoryWidth * 3.54 / 2.54 + 40
	local choiceBottom = if touch then 160 else 36
	-- Stack the choice row above the fan only when they share horizontal space.
	if (hasOffer or Config.getOwnedCount(state.latest.levels) > 0)
		and 16 + cardWidth * 3 + 20 > viewportSize.X / 2 - inventoryWidth * 1.6 then
		choiceBottom = math.max(choiceBottom, inventoryHeight + 52)
	end
	cardWidth = math.min(cardWidth, math.max(80, viewportSize.Y - choiceBottom - 84) * 2.54 / 3.54)
	cardHeight = cardWidth * 3.54 / 2.54
	local hint = if touch then "TAP A NUMBER" else `PRESS {KEY_HINTS[#snapshot.choices] or ""}`
	local queueHint = if snapshot.pending > 1 then `  (+{snapshot.pending - 1} waiting)` else ""

	React.useEffect(function()
		local connection = UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
			setTouch(UserInputService.TouchEnabled)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		if not hasOffer then
			return
		end
		ContextActionService:BindActionAtPriority(ACTION, function(_, inputState: Enum.UserInputState, input: InputObject)
			if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Pass
			end
			local index = table.find(KEYS, input.KeyCode)
			if not index or not snapshot.choices[index] then
				return Enum.ContextActionResult.Pass
			end
			if inputState == Enum.UserInputState.Begin then
				choose(index)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, table.unpack(KEYS))
		return function()
			ContextActionService:UnbindAction(ACTION)
		end
	end, { hasOffer, snapshot.offerId, #snapshot.choices, choose })

	local cards = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, cardId in snapshot.choices do
		local card = Config.getCard(cardId)
		if card then
			cards[`{snapshot.offerId}_{cardId}`] = e(CardView, {
				id = cardId,
				title = card.name,
				index = index,
				width = cardWidth,
				mode = if state.selected then (if state.selected == cardId then "chosen" else "dismissed")
					else (if state.requested == cardId then "waiting" else "idle"),
				touch = touch,
				onChoose = choose,
			})
		end
	end

	return e("ScreenGui", {
		Name = "UpgradeHud",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Canvas = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Active = false,
			[React.Change.AbsoluteSize] = function(frame: Frame)
				setViewportSize(frame.AbsoluteSize)
			end,
		}, {
			Inventory = e(UpgradeInventory, { levels = state.latest.levels, width = inventoryWidth }),
			Choices = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16, 1, -choiceBottom),
				Size = UDim2.fromOffset(cardWidth * 3 + 20, cardHeight + 68),
				BackgroundTransparency = 1,
				Active = false,
				Visible = hasOffer,
			}, {
				Hint = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Active = false,
					FontFace = UIFonts.ExtraBold,
					Text = if state.selected then "UPGRADE ADDED!" elseif state.requested then "CHOOSING..." else `LEVEL UP!  {hint}{queueHint}`,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,
					TextStrokeTransparency = 0.15,
				}, {
					Bounds = e("UITextSizeConstraint", { MinTextSize = 9, MaxTextSize = 17 }),
				}),
				Cards = e("Frame", {
					Position = UDim2.fromOffset(0, 30),
					Size = UDim2.new(1, 0, 1, -30),
					BackgroundTransparency = 1,
					Active = false,
				}, cards),
			}),
		}),
	})
end

local hudContainer = Instance.new("Folder")
hudContainer.Name = "UpgradeHudRoot"
local hudRoot = ReactRoblox.createRoot(hudContainer)
hudRoot:render(ReactRoblox.createPortal(e(UpgradeHud), playerGui))

script.Destroying:Connect(function()
	ContextActionService:UnbindAction(ACTION)
	hudRoot:unmount()
	hudContainer:Destroy()
end)
