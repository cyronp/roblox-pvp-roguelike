local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DashConfig"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local e = React.createElement
local AQUA = Color3.fromRGB(100, 224, 238)

local function readNumber(character: Model?, name: string): number
	local value = if character then character:GetAttribute(name) else nil
	return if typeof(value) == "number" then value else 0
end

return function(props: { player: Player })
	local character, setCharacter = React.useState(props.player.Character)
	local progress, setProgress = React.useState({ charges = 0, readyAt = 0, rechargeAt = 0 })
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	local touch, setTouch = React.useState(UserInputService.TouchEnabled)

	React.useEffect(function()
		local added = props.player.CharacterAdded:Connect(setCharacter)
		local removing = props.player.CharacterRemoving:Connect(function() setCharacter(nil) end)
		local input = UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
			setTouch(UserInputService.TouchEnabled)
		end)
		setCharacter(props.player.Character)
		return function()
			added:Disconnect()
			removing:Disconnect()
			input:Disconnect()
		end
	end, { props.player })

	React.useEffect(function()
		local function update()
			setProgress({
				charges = readNumber(character, "DashCharges"),
				readyAt = readNumber(character, "DashReadyAt"),
				rechargeAt = readNumber(character, "DashRechargeAt"),
			})
			setNow(workspace:GetServerTimeNow())
		end
		local connections: { RBXScriptConnection } = {}
		if character then
			for _, attribute in { "DashCharges", "DashReadyAt", "DashRechargeAt" } do
				table.insert(connections, character:GetAttributeChangedSignal(attribute):Connect(update))
			end
		end
		update()
		return function()
			for _, connection in connections do connection:Disconnect() end
		end
	end, { character })

	React.useEffect(function()
		local deadline = math.max(progress.readyAt, progress.rechargeAt)
		if deadline <= workspace:GetServerTimeNow() then return end
		-- Only tick while a displayed countdown is active; no per-frame HUD work.
		local timer = task.spawn(function()
			repeat
				task.wait(0.1)
				setNow(workspace:GetServerTimeNow())
			until workspace:GetServerTimeNow() >= deadline
		end)
		return function()
			if coroutine.status(timer) ~= "dead" then task.cancel(timer) end
		end
	end, { progress.readyAt, progress.rechargeAt })

	local cooldown = math.max(0, progress.readyAt - now)
	local reload = math.max(0, progress.rechargeAt - now)
	local status = if cooldown > 0 then string.format("%.1fs", cooldown)
		elseif progress.rechargeAt > 0 then string.format("+1 IN %.1fs", reload) else "READY"
	local pips = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index = 1, Config.MAX_CHARGES do
		local fraction = if index <= progress.charges then 1
			elseif index == progress.charges + 1 and progress.rechargeAt > 0 then 1 - reload / Config.RECHARGE_TIME else 0
		pips[tostring(index)] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(24, 5),
			BackgroundColor3 = Color3.fromRGB(32, 48, 58),
			BorderSizePixel = 0,
		}, {
			Fill = e("Frame", {
				Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
				BackgroundColor3 = AQUA,
				BackgroundTransparency = if cooldown > 0 then 0.45 else 0,
				BorderSizePixel = 0,
			}),
		})
	end

	return e("ScreenGui", {
		Name = "DashHud", ResetOnSpawn = false, DisplayOrder = 10,
		ScreenInsets = Enum.ScreenInsets.None,
	}, {
		Panel = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5, 48),
			Size = UDim2.fromOffset(110, 46),
			BackgroundTransparency = 1,
			Visible = character ~= nil and (progress.charges > 0 or progress.rechargeAt > 0),
		}, {
			Hint = e("TextLabel", {
				Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1,
				FontFace = UIFonts.Bold, Text = if touch then "DASH" else "SHIFT · DASH",
				TextSize = 12, TextColor3 = AQUA, TextStrokeTransparency = 0.3,
			}),
			Charges = e("Frame", {
				Position = UDim2.fromOffset(15, 20), Size = UDim2.fromOffset(80, 5), BackgroundTransparency = 1,
			}, pips),
			Status = e("TextLabel", {
				Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1,
				FontFace = UIFonts.Bold, Text = status, TextSize = 11,
				TextColor3 = Color3.fromRGB(216, 226, 232), TextStrokeTransparency = 0.3,
			}),
		}),
	})
end
