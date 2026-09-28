local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local CROSSHAIR_COLOR = Color3.fromRGB(255, 255, 255)
local CAMERA_OFFSET = Vector3.new(1.75, 1, 0)

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
