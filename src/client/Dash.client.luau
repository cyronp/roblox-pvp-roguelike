local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Dash") :: RemoteEvent
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DashConfig"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local DashEffects = require(script.Parent.DashEffects)
local effectsConnection = remote.OnClientEvent:Connect(DashEffects.play)
local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
local CombatHud = require(script.Parent.CombatHud)
local ACTION = "Dash"
local lastRequestAt = -math.huge

local function requestDash()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not humanoid or humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand
		or not root or not root:IsA("BasePart") or root.Anchored then return end
	local now = workspace:GetServerTimeNow()
	local charges = character:GetAttribute("DashCharges")
	local readyAt = character:GetAttribute("DashReadyAt")
	if typeof(charges) ~= "number" or charges <= 0 or typeof(readyAt) ~= "number" or now < readyAt then return end
	if now - lastRequestAt < Config.REQUEST_INTERVAL then return end
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then direction = root.CFrame.LookVector end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then return end
	lastRequestAt = now
	remote:FireServer(character, flat.Unit)
end

ContextActionService:BindActionAtPriority(ACTION, function(_, inputState: Enum.UserInputState)
	if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then requestDash() end
	return Enum.ContextActionResult.Sink
end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
ContextActionService:SetTitle(ACTION, "DASH")
ContextActionService:SetPosition(ACTION, UDim2.new(1, -160, 1, -160))

local function styleTouchButton()
	local button = ContextActionService:GetButton(ACTION)
	if not button or button:FindFirstChild("CombatCorner") then return end
	button.Image = ""
	button.BackgroundColor3 = Theme.CombatSurface
	button.BackgroundTransparency = 0.12
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(64, 64)
	local corner = Instance.new("UICorner")
	corner.Name = "CombatCorner"
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	local outline = Instance.new("UIStroke")
	outline.Color = Theme.CombatLine
	outline.Thickness = 1
	outline.Parent = button
	for _, child in button:GetDescendants() do
		if child:IsA("TextLabel") then
			child.Font = Enum.Font.GothamMedium
			child.TextColor3 = Theme.CombatText
			child.TextStrokeTransparency = 1
			child.TextSize = 14
		end
	end
end

styleTouchButton()
local touchConnection = UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(styleTouchButton)

local hudContainer = Instance.new("Folder")
hudContainer.Name = "CombatHudRoot"
local hudRoot = ReactRoblox.createRoot(hudContainer)
hudRoot:render(ReactRoblox.createPortal(
	React.createElement(CombatHud, { player = player }), player:WaitForChild("PlayerGui")
))

script.Destroying:Connect(function()
	effectsConnection:Disconnect()
	DashEffects.destroy()
	touchConnection:Disconnect()
	ContextActionService:UnbindAction(ACTION)
	hudRoot:unmount()
	hudContainer:Destroy()
end)
