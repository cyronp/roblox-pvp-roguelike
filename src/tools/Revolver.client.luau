local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local tool = script.Parent :: Tool
local fireRemote = ReplicatedStorage:WaitForChild("RevolverFire") :: RemoteEvent
local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
local AmmoHud = require(tool:WaitForChild("AmmoHud"))

local RANGE = 300
local FIRE_INTERVAL = 0.7
local lastShotAt = -math.huge

player:SetAttribute("RevolverCooldownDuration", FIRE_INTERVAL)

local reticle = player:WaitForChild("PlayerGui"):WaitForChild("Crosshair"):WaitForChild("Reticle")
local ammoContainer = Instance.new("Frame")
ammoContainer.Name = "RevolverAmmo"
ammoContainer.Size = UDim2.fromScale(1, 1)
ammoContainer.BackgroundTransparency = 1
ammoContainer.Visible = false
ammoContainer.Parent = reticle

local ammoRoot = ReactRoblox.createRoot(ammoContainer)
ammoRoot:render(React.createElement(AmmoHud, { tool = tool }))

tool.Equipped:Connect(function()
	ammoContainer.Visible = true
end)

tool.Unequipped:Connect(function()
	ammoContainer.Visible = false
end)

if tool.Parent == player.Character then
	ammoContainer.Visible = true
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
	if now - lastShotAt < FIRE_INTERVAL then
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
	player:SetAttribute("RevolverCooldownEnd", now + FIRE_INTERVAL)
	fireRemote:FireServer(tool, aimPoint)
end)

tool.Destroying:Connect(function()
	ammoRoot:unmount()
	ammoContainer:Destroy()
end)
