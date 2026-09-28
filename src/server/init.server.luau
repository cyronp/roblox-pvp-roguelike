local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local fireRemote = ReplicatedStorage:WaitForChild("RevolverFire") :: RemoteEvent
local revolverTemplate = ServerStorage:WaitForChild("Revolver") :: Tool

local DAMAGE = 35
local RANGE = 300
local MAX_AMMO = 6
local FIRE_INTERVAL = 0.45
local RELOAD_TIME = 1.8

type RevolverState = {
	ammo: number,
	reloading: boolean,
	lastShotAt: number,
}

local states: { [Tool]: RevolverState? } = {}

local function addPiece(handle: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Color = color
	piece.Material = Enum.Material.Metal
	piece.Shape = shape or Enum.PartType.Block
	piece.CFrame = handle.CFrame * offset
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.Massless = true
	piece.Parent = handle.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.Parent = piece
end

local steel = Color3.fromRGB(61, 65, 71)
local darkSteel = Color3.fromRGB(35, 38, 43)

local function prepareRevolver(tool: Tool)
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end
	if handle:FindFirstChild("Muzzle") then
		return
	end

	addPiece(handle, "Frame", Vector3.new(0.48, 0.32, 0.75), CFrame.new(0, 0.56, -0.24), steel)
	addPiece(handle, "Cylinder", Vector3.new(0.52, 0.43, 0.43), CFrame.new(0, 0.52, -0.48), darkSteel, Enum.PartType.Cylinder)
	addPiece(handle, "Barrel", Vector3.new(0.27, 0.27, 1.05), CFrame.new(0, 0.59, -1.15), steel)
	addPiece(handle, "FrontSight", Vector3.new(0.08, 0.12, 0.1), CFrame.new(0, 0.79, -1.6), darkSteel)
	addPiece(handle, "Hammer", Vector3.new(0.2, 0.16, 0.2), CFrame.new(0, 0.78, 0.16), darkSteel)
	addPiece(handle, "TriggerGuard", Vector3.new(0.06, 0.12, 0.45), CFrame.new(0, 0.12, -0.2), darkSteel)

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.59, -1.7)
	muzzle.Parent = handle

	if tool:GetAttribute("Ammo") == nil then
		tool:SetAttribute("Ammo", MAX_AMMO)
		tool:SetAttribute("Reloading", false)
	end
end

prepareRevolver(revolverTemplate)

local function watchTools(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child.Name == "Revolver" then
			prepareRevolver(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Revolver" then
			prepareRevolver(child)
		end
	end)
end

local function equipRevolver(player: Player, character: Model, humanoid: Humanoid, backpack: Instance, tool: Tool): boolean
	humanoid:EquipTool(tool)
	RunService.Heartbeat:Wait()
	if tool.Parent == backpack and player.Character == character and humanoid.Health > 0 then
		humanoid:EquipTool(tool)
	end
	RunService.Heartbeat:Wait()
	if tool.Parent == backpack and player.Character == character and humanoid.Health > 0 then
		tool.Parent = character
	end
	return tool.Parent == character
end

local function onPlayerAdded(player: Player)
	local lastCharacter: Model? = nil
	local function onCharacterAdded(character: Model)
		if lastCharacter == character then
			return
		end
		lastCharacter = character
		watchTools(character)
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 10)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			local backpack = player:WaitForChild("Backpack", 10)
			if not humanoid or not humanoid:IsA("Humanoid") or not root or not backpack then
				return
			end

			while player.Character == character and not character:IsDescendantOf(workspace) do
				character.AncestryChanged:Wait()
			end
			RunService.Heartbeat:Wait()
			if player.Character ~= character or humanoid.Health <= 0 then
				return
			end
			local equipped = character:FindFirstChild("Revolver")
			if equipped and equipped:IsA("Tool") then
				return
			end

			local backpackTool = backpack:FindFirstChild("Revolver")
			local tool: Tool
			if backpackTool and backpackTool:IsA("Tool") then
				tool = backpackTool
			else
				tool = revolverTemplate:Clone() :: Tool
				tool.Parent = backpack
			end
			prepareRevolver(tool)
			equipRevolver(player, character, humanoid, backpack, tool)
		end)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
	watchTools(player:WaitForChild("Backpack"))
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

local function getState(tool: Tool): RevolverState
	local state = states[tool]
	if state then
		return state
	end

	local newState: RevolverState = { ammo = MAX_AMMO, reloading = false, lastShotAt = -math.huge }
	states[tool] = newState
	tool.Destroying:Connect(function()
		states[tool] = nil
	end)
	tool:SetAttribute("Ammo", MAX_AMMO)
	tool:SetAttribute("Reloading", false)
	return newState
end

local function startReload(tool: Tool, state: RevolverState)
	if state.reloading or state.ammo == MAX_AMMO then
		return
	end

	state.reloading = true
	tool:SetAttribute("Reloading", true)
	task.delay(RELOAD_TIME, function()
		if tool.Parent == nil then
			return
		end

		state.ammo = MAX_AMMO
		state.reloading = false
		tool:SetAttribute("Ammo", MAX_AMMO)
		tool:SetAttribute("Reloading", false)
	end)
end

local function showShot(origin: Vector3, hitPosition: Vector3)
	local distance = (hitPosition - origin).Magnitude
	if distance < 0.1 then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Name = "RevolverTracer"
	tracer.Size = Vector3.new(0.05, 0.05, distance)
	tracer.CFrame = CFrame.lookAt(origin, hitPosition) * CFrame.new(0, 0, -distance / 2)
	tracer.Color = Color3.fromRGB(255, 225, 140)
	tracer.Material = Enum.Material.Neon
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.Parent = workspace
	Debris:AddItem(tracer, 0.08)

	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.35, 0.35, 0.35)
	flash.CFrame = CFrame.new(origin)
	flash.Color = Color3.fromRGB(255, 202, 92)
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.Parent = workspace
	Debris:AddItem(flash, 0.07)
end

fireRemote.OnServerEvent:Connect(function(player: Player, tool: unknown, aimPoint: unknown)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") or tool.Name ~= "Revolver" then
		return
	end
	if typeof(aimPoint) ~= "Vector3" then
		return
	end
	if aimPoint.X ~= aimPoint.X or aimPoint.Y ~= aimPoint.Y or aimPoint.Z ~= aimPoint.Z then
		return
	end
	if math.abs(aimPoint.X) > 100000 or math.abs(aimPoint.Y) > 100000 or math.abs(aimPoint.Z) > 100000 then
		return
	end

	local character = player.Character
	if not character or tool.Parent ~= character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	local toolHandle = tool:FindFirstChild("Handle")
	if not humanoid or humanoid.Health <= 0 or not head or not head:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return
	end
	if not toolHandle or not toolHandle:IsA("BasePart") then
		return
	end
	local toolMuzzle = toolHandle:FindFirstChild("Muzzle")
	if not toolMuzzle or not toolMuzzle:IsA("Attachment") then
		return
	end

	local aimDirection = aimPoint - head.Position
	if aimDirection.Magnitude < 0.1 or aimDirection.Magnitude > RANGE + 12 then
		return
	end
	local horizontalAim = Vector3.new(aimDirection.X, 0, aimDirection.Z)
	if horizontalAim.Magnitude > 1 and root.CFrame.LookVector:Dot(horizontalAim.Unit) < -0.25 then
		return
	end

	local origin = toolMuzzle.WorldPosition
	if (origin - head.Position).Magnitude > 8 then
		return
	end

	local shotDirection = aimPoint - origin
	if shotDirection.Magnitude < 0.1 then
		return
	end

	local state = getState(tool)
	if state.reloading then
		return
	end
	if state.ammo == 0 then
		startReload(tool, state)
		return
	end

	local now = os.clock()
	if now - state.lastShotAt < FIRE_INTERVAL then
		return
	end

	state.lastShotAt = now
	state.ammo -= 1
	tool:SetAttribute("Ammo", state.ammo)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	local rayDirection = shotDirection.Unit * RANGE
	local result = workspace:Raycast(origin, rayDirection, raycastParams)
	local hitPosition = if result then result.Position else origin + rayDirection
	showShot(origin, hitPosition)

	if result then
		local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
		local targetHumanoid = if hitModel then hitModel:FindFirstChildOfClass("Humanoid") else nil
		if targetHumanoid and targetHumanoid ~= humanoid and targetHumanoid.Health > 0 then
			targetHumanoid:TakeDamage(DAMAGE)
		end
	end

	if state.ammo == 0 then
		task.delay(FIRE_INTERVAL, function()
			if tool.Parent then
				startReload(tool, state)
			end
		end)
	end
end)
