local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MatchConfig"))
local MatchRules = require(script.Parent:WaitForChild("MatchRules"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local killFeedRemote = ReplicatedStorage:WaitForChild("KillFeed") :: RemoteEvent
-- Clients read the round state from these replicated attributes; no remote is needed.
local matchState = ReplicatedStorage:WaitForChild("MatchState") :: Folder

export type State = "Waiting" | "Intermission" | "Active" | "Results"
type EndReason = "TimeUp" | "KillTarget" | "NotEnoughPlayers"

type Entry = {
	score: MatchRules.Score,
	kills: IntValue,
	deaths: IntValue,
	wins: IntValue,
	connections: { RBXScriptConnection },
}

local entries: { [Player]: Entry } = {}
-- The player credited with the lethal revolver hit on each character, until it dies.
local killers: { [Model]: Player } = {}
local state: State = "Waiting"
local roundOpen = false
local endReason: EndReason? = nil
local roundEnded = Instance.new("BindableEvent")
local playersChanged = Instance.new("BindableEvent")
local started = false

local Match = {}

local function setState(nextState: State, duration: number?)
	state = nextState
	matchState:SetAttribute("EndsAt", if duration then workspace:GetServerTimeNow() + duration else nil)
	matchState:SetAttribute("State", nextState)
end

local function countPlayers(): number
	local count = 0
	for _ in entries do
		count += 1
	end
	return count
end

local function enoughPlayers(): boolean
	return countPlayers() >= Config.MIN_PLAYERS
end

local function collectScores(): { [Player]: MatchRules.Score }
	local scores = {}
	for player, entry in entries do
		scores[player] = entry.score
	end
	return scores
end

local function publishLeader()
	local leader = if state == "Active" then MatchRules.pickWinner(collectScores()) else nil
	local leaderEntry = if leader then entries[leader] else nil
	matchState:SetAttribute("LeaderName", if leader then leader.DisplayName else nil)
	matchState:SetAttribute("LeaderKills", if leaderEntry then leaderEntry.score.kills else nil)
end

local function endRound(reason: EndReason)
	if not roundOpen then
		return
	end
	roundOpen = false
	endReason = reason
	roundEnded:Fire()
end

local function onPlayerDied(victim: Player, character: Model)
	local killer = killers[character]
	killers[character] = nil
	if killer and (killer == victim or killer.Parent ~= Players) then
		killer = nil
	end
	if victim.Parent ~= Players then
		return
	end

	killFeedRemote:FireAllClients(victim, killer)
	if state ~= "Active" then
		return
	end

	local victimEntry = entries[victim]
	if victimEntry then
		victimEntry.score.deaths += 1
		victimEntry.deaths.Value = victimEntry.score.deaths
		PlayerData.Increment(victim, "Deaths")
	end

	local killerEntry = if killer then entries[killer] else nil
	if not killer or not killerEntry then
		return
	end
	MatchRules.addKill(killerEntry.score, os.clock())
	killerEntry.kills.Value = killerEntry.score.kills
	PlayerData.Increment(killer, "Kills")
	publishLeader()
	if killerEntry.score.kills >= Config.KILL_TARGET then
		endRound("KillTarget")
	end
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end
	humanoid.Died:Once(function()
		-- Deferred so a lethal revolver hit records its killer first, whichever order the engine uses.
		task.defer(onPlayerDied, player, character)
	end)
end

local function addStat(folder: Folder, name: string): IntValue
	local value = Instance.new("IntValue")
	value.Name = name
	value.Parent = folder
	return value
end

local function onPlayerAdded(player: Player)
	if entries[player] then
		return
	end
	-- The player list sorts by the first stat, so round kills come first.
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local entry: Entry = {
		score = MatchRules.newScore(),
		kills = addStat(leaderstats, "Kills"),
		deaths = addStat(leaderstats, "Deaths"),
		wins = addStat(leaderstats, "Wins"),
		connections = {},
	}
	entry.wins.Value = PlayerData.Get(player).Wins
	leaderstats.Parent = player
	entries[player] = entry

	table.insert(entry.connections, player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end))
	table.insert(entry.connections, player.CharacterRemoving:Connect(function(character)
		killers[character] = nil
	end))
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
	playersChanged:Fire()
end

local function onPlayerRemoving(player: Player)
	local entry = entries[player]
	entries[player] = nil
	if entry then
		for _, connection in entry.connections do
			connection:Disconnect()
		end
	end
	if player.Character then
		killers[player.Character] = nil
	end
	if state == "Active" then
		publishLeader()
		if not enoughPlayers() then
			endRound("NotEnoughPlayers")
		end
	end
	playersChanged:Fire()
end

local function startRound()
	for _, entry in entries do
		entry.score = MatchRules.newScore()
		entry.kills.Value = 0
		entry.deaths.Value = 0
	end
	table.clear(killers)
	matchState:SetAttribute("WinnerName", nil)
	matchState:SetAttribute("WinnerKills", nil)
	matchState:SetAttribute("EndReason", nil)
	roundOpen = true
	setState("Active", Config.ROUND_DURATION)
	publishLeader()

	-- Respawning resets health, level, and upgrades, so everyone starts the round even.
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			if player.Parent == Players then
				player:LoadCharacter()
			end
		end)
	end
end

local function waitForRoundEnd(): EndReason
	local timeout = task.delay(Config.ROUND_DURATION, endRound, "TimeUp")
	-- The round may already have ended while players were respawning.
	if roundOpen then
		roundEnded.Event:Wait()
	end
	if coroutine.status(timeout) == "suspended" then
		task.cancel(timeout)
	end
	local reason = endReason or "TimeUp"
	endReason = nil
	return reason
end

local function finishRound(reason: EndReason)
	local winner = if reason == "NotEnoughPlayers" then nil else MatchRules.pickWinner(collectScores())
	local winnerEntry = if winner then entries[winner] else nil
	for player in entries do
		PlayerData.Increment(player, "MatchesPlayed")
	end
	if winner and winnerEntry then
		PlayerData.Increment(winner, "Wins")
		matchState:SetAttribute("WinnerName", winner.DisplayName)
		matchState:SetAttribute("WinnerKills", winnerEntry.score.kills)
	end
	matchState:SetAttribute("EndReason", reason)
	setState("Results", Config.RESULTS_DURATION)
	publishLeader()
end

local function runRounds()
	while true do
		while not enoughPlayers() do
			setState("Waiting")
			playersChanged.Event:Wait()
		end

		setState("Intermission", Config.INTERMISSION_DURATION)
		task.wait(Config.INTERMISSION_DURATION)
		if enoughPlayers() then
			startRound()
			finishRound(waitForRoundEnd())
			task.wait(Config.RESULTS_DURATION)
		end
	end
end

-- Called only by the server's confirmed lethal-hit path, never by a client remote.
function Match.CreditKill(killer: Player, victimCharacter: Model)
	-- Only player characters get a Died handler; NPC entries would never be cleared.
	if Players:GetPlayerFromCharacter(victimCharacter) then
		killers[victimCharacter] = killer
	end
end

function Match.Start()
	if started then
		return
	end
	started = true
	Players.RespawnTime = Config.RESPAWN_TIME

	PlayerData.Changed:Connect(function(player: Player)
		local entry = entries[player]
		if entry then
			entry.wins.Value = PlayerData.Get(player).Wins
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(runRounds)
end

return Match
