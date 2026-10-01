local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local DashConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DashConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local e = React.createElement

type DashProgress = { charges: number, readyAt: number, rechargeAt: number }
type AmmoProgress = { ammo: number, capacity: number, reloading: boolean }

local function readNumber(instance: Instance?, name: string): number
	local value = if instance then instance:GetAttribute(name) else nil
	return if typeof(value) == "number" then value else 0
end

local function equippedRevolver(character: Model?): Tool?
	local tool = if character then character:FindFirstChild("Revolver") else nil
	return if tool and tool:IsA("Tool") then tool else nil
end

local function readAmmo(tool: Tool?): AmmoProgress
	if not tool then
		return { ammo = UpgradeConfig.BASE_AMMO, capacity = UpgradeConfig.BASE_AMMO, reloading = false }
	end
	local capacity = tool:GetAttribute("MaxAmmo")
	if typeof(capacity) ~= "number" then capacity = UpgradeConfig.BASE_AMMO end
	local ammo = tool:GetAttribute("Ammo")
	if typeof(ammo) ~= "number" then ammo = capacity end
	return {
		ammo = math.clamp(math.floor(ammo), 0, capacity),
		capacity = capacity,
		reloading = tool:GetAttribute("Reloading") == true,
	}
end

return function(props: { player: Player })
	local character, setCharacter = React.useState(props.player.Character)
	local tool, setTool = React.useState(equippedRevolver(props.player.Character))
	local dash, setDash = React.useState({ charges = 0, readyAt = 0, rechargeAt = 0 } :: DashProgress)
	local ammo, setAmmo = React.useState(readAmmo(tool))
	local now, setNow = React.useState(workspace:GetServerTimeNow())

	React.useEffect(function()
		local added = props.player.CharacterAdded:Connect(setCharacter)
		local removing = props.player.CharacterRemoving:Connect(function() setCharacter(nil) end)
		setCharacter(props.player.Character)
		return function()
			added:Disconnect()
			removing:Disconnect()
		end
	end, { props.player })

	React.useEffect(function()
		local function updateTool()
			setTool(equippedRevolver(character))
		end
		local connections: { RBXScriptConnection } = {}
		if character then
			table.insert(connections, character.ChildAdded:Connect(updateTool))
			table.insert(connections, character.ChildRemoved:Connect(updateTool))
		end
		updateTool()
		return function()
			for _, connection in connections do connection:Disconnect() end
		end
	end, { character })

	React.useEffect(function()
		local function updateDash()
			setDash({
				charges = readNumber(character, "DashCharges"),
				readyAt = readNumber(character, "DashReadyAt"),
				rechargeAt = readNumber(character, "DashRechargeAt"),
			})
			setNow(workspace:GetServerTimeNow())
		end
		local connections: { RBXScriptConnection } = {}
		if character then
			for _, attribute in { "DashCharges", "DashReadyAt", "DashRechargeAt" } do
				table.insert(connections, character:GetAttributeChangedSignal(attribute):Connect(updateDash))
			end
		end
		updateDash()
		return function()
			for _, connection in connections do connection:Disconnect() end
		end
	end, { character })

	React.useEffect(function()
		local function updateAmmo()
			setAmmo(readAmmo(tool))
		end
		local connections: { RBXScriptConnection } = {}
		if tool then
			for _, attribute in { "Ammo", "MaxAmmo", "Reloading" } do
				table.insert(connections, tool:GetAttributeChangedSignal(attribute):Connect(updateAmmo))
			end
		end
		updateAmmo()
		return function()
			for _, connection in connections do connection:Disconnect() end
		end
	end, { tool })

	React.useEffect(function()
		local deadline = math.max(dash.readyAt, dash.rechargeAt)
		if deadline <= workspace:GetServerTimeNow() then return end
		local timer = task.spawn(function()
			repeat
				task.wait(0.1)
				setNow(workspace:GetServerTimeNow())
			until workspace:GetServerTimeNow() >= deadline
		end)
		return function()
			if coroutine.status(timer) ~= "dead" then task.cancel(timer) end
		end
	end, { dash.readyAt, dash.rechargeAt })

	local locked = now < dash.readyAt
	local remaining = math.max(0, dash.rechargeAt - now)
	local bars = {}
	for index = 1, DashConfig.MAX_CHARGES do
		local fill = if index <= dash.charges then 1
			elseif index == dash.charges + 1 and dash.rechargeAt > 0 then 1 - remaining / DashConfig.RECHARGE_TIME
			else 0
		bars[tostring(index)] = e("Frame", {
			Position = UDim2.fromOffset((index - 1) * 34, 0),
			Size = UDim2.fromOffset(28, 9),
			BackgroundColor3 = Theme.PaperShade,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Fill = e("Frame", {
				Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1),
				BackgroundColor3 = Theme.Cyan,
				BackgroundTransparency = if locked then 0.55 else 0,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			}),
		})
	end

	return e("ScreenGui", {
		Name = "CombatHud",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Panel = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16),
			Size = UDim2.fromOffset(198, 50),
			BackgroundColor3 = Theme.Paper,
			BorderSizePixel = 0,
			Visible = character ~= nil and (dash.charges > 0 or dash.rechargeAt > 0),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.Radius) }),
			Outline = e("UIStroke", { Color = Theme.Ink, Thickness = Theme.Border }),
			Divider = e("Frame", {
				Position = UDim2.fromOffset(80, 8),
				Size = UDim2.fromOffset(2, 34),
				BackgroundColor3 = Theme.PaperShade,
				BorderSizePixel = 0,
			}),
			AmmoLabel = e("TextLabel", {
				Position = UDim2.fromOffset(10, 5), Size = UDim2.fromOffset(63, 13),
				BackgroundTransparency = 1,
				FontFace = UIFonts.ExtraBold, Text = if ammo.reloading then "RELOAD" else "AMMO",
				TextColor3 = Theme.Muted, TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			AmmoCount = e("TextLabel", {
				Position = UDim2.fromOffset(10, 19), Size = UDim2.fromOffset(65, 25),
				BackgroundTransparency = 1,
				FontFace = UIFonts.ExtraBold,
				Text = if tool then `{ammo.ammo}/{ammo.capacity}` else "--/--",
				TextColor3 = if ammo.ammo == 0 then Theme.Danger else Theme.Ink,
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			DashLabel = e("TextLabel", {
				Position = UDim2.fromOffset(92, 5), Size = UDim2.fromOffset(96, 13),
				BackgroundTransparency = 1,
				FontFace = UIFonts.ExtraBold, Text = "DASH",
				TextColor3 = Theme.Ink, TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Charges = e("Frame", {
				Position = UDim2.fromOffset(92, 26), Size = UDim2.fromOffset(96, 9),
				BackgroundTransparency = 1,
			}, bars),
		}),
	})
end
