local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local chooseRemote = ReplicatedStorage:WaitForChild("ChooseUpgrade") :: RemoteEvent
local changed = Instance.new("BindableEvent")
local random = Random.new()
local EMPTY_LEVELS: Config.Levels = table.freeze({})
local REQUEST_INTERVAL = 0.15

type Run = {
	levels: Config.Levels,
	pending: number,
	choices: { string },
	offerId: number,
	lastRequestAt: number,
}

local runs: { [Player]: Run } = {}
local nextOfferId = 0
local Upgrades = { Changed = changed.Event }

local function publish(player: Player, run: Run)
	-- One replicated snapshot keeps the offer, token, and inventory consistent.
	player:SetAttribute("UpgradeState", HttpService:JSONEncode({
		levels = run.levels,
		pending = run.pending,
		choices = run.choices,
		offerId = run.offerId,
	}))
end

local function offerNext(run: Run)
	run.choices = {}
	if run.pending <= 0 then
		return
	end
	run.choices = Config.rollChoices(run.levels, random)
	if #run.choices == 0 then
		-- XP can continue after all three owned cards reach level five.
		run.pending = 0
		return
	end
	nextOfferId += 1
	run.offerId = nextOfferId
end

function Upgrades.Reset(player: Player)
	local run: Run = {
		levels = {}, pending = 0, choices = {}, offerId = 0, lastRequestAt = -math.huge,
	}
	runs[player] = run
	publish(player, run)
	changed:Fire(player)
end

function Upgrades.RemovePlayer(player: Player)
	runs[player] = nil
end

function Upgrades.GetWeaponStats(player: Player): Config.WeaponStats
	local run = runs[player]
	return Config.getWeaponStats(if run then run.levels else EMPTY_LEVELS)
end

function Upgrades.HasPendingChoice(player: Player): boolean
	local run = runs[player]
	return run ~= nil and #run.choices > 0
end

function Upgrades.AwardLevels(player: Player, count: number)
	local run = runs[player]
	if not run or count <= 0 then
		return
	end
	run.pending += count
	-- Preserve the active offer when additional level-ups queue behind it.
	if #run.choices == 0 then
		offerNext(run)
	end
	publish(player, run)
end

chooseRemote.OnServerEvent:Connect(function(player: Player, offerId: unknown, cardId: unknown)
	local run = runs[player]
	if not run or player.Parent ~= Players then
		return
	end
	local now = os.clock()
	if now - run.lastRequestAt < REQUEST_INTERVAL then
		return
	end
	run.lastRequestAt = now
	if typeof(offerId) ~= "number" or offerId ~= run.offerId or typeof(cardId) ~= "string" then
		return
	end
	if run.pending <= 0 or not table.find(run.choices, cardId) then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local level = run.levels[cardId] or 0
	if level >= Config.MAX_LEVEL or (level == 0 and Config.getOwnedCount(run.levels) >= Config.MAX_CARDS) then
		return
	end

	run.levels[cardId] = level + 1
	run.pending -= 1
	if cardId == "Health" then
		humanoid.MaxHealth += Config.HEALTH_PER_LEVEL
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.HEALTH_PER_LEVEL)
	end
	offerNext(run)
	publish(player, run)
	changed:Fire(player)
end)

return Upgrades
