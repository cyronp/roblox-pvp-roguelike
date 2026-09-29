local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local CROSSHAIR_COLOR = Color3.fromRGB(255, 255, 255)
local COOLDOWN_COLOR = Color3.fromRGB(180, 184, 190)
local COOLDOWN_DIAMETER = 44
local COOLDOWN_RADIUS = COOLDOWN_DIAMETER / 2
local COOLDOWN_SEGMENT_COUNT = 48
local CAMERA_OFFSET = Vector3.new(1.75, 1, 0)

-- Disabling the backpack also disables its inventory and tool-switching controls.
-- Retry during startup in case Roblox's core UI is still initializing.
task.spawn(function()
	for attempt = 1, 5 do
		local success, message = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if success then
			return
		end
		if attempt == 5 then
			warn(`Failed to hide the inventory: {message}`)
			return
		end
		task.wait(0.5)
	end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Crosshair"
screenGui.IgnoreGuiInset = true
screenGui.ScreenInsets = Enum.ScreenInsets.None
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = player:WaitForChild("PlayerGui")

local crosshair = Instance.new("Frame")
crosshair.Name = "Reticle"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(16, 16)
crosshair.BackgroundTransparency = 1
crosshair.Visible = false
crosshair.Parent = screenGui

local function addMark(name: string, x: number, y: number, width: number, height: number)
	local mark = Instance.new("Frame")
	mark.Name = name
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromOffset(x, y)
	mark.Size = UDim2.fromOffset(width, height)
	mark.BackgroundColor3 = CROSSHAIR_COLOR
	mark.BorderSizePixel = 0
	mark.Parent = crosshair

	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(25, 25, 25)
	outline.Thickness = 0.5
	outline.Parent = mark
end

addMark("Top", 8, 4, 1, 5)
addMark("Bottom", 8, 12, 1, 5)
addMark("Left", 4, 8, 5, 1)
addMark("Right", 12, 8, 5, 1)

local cooldownRing = Instance.new("Frame")
cooldownRing.Name = "ShotCooldown"
cooldownRing.AnchorPoint = Vector2.new(0.5, 0.5)
cooldownRing.Position = UDim2.fromOffset(8, 8)
cooldownRing.Size = UDim2.fromOffset(COOLDOWN_DIAMETER, COOLDOWN_DIAMETER)
cooldownRing.BackgroundTransparency = 1
cooldownRing.Visible = false
cooldownRing.Parent = crosshair

local cooldownCorner = Instance.new("UICorner")
cooldownCorner.CornerRadius = UDim.new(1, 0)
cooldownCorner.Parent = cooldownRing

local cooldownStroke = Instance.new("UIStroke")
cooldownStroke.Color = CROSSHAIR_COLOR
cooldownStroke.Thickness = 2
cooldownStroke.Transparency = 0.78
cooldownStroke.Parent = cooldownRing

local cooldownSegments: { Frame } = {}
for index = 1, COOLDOWN_SEGMENT_COUNT do
	local angle = -math.pi / 2 + (index - 0.5) * 2 * math.pi / COOLDOWN_SEGMENT_COUNT
	local segment = Instance.new("Frame")
	segment.Name = `Segment{index}`
	segment.AnchorPoint = Vector2.new(0.5, 0.5)
	segment.Position = UDim2.fromOffset(
		COOLDOWN_RADIUS + math.cos(angle) * COOLDOWN_RADIUS,
		COOLDOWN_RADIUS + math.sin(angle) * COOLDOWN_RADIUS
	)
	segment.Size = UDim2.fromOffset(3.3, 2.5)
	segment.Rotation = math.deg(angle) + 90
	segment.BackgroundColor3 = COOLDOWN_COLOR
	segment.BorderSizePixel = 0
	segment.Visible = false
	segment.Parent = cooldownRing
	cooldownSegments[index] = segment
end

local cooldownTip = Instance.new("Frame")
cooldownTip.Name = "ProgressTip"
cooldownTip.AnchorPoint = Vector2.new(0.5, 0.5)
cooldownTip.Size = UDim2.fromOffset(5, 5)
cooldownTip.BackgroundColor3 = COOLDOWN_COLOR
cooldownTip.BorderSizePixel = 0
cooldownTip.Parent = cooldownRing

local tipCorner = Instance.new("UICorner")
tipCorner.CornerRadius = UDim.new(1, 0)
tipCorner.Parent = cooldownTip

local visibleSegmentCount = 0

local function setVisibleSegments(count: number)
	for index = visibleSegmentCount + 1, count do
		cooldownSegments[index].Visible = true
	end
	for index = count + 1, visibleSegmentCount do
		cooldownSegments[index].Visible = false
	end
	visibleSegmentCount = count
end

local function updateCooldownRing()
	local endsAt = player:GetAttribute("RevolverCooldownEnd")
	local duration = player:GetAttribute("RevolverCooldownDuration")
	if typeof(endsAt) ~= "number" or typeof(duration) ~= "number" or duration <= 0 then
		cooldownRing.Visible = false
		return
	end

	local remaining = endsAt - os.clock()
	local character = player.Character
	if remaining <= 0 or not character or not character:FindFirstChild("Revolver") then
		cooldownRing.Visible = false
		return
	end

	cooldownRing.Visible = true
	local progress = math.clamp(1 - remaining / duration, 0, 1)
	setVisibleSegments(math.ceil(progress * COOLDOWN_SEGMENT_COUNT))
	local tipAngle = -math.pi / 2 + progress * 2 * math.pi
	cooldownTip.Position = UDim2.fromOffset(
		COOLDOWN_RADIUS + math.cos(tipAngle) * COOLDOWN_RADIUS,
		COOLDOWN_RADIUS + math.sin(tipAngle) * COOLDOWN_RADIUS
	)
end

local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil

local function onCharacterAdded(character: Model)
	local newHumanoid = character:WaitForChild("Humanoid") :: Humanoid
	local newRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	if player.Character ~= character then
		return
	end

	humanoid = newHumanoid
	rootPart = newRootPart
	newHumanoid.CameraOffset = CAMERA_OFFSET
	newHumanoid.AutoRotate = false
end

player.CharacterRemoving:Connect(function()
	humanoid = nil
	rootPart = nil
end)
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

RunService:BindToRenderStep("ThirdPersonAim", Enum.RenderPriority.Camera.Value + 1, function()
	local currentHumanoid = humanoid
	local currentRootPart = rootPart
	local active = currentHumanoid ~= nil and currentRootPart ~= nil and currentHumanoid.Health > 0
	local usingMenu = GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() ~= nil
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
	crosshair.Visible = active and not usingMenu
	if crosshair.Visible then
		updateCooldownRing()
	end

	if not active or usingMenu or not currentRootPart then
		UserInputService.MouseIconEnabled = true
		if not GuiService.MenuIsOpen then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		return
	end

	if UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local lookVector = camera.CFrame.LookVector
	local flatDirection = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatDirection.Magnitude > 0.001 then
		currentRootPart.CFrame = CFrame.lookAt(currentRootPart.Position, currentRootPart.Position + flatDirection)
	end
end)
