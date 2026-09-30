local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local tool = script.Parent :: Tool
local fireRemote = ReplicatedStorage:WaitForChild("RevolverFire") :: RemoteEvent
local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
local AmmoHud = require(tool:WaitForChild("AmmoHud"))
local DamageHud = require(tool:WaitForChild("DamageHud"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))

local RANGE = 300
local lastShotAt = -math.huge

local reticle = player:WaitForChild("PlayerGui"):WaitForChild("Crosshair"):WaitForChild("Reticle")
local hudContainer = Instance.new("Frame")
hudContainer.Name = "RevolverHud"
hudContainer.Size = UDim2.fromScale(1, 1)
hudContainer.BackgroundTransparency = 1
hudContainer.Visible = false
hudContainer.Parent = reticle

local hudRoot = ReactRoblox.createRoot(hudContainer)
hudRoot:render(React.createElement(React.Fragment, nil, {
	Ammo = React.createElement(AmmoHud, { tool = tool }),
	Damage = React.createElement(DamageHud, { tool = tool }),
}))

tool.Equipped:Connect(function()
	hudContainer.Visible = true
end)

tool.Unequipped:Connect(function()
	hudContainer.Visible = false
end)

if tool.Parent == player.Character then
	hudContainer.Visible = true
end

tool.Activated:Connect(function()
	if tool.Parent ~= player.Character or tool:GetAttribute("Reloading") == true then
		return
	end
	local ammo = tool:GetAttribute("Ammo")
	if typeof(ammo) == "number" and ammo <= 0 then
		return
	end

	local now = os.clock()
	local interval = tool:GetAttribute("FireInterval")
	local fireInterval = if typeof(interval) == "number" then interval else UpgradeConfig.BASE_FIRE_INTERVAL
	if now - lastShotAt < fireInterval then
		return
	end

	local camera = workspace.CurrentCamera
	local character = player.Character
	if not camera or not character then
		return
	end

	local center = camera.ViewportSize / 2
	local aimRay = camera:ViewportPointToRay(center.X, center.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(aimRay.Origin, aimRay.Direction * RANGE, raycastParams)
	local aimPoint = if result then result.Position else aimRay.Origin + aimRay.Direction * RANGE

	lastShotAt = now
	player:SetAttribute("RevolverCooldownDuration", fireInterval)
	player:SetAttribute("RevolverCooldownEnd", now + fireInterval)
	fireRemote:FireServer(tool, aimPoint)
end)

tool.Destroying:Connect(function()
	hudRoot:unmount()
	hudContainer:Destroy()
end)
