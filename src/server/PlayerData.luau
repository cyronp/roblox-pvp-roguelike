local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Schema = require(script.Parent:WaitForChild("PlayerDataSchema"))

local STORE_NAME = "PlayerStats"
local AUTOSAVE_INTERVAL = 90
local MAX_ATTEMPTS = 3
-- Roblox gives BindToClose 30 seconds; leave headroom for the engine to finish.
local SHUTDOWN_SAVE_TIMEOUT = 25

type Session = {
	-- Last value read from or written to the DataStore.
	stored: Schema.Stats,
	-- Increments earned in this server that have not been saved yet.
	pending: Schema.Stats,
}

local sessions: { [Player]: Session } = {}
local savesInFlight = 0
local changedEvent = Instance.new("BindableEvent")
local store: DataStore? = nil

local PlayerData = {
	-- Fires with the Player whose saved stats changed.
	Changed = changedEvent.Event,
}

do
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if success then
		store = result
	else
		warn(`Player stats will not be saved: {result}`)
	end
end

local function keyFor(userId: number): string
	return `player_{userId}`
end

local function withRetries<T>(label: string, callback: () -> T): (boolean, T?)
	for attempt = 1, MAX_ATTEMPTS do
		local success, result = pcall(callback)
		if success then
			return true, result
		end
		if attempt == MAX_ATTEMPTS then
			warn(`{label} failed: {result}`)
			break
		end
		task.wait(2 ^ attempt)
	end
	return false, nil
end

local function load(player: Player, session: Session)
	local activeStore = store
	if not activeStore then
		return
	end
	local success, raw = withRetries(`Loading stats for {player.UserId}`, function()
		return activeStore:GetAsync(keyFor(player.UserId))
	end)
	if sessions[player] ~= session then
		return
	end
	if success then
		session.stored = Schema.reconcile(raw)
		changedEvent:Fire(player)
	elseif RunService:IsStudio() then
		-- Usually "Enable Studio Access to API Services" is off; stop retrying every save.
		store = nil
		warn("Player stats are disabled for this Studio session. Enable Studio Access to API Services to test saving.")
	end
end

local function save(userId: number, session: Session)
	local activeStore = store
	if not activeStore or Schema.isEmpty(session.pending) then
		return
	end

	-- Take the unsaved increments now; anything earned while this yields stays pending.
	local delta = session.pending
	session.pending = Schema.empty()
	savesInFlight += 1
	local success, saved = withRetries(`Saving stats for {userId}`, function()
		return activeStore:UpdateAsync(keyFor(userId), function(raw: unknown)
			return Schema.serialize(Schema.add(Schema.reconcile(raw), delta))
		end)
	end)
	savesInFlight -= 1

	if success then
		session.stored = Schema.reconcile(saved)
	else
		session.pending = Schema.add(session.pending, delta)
	end
end

function PlayerData.Get(player: Player): Schema.Stats
	local session = sessions[player]
	if not session then
		return Schema.empty()
	end
	return Schema.add(session.stored, session.pending)
end

-- Server-only: callers must already have validated the event that earned the stat.
function PlayerData.Increment(player: Player, field: Schema.Field, amount: number?)
	local session = sessions[player]
	if not session then
		return
	end
	session.pending[field] += amount or 1
	changedEvent:Fire(player)
end

local function onPlayerAdded(player: Player)
	if sessions[player] then
		return
	end
	local session: Session = { stored = Schema.empty(), pending = Schema.empty() }
	sessions[player] = session
	load(player, session)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	sessions[player] = nil
	if session then
		save(player.UserId, session)
	end
end

function PlayerData.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, session in sessions do
				task.spawn(save, player.UserId, session)
			end
		end
	end)

	game:BindToClose(function()
		for player, session in sessions do
			task.spawn(save, player.UserId, session)
		end
		-- PlayerRemoving saves may also still be running during shutdown.
		local deadline = os.clock() + SHUTDOWN_SAVE_TIMEOUT
		while savesInFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
