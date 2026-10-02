local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local DashConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DashConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local WeaponPreview = require(script.Parent.WeaponPreview)
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
	local touch, setTouch = React.useState(UserInputService.TouchEnabled)
	local hudScale, setHudScale = React.useState(1)

	React.useEffect(function()
		local connection = UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
			setTouch(UserInputService.TouchEnabled)
		end)
		return function() connection:Disconnect() end
	end, {})

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
	end, { character or false })

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
	end, { character or false })

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
	end, { tool or false })

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
	bars.Layout = e("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for index = 1, DashConfig.MAX_CHARGES do
		local fill = if index <= dash.charges then 1
			elseif index == dash.charges + 1 and dash.rechargeAt > 0 then 1 - remaining / DashConfig.RECHARGE_TIME
			else 0
		bars[tostring(index)] = e("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1 / DashConfig.MAX_CHARGES, -5 * (DashConfig.MAX_CHARGES - 1) / DashConfig.MAX_CHARGES, 1, 0),
			BackgroundColor3 = Theme.CombatLine,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
		}, {
			Fill = e("Frame", {
				Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1),
				BackgroundColor3 = Theme.CombatText,
				BackgroundTransparency = if locked then 0.55 else 0,
				BorderSizePixel = 0,
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
		Bounds = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			[React.Change.AbsoluteSize] = function(frame: Frame)
				setHudScale(math.clamp(frame.AbsoluteSize.X / 900, 0.8, 1))
			end,
		}, {
			Panel = e("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				-- Keep clear of the XP dock and the touch jump/dash controls.
				Position = UDim2.new(1, -16, 1, -(if touch then 244 else Theme.BottomInset + Theme.ProgressHeight + 12)),
				Size = UDim2.fromOffset(268, 108),
				BackgroundColor3 = Theme.CombatSurface,
				BackgroundTransparency = 0.12,
				BorderSizePixel = 0,
				Visible = character ~= nil and (tool ~= nil or dash.charges > 0 or dash.rechargeAt > 0),
			}, {
				Scale = e("UIScale", { Scale = hudScale }),
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
				Outline = e("UIStroke", { Color = Theme.CombatLine, Thickness = 1, Transparency = 0.4 }),
				Weapon = e(WeaponPreview, { tool = tool }),
				AmmoCount = e("TextLabel", {
					Position = UDim2.fromOffset(158, 10), Size = UDim2.fromOffset(54, 40),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamMedium,
					Text = if tool then tostring(ammo.ammo) else "–",
					TextColor3 = Theme.CombatText, TextSize = 36,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				Capacity = e("TextLabel", {
					Position = UDim2.fromOffset(219, 26), Size = UDim2.fromOffset(36, 20),
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					Text = if tool then `/ {ammo.capacity}` else "/ –",
					TextColor3 = Theme.CombatMuted, TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				WeaponLabel = e("TextLabel", {
					Position = UDim2.fromOffset(158, 52), Size = UDim2.fromOffset(96, 13),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamMedium,
					Text = if not tool then "UNEQUIPPED" elseif ammo.reloading then "RELOADING" else "REVOLVER",
					TextColor3 = if ammo.reloading then Theme.CombatText else Theme.CombatMuted,
					TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right,
				}),
				Divider = e("Frame", {
					Position = UDim2.fromOffset(14, 76), Size = UDim2.new(1, -28, 0, 1),
					BackgroundColor3 = Theme.CombatLine, BackgroundTransparency = 0.5, BorderSizePixel = 0,
				}),
				DashLabel = e("TextLabel", {
					Position = UDim2.fromOffset(14, 85), Size = UDim2.fromOffset(38, 13),
					BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
					Text = "DASH", TextColor3 = Theme.CombatMuted, TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Charges = e("Frame", {
					Position = UDim2.fromOffset(60, 89), Size = UDim2.fromOffset(144, 5),
					BackgroundTransparency = 1,
				}, bars),
				KeyHint = e("TextLabel", {
					Position = UDim2.fromOffset(216, 84), Size = UDim2.fromOffset(38, 16),
					BackgroundTransparency = 1, Font = Enum.Font.Gotham,
					Text = "SHIFT", TextColor3 = Theme.CombatMuted, TextSize = 9,
					Visible = not touch,
				}),
			}),
		}),
	})
end
