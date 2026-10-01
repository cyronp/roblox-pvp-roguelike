local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DashConfig"))
local Charges = require(script.Parent.DashCharges)
local remote = ReplicatedStorage:WaitForChild("Dash") :: RemoteEvent

type Run = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	state: Charges.State,
	lastRequestAt: number,
	rechargeTask: thread?,
	endTask: thread?,
	died: RBXScriptConnection?,
	velocity: LinearVelocity?,
	attachment: Attachment?,
}

local runs: { [Player]: Run } = {}
local characters: { [Player]: Model } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}

local function publish(run: Run)
	run.character:SetAttribute("DashCharges", run.state.charges)
	run.character:SetAttribute("DashReadyAt", run.state.readyAt)
	run.character:SetAttribute("DashRechargeAt", run.state.rechargeAt)
end

local function stopMotion(run: Run)
	if run.endTask then
		task.cancel(run.endTask)
		run.endTask = nil
	end
	if run.velocity then
		run.velocity:Destroy()
		run.velocity = nil
		-- Remove leftover dash momentum without changing jumping or falling velocity.
		if run.root.Parent and not run.root.Anchored then
			local velocity = run.root.AssemblyLinearVelocity
			local flat = Vector3.new(velocity.X, 0, velocity.Z)
			local speed = math.max(0, run.humanoid.WalkSpeed)
			if flat.Magnitude > speed then
				flat = flat.Unit * speed
				run.root.AssemblyLinearVelocity = Vector3.new(flat.X, velocity.Y, flat.Z)
			end
		end
	end
	if run.attachment then
		run.attachment:Destroy()
		run.attachment = nil
	end
end

local function clearCharacter(player: Player)
	local run = runs[player]
	runs[player] = nil
	characters[player] = nil
	if not run then
		return
	end
	if run.died then run.died:Disconnect() end
	if run.rechargeTask then task.cancel(run.rechargeTask) end
	stopMotion(run)
	run.state.charges = 0
	run.state.readyAt = 0
	run.state.rechargeAt = 0
	publish(run)
end

local function scheduleRecharge(player: Player, run: Run)
	if run.rechargeTask then
		task.cancel(run.rechargeTask)
		run.rechargeTask = nil
	end
	if run.state.rechargeAt == 0 then return end
	run.rechargeTask = task.delay(math.max(0, run.state.rechargeAt - workspace:GetServerTimeNow()), function()
		run.rechargeTask = nil
		if runs[player] ~= run then return end
		Charges.refill(run.state, workspace:GetServerTimeNow())
		publish(run)
		scheduleRecharge(player, run)
	end)
end

local function startMotion(run: Run, direction: Vector3)
	stopMotion(run)
	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = run.root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	velocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * Config.SPEED
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = run.root.AssemblyMass * 1500
	velocity.Parent = run.root
	run.attachment = attachment
	run.velocity = velocity
	run.endTask = task.delay(Config.DURATION, function()
		run.endTask = nil
		stopMotion(run)
	end)
end

local requestConnection = remote.OnServerEvent:Connect(function(player: Player, character: unknown, direction: unknown)
	local run = runs[player]
	if not run or player.Parent ~= Players then return end
	local now = workspace:GetServerTimeNow()
	if now - run.lastRequestAt < Config.REQUEST_INTERVAL then return end
	run.lastRequestAt = now
	-- Bind requests to this life, so delayed input cannot consume a respawn's charges.
	if character ~= run.character or player.Character ~= run.character then return end
	if typeof(direction) ~= "Vector3" then return end
	if direction.X ~= direction.X or direction.Y ~= direction.Y or direction.Z ~= direction.Z then return end
	if math.abs(direction.X) > 1 or math.abs(direction.Z) > 1 or math.abs(direction.Y) > 0.01 then return end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.9 or flat.Magnitude > 1.1 then return end
	if run.humanoid.Health <= 0 or run.humanoid.Sit or run.humanoid.PlatformStand
		or run.root.Anchored or not run.root:IsDescendantOf(workspace) then return end
	if not Charges.spend(run.state, now) then return end
	startMotion(run, flat.Unit)
	publish(run)
	scheduleRecharge(player, run)
end)

local function onCharacterAdded(player: Player, character: Model)
	if characters[player] == character then return end
	clearCharacter(player)
	characters[player] = character
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if characters[player] ~= character or player.Character ~= character or player.Parent ~= Players then return end
	if not humanoid or not humanoid:IsA("Humanoid") or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") then return end
	local run: Run = {
		character = character, humanoid = humanoid, root = root,
		state = Charges.new(), lastRequestAt = -math.huge,
	}
	runs[player] = run
	run.died = humanoid.Died:Connect(function()
		if runs[player] == run then clearCharacter(player) end
	end)
	publish(run)
end

local function onPlayerAdded(player: Player)
	if connections[player] then return end
	connections[player] = {
		player.CharacterAdded:Connect(function(character) onCharacterAdded(player, character) end),
		player.CharacterRemoving:Connect(function(character)
			if characters[player] == character then clearCharacter(player) end
		end),
	}
	if player.Character then task.spawn(onCharacterAdded, player, player.Character) end
end

local function removePlayer(player: Player)
	clearCharacter(player)
	for _, connection in connections[player] or {} do connection:Disconnect() end
	connections[player] = nil
end

local addedConnection = Players.PlayerAdded:Connect(onPlayerAdded)
local removingConnection = Players.PlayerRemoving:Connect(removePlayer)
for _, player in Players:GetPlayers() do onPlayerAdded(player) end

script.Destroying:Connect(function()
	requestConnection:Disconnect()
	addedConnection:Disconnect()
	removingConnection:Disconnect()
	for player in connections do removePlayer(player) end
end)
