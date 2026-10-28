local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MatchConfig"))

local deployRemote = ReplicatedStorage:WaitForChild("Deploy") :: RemoteEvent

-- Ignore repeated PLAY presses (or exploit spam) within this window.
local DEPLOY_COOLDOWN = 1

-- Players start in the main menu with no character. Pressing PLAY deploys them, and from
-- then on the server respawns them after each death; Roblox's automatic loading is off.
local deployed: { [Player]: boolean } = {}
local lastRequestAt: { [Player]: number } = {}
local respawnTasks: { [Player]: thread } = {}
local changedEvent = Instance.new("BindableEvent")
local started = false

local Spawning = {
	-- Fires with the Player whose deployed status changed.
	Changed = changedEvent.Event,
}

local function cancelRespawn(player: Player)
	local respawnTask = respawnTasks[player]
	respawnTasks[player] = nil
	if respawnTask and coroutine.status(respawnTask) == "suspended" then
		task.cancel(respawnTask)
	end
end

function Spawning.IsDeployed(player: Player): boolean
	return deployed[player] == true
end

function Spawning.CountDeployed(): number
	local count = 0
	for _ in deployed do
		count += 1
	end
	return count
end

-- Gives a deployed player a fresh character immediately, e.g. at the start of a round.
function Spawning.Respawn(player: Player)
	if not deployed[player] or player.Parent ~= Players then
		return
	end
	cancelRespawn(player)
	player:LoadCharacter()
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end
	humanoid.Died:Once(function()
		cancelRespawn(player)
		respawnTasks[player] = task.delay(Config.RESPAWN_TIME, function()
			respawnTasks[player] = nil
			-- Skip if something else (such as a round start) already gave them a new character.
			if deployed[player] and player.Parent == Players and player.Character == character then
				player:LoadCharacter()
			end
		end)
	end)
end

local function onDeployRequested(player: Player)
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < DEPLOY_COOLDOWN then
		return
	end
	lastRequestAt[player] = now
	if deployed[player] or player.Parent ~= Players then
		return
	end

	deployed[player] = true
	player:SetAttribute("Deployed", true)
	changedEvent:Fire(player)
	player:LoadCharacter()
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Deployed", false)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
end

local function onPlayerRemoving(player: Player)
	cancelRespawn(player)
	lastRequestAt[player] = nil
	if deployed[player] then
		deployed[player] = nil
		changedEvent:Fire(player)
	end
end

function Spawning.Start()
	if started then
		return
	end
	started = true
	-- Also set in default.project.json so nobody spawns before this script runs.
	Players.CharacterAutoLoads = false

	-- The remote carries no arguments; any extra values an exploiter sends are ignored.
	deployRemote.OnServerEvent:Connect(onDeployRequested)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return Spawning
