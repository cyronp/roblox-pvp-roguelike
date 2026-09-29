local MAX_HEALTH = 100
local RESPAWN_DELAY = 3
local DISTANCE_FROM_SPAWN = 24
local BODY_COLOR = Color3.fromRGB(218, 133, 68)
local LIMB_COLOR = Color3.fromRGB(61, 70, 83)

local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local spawnPosition = if spawnLocation then spawnLocation.Position else Vector3.zero
local forward = if spawnLocation then spawnLocation.CFrame.LookVector else Vector3.new(0, 0, -1)
forward = Vector3.new(forward.X, 0, forward.Z)
forward = if forward.Magnitude > 0.001 then forward.Unit else Vector3.new(0, 0, -1)

local targetPosition = spawnPosition + forward * DISTANCE_FROM_SPAWN
local ground = workspace:Raycast(targetPosition + Vector3.new(0, 64, 0), Vector3.new(0, -256, 0))
local groundHeight = if ground then ground.Position.Y else spawnPosition.Y
local rootPosition = Vector3.new(targetPosition.X, groundHeight + 3, targetPosition.Z)
local spawnCFrame = CFrame.lookAt(rootPosition, rootPosition - forward)

local currentDummy: Model? = nil
local respawnTask: thread? = nil
local stopped = false

local function addPart(model: Model, name: string, size: Vector3, offset: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = spawnCFrame * CFrame.new(offset)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.Parent = model
	return part
end

local function connectParts(name: string, parent: BasePart, child: BasePart)
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = parent
	joint.Part1 = child
	joint.C0 = parent.CFrame:ToObjectSpace(child.CFrame)
	joint.Parent = parent
end

local function spawnDummy()
	if stopped then
		return
	end

	local model = Instance.new("Model")
	model.Name = "TrainingDummy"

	local root = addPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, LIMB_COLOR)
	root.Anchored = true
	root.Transparency = 1
	root.CanQuery = false
	model.PrimaryPart = root

	local torso = addPart(model, "Torso", Vector3.new(2, 2, 1), Vector3.zero, BODY_COLOR)
	local head = addPart(model, "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), Color3.fromRGB(240, 201, 132))
	local leftArm = addPart(model, "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), LIMB_COLOR)
	local rightArm = addPart(model, "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), LIMB_COLOR)
	local leftLeg = addPart(model, "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), LIMB_COLOR)
	local rightLeg = addPart(model, "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), LIMB_COLOR)
	connectParts("RootJoint", root, torso)
	connectParts("Neck", torso, head)
	connectParts("Left Shoulder", torso, leftArm)
	connectParts("Right Shoulder", torso, rightArm)
	connectParts("Left Hip", torso, leftLeg)
	connectParts("Right Hip", torso, rightLeg)

	local target = addPart(model, "Target", Vector3.new(0.08, 1, 1), Vector3.new(0, 0, -0.55), Color3.fromRGB(250, 239, 208))
	target.Shape = Enum.PartType.Cylinder
	target.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
	connectParts("TargetMount", torso, target)

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = "Training Dummy"
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
	humanoid.NameDisplayDistance = 80
	humanoid.HealthDisplayDistance = 80
	humanoid.Parent = model

	humanoid.Died:Once(function()
		humanoid.DisplayName = "Respawning..."
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				child.Color = Color3.fromRGB(90, 94, 100)
				child.CanQuery = false
			end
		end
		respawnTask = task.delay(RESPAWN_DELAY, function()
			respawnTask = nil
			model:Destroy()
			currentDummy = nil
			spawnDummy()
		end)
	end)

	currentDummy = model
	-- Assemble the neck and limbs before the humanoid enters the world.
	model.Parent = workspace
end

script.Destroying:Connect(function()
	stopped = true
	if respawnTask then
		task.cancel(respawnTask)
	end
	if currentDummy then
		currentDummy:Destroy()
	end
end)

spawnDummy()
