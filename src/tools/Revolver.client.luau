local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local tool = script.Parent :: Tool
local fireRemote = ReplicatedStorage:WaitForChild("RevolverFire") :: RemoteEvent

local RANGE = 300
local MAX_AMMO = 6
local FIRE_INTERVAL = 0.45
local lastShotAt = -math.huge

local ammoGui = Instance.new("ScreenGui")
ammoGui.Name = "RevolverAmmo"
ammoGui.ResetOnSpawn = false
ammoGui.Enabled = false
ammoGui.Parent = player:WaitForChild("PlayerGui")

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Name = "Ammo"
ammoLabel.AnchorPoint = Vector2.new(0.5, 1)
ammoLabel.Position = UDim2.new(0.5, 0, 1, -70)
ammoLabel.Size = UDim2.fromOffset(160, 36)
ammoLabel.BackgroundTransparency = 1
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextSize = 24
ammoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ammoLabel.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
ammoLabel.TextStrokeTransparency = 0.25
ammoLabel.Parent = ammoGui

local function updateAmmo()
	if tool:GetAttribute("Reloading") == true then
		ammoLabel.Text = "RELOADING"
		return
	end

	local ammo = tool:GetAttribute("Ammo")
	local count = if typeof(ammo) == "number" then ammo else MAX_AMMO
	ammoLabel.Text = `{count} / {MAX_AMMO}`
end

tool:GetAttributeChangedSignal("Ammo"):Connect(updateAmmo)
tool:GetAttributeChangedSignal("Reloading"):Connect(updateAmmo)
updateAmmo()

tool.Equipped:Connect(function()
	updateAmmo()
	ammoGui.Enabled = true
end)

tool.Unequipped:Connect(function()
	ammoGui.Enabled = false
end)

if tool.Parent == player.Character then
	ammoGui.Enabled = true
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
	fireRemote:FireServer(tool, aimPoint)
end)

tool.Destroying:Connect(function()
	ammoGui:Destroy()
end)
