-- The runner loads the production modules unchanged; physics still needs Studio.
local modules = {}
local now = 100

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			local connection = { Connected = true }
			function connection:Disconnect() self.Connected = false end
			callbacks[connection] = callback
			return connection
		end,
		Fire = function(_, ...)
			for connection, callback in callbacks do
				if connection.Connected then callback(...) end
			end
		end,
	}
end

local Vector3 = {}
local vectorMeta = {}
function Vector3.new(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vectorMeta) end
function vectorMeta.__index(value, key)
	local magnitude = math.sqrt(value.X ^ 2 + value.Y ^ 2 + value.Z ^ 2)
	if key == "Magnitude" then return magnitude end
	if key == "Unit" then return Vector3.new(value.X / magnitude, value.Y / magnitude, value.Z / magnitude) end
	error(key)
end
function vectorMeta.__mul(value, scale) return Vector3.new(value.X * scale, value.Y * scale, value.Z * scale) end
local Vector2 = { new = function(x, y) return Vector3.new(x, y, 0) end }
local nativeTypeof = typeof
local function typeof(value)
	return if type(value) == "table" and getmetatable(value) == vectorMeta then "Vector3" else nativeTypeof(value)
end

local tasks = {}
local task = {}
function task.delay(seconds, callback)
	local pending = { at = now + seconds, callback = callback, cancelled = false }
	table.insert(tasks, pending)
	return pending
end
function task.cancel(pending) pending.cancelled = true end
function task.spawn(callback, ...) callback(...) end
local function advanceTo(target)
	while true do
		local nextTask = nil
		for _, pending in tasks do
			if not pending.cancelled and pending.at <= target and (not nextTask or pending.at < nextTask.at) then
				nextTask = pending
			end
		end
		if not nextTask then break end
		nextTask.cancelled = true
		now = nextTask.at
		nextTask.callback()
	end
	now = target
end

local created = {}
local Instance = {}
function Instance.new(class)
	local object = { ClassName = class }
	function object:Destroy() self.destroyed = true; self.Parent = nil end
	table.insert(created, object)
	return object
end
local Enum = {
	ActuatorRelativeTo = { World = "World" },
	VelocityConstraintMode = { Plane = "Plane" },
	ForceLimitMode = { Magnitude = "Magnitude" },
}
local workspace = { GetServerTimeNow = function() return now end }
local remote = { OnServerEvent = signal() }
local broadcasts = {}
function remote:FireAllClients(character, direction)
	table.insert(broadcasts, { character = character, direction = direction })
end
local shared = { WaitForChild = function(_, name) return name end }
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end }
local game = { GetService = function(_, name)
	if name == "Players" then return players end
	assert(name == "ReplicatedStorage")
	return { WaitForChild = function(_, child)
		if child == "Shared" then return shared end
		assert(child == "Dash")
		return remote
	end }
end }
local script = { Parent = { DashCharges = "DashCharges" }, Destroying = signal() }
local function require(name) return assert(modules[name], name) end

local function makeCharacter()
	local humanoid = { Health = 100, WalkSpeed = 16, Sit = false, PlatformStand = false, Died = signal() }
	function humanoid:IsA(class) return class == "Humanoid" end
	local root = { Parent = true, Anchored = false, AssemblyMass = 10, AssemblyLinearVelocity = Vector3.new(72, -12, 0) }
	function root:IsA(class) return class == "BasePart" end
	function root:IsDescendantOf() return self.Parent ~= nil end
	local character = { attributes = {} }
	function character:WaitForChild(name) return if name == "Humanoid" then humanoid else root end
	function character:SetAttribute(name, value) self.attributes[name] = value end
	return character, humanoid, root
end
local function makePlayer()
	local character, humanoid, root = makeCharacter()
	local player = { Parent = players, Character = character, CharacterAdded = signal(), CharacterRemoving = signal() }
	return player, humanoid, root
end
local function liveConstraints()
	local count = 0
	for _, object in created do
		if object.ClassName == "LinearVelocity" and not object.destroyed then count += 1 end
	end
	return count
end
local forward = Vector3.new(1, 0, 0)

-- INSERT PROJECT MODULES HERE

local Charges = modules.DashCharges
local state = Charges.new()
assert(Charges.spend(state, 10) and state.charges == 2)
assert(not Charges.spend(state, 10.999), "The one-second cooldown must be enforced")
assert(Charges.spend(state, 11) and Charges.spend(state, 12))
assert(not Charges.spend(state, 13), "Three charges must exhaust the supply")
assert(state.rechargeAt == 13.5, "Later dashes must not restart the first recharge")
Charges.refill(state, 13.499)
assert(state.charges == 0)
Charges.refill(state, 13.5)
assert(state.charges == 1 and state.rechargeAt == 17)
assert(Charges.spend(state, 13.5) and state.rechargeAt == 17)
Charges.refill(state, 100)
assert(state.charges == 3 and state.rechargeAt == 0, "Late callbacks must catch up without overfilling")

local player, humanoid, root = makePlayer()
local other = makePlayer()
players.PlayerAdded:Fire(player)
players.PlayerAdded:Fire(other)
assert(player.Character.attributes.DashCharges == 3 and other.Character.attributes.DashCharges == 3)
remote.OnServerEvent:Fire(player, player.Character, forward)
assert(player.Character.attributes.DashCharges == 2 and liveConstraints() == 1)
assert(#broadcasts == 1 and broadcasts[1].character == player.Character)
assert(broadcasts[1].direction.Magnitude == 1, "Accepted dashes must broadcast the normalized direction")
remote.OnServerEvent:Fire(player, player.Character, forward)
assert(player.Character.attributes.DashCharges == 2, "Spam must not spend extra charges")
assert(#broadcasts == 1, "Spam must not broadcast extra effects")
advanceTo(100.25)
assert(liveConstraints() == 0 and root.AssemblyLinearVelocity.Y == -12)
assert(root.AssemblyLinearVelocity.X == 16, "Dash completion must remove excess horizontal momentum")
advanceTo(100.5)
remote.OnServerEvent:Fire(player, player.Character, forward)
assert(player.Character.attributes.DashCharges == 2, "Server cooldown must reject early requests")
assert(#broadcasts == 1, "Cooldown rejection must not play effects")
advanceTo(101)
remote.OnServerEvent:Fire(player, player.Character, forward)
advanceTo(102)
remote.OnServerEvent:Fire(player, player.Character, forward)
assert(player.Character.attributes.DashCharges == 0)
advanceTo(103)
remote.OnServerEvent:Fire(player, player.Character, forward)
assert(liveConstraints() == 0)
advanceTo(103.5)
assert(player.Character.attributes.DashCharges == 1)
advanceTo(107)
assert(player.Character.attributes.DashCharges == 2)
advanceTo(110.5)
assert(player.Character.attributes.DashCharges == 3 and player.Character.attributes.DashRechargeAt == 0)
assert(other.Character.attributes.DashCharges == 3, "Players must have independent charge supplies")

local acceptedCount = #broadcasts
for _, invalid in { "forward", {}, 123, Vector3.new(0, 0, 0), Vector3.new(2, 0, 0),
	Vector3.new(1, 1, 0), Vector3.new(math.huge, 0, 0), Vector3.new(0 / 0, 0, 0) } do
	advanceTo(now + 0.2)
	remote.OnServerEvent:Fire(player, player.Character, invalid)
	assert(player.Character.attributes.DashCharges == 3 and liveConstraints() == 0)
end
for _, flag in { "Sit", "PlatformStand" } do
	humanoid[flag] = true
	advanceTo(now + 0.2)
	remote.OnServerEvent:Fire(player, player.Character, forward)
	assert(player.Character.attributes.DashCharges == 3)
	humanoid[flag] = false
end
root.Anchored = true
advanceTo(now + 0.2)
remote.OnServerEvent:Fire(player, player.Character, forward)
assert(player.Character.attributes.DashCharges == 3)
root.Anchored = false
assert(#broadcasts == acceptedCount, "Invalid or disallowed dashes must not broadcast effects")

advanceTo(now + 0.2)
remote.OnServerEvent:Fire(player, player.Character, forward)
assert(liveConstraints() == 1)
now += 1
remote.OnServerEvent:Fire(player, player.Character, forward)
assert(liveConstraints() == 1, "A delayed completion callback must not leave overlapping dash constraints")
local oldCharacter = player.Character
humanoid.Health = 0
humanoid.Died:Fire()
assert(liveConstraints() == 0 and oldCharacter.attributes.DashCharges == 0)
advanceTo(now + 10)
acceptedCount = #broadcasts
remote.OnServerEvent:Fire(player, oldCharacter, forward)
assert(oldCharacter.attributes.DashCharges == 0, "Death must cancel recharge work and reject requests")
assert(#broadcasts == acceptedCount, "Dead characters must not play dash effects")
player.CharacterRemoving:Fire(oldCharacter)
local nextCharacter = makeCharacter()
player.Character = nextCharacter
player.CharacterAdded:Fire(nextCharacter)
assert(nextCharacter.attributes.DashCharges == 3)
remote.OnServerEvent:Fire(player, oldCharacter, forward)
assert(nextCharacter.attributes.DashCharges == 3, "A previous life's request cannot dash the new character")
assert(#broadcasts == acceptedCount, "A previous life's request must not broadcast effects")
advanceTo(now + 0.2)
remote.OnServerEvent:Fire(player, nextCharacter, forward)
assert(liveConstraints() == 1)
players.PlayerRemoving:Fire(player)
assert(liveConstraints() == 0)
advanceTo(now + 20)
assert(nextCharacter.attributes.DashCharges == 0, "Disconnect must cancel recharge work")
script.Destroying:Fire()
for _, object in created do assert(object.destroyed, "Temporary dash objects must be cleaned up") end
print("PASS: dash cooldown boundaries, sequential recharge, spam/invalid requests, player isolation, death, respawn, disconnect, and cleanup")
