local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Dash") :: RemoteEvent
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DashConfig"))
local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
local DashHud = require(script.Parent.DashHud)
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

local hudContainer = Instance.new("Folder")
hudContainer.Name = "DashHudRoot"
local hudRoot = ReactRoblox.createRoot(hudContainer)
hudRoot:render(ReactRoblox.createPortal(
	React.createElement(DashHud, { player = player }), player:WaitForChild("PlayerGui")
))

script.Destroying:Connect(function()
	ContextActionService:UnbindAction(ACTION)
	hudRoot:unmount()
	hudContainer:Destroy()
end)
