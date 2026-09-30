-- The runner inserts the unmodified project modules between fixtures and assertions.
local modules = {}
local now = 0
local os = { clock = function() return now end }
local Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }
local Random = {}
function Random.new(seed: number?)
	local value = seed or 1
	return {
		NextInteger = function(_, low: number, high: number)
			value = (value * 48271) % 2147483647
			return low + value % (high - low + 1)
		end,
	}
end

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, callback in callbacks do callback(...) end
		end,
	}
end

local Instance = {}
function Instance.new(className: string)
	assert(className == "BindableEvent")
	local event = signal()
	return { Event = event, Fire = function(_, ...) event:Fire(...) end }
end

local function copy(value)
	if typeof(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end

local remote = { OnServerEvent = signal() }
local shared = { WaitForChild = function(_, name) return name end }
local services = {
	Players = {},
	HttpService = { JSONEncode = function(_, value) return copy(value) end },
	ReplicatedStorage = {
		WaitForChild = function(_, name)
			if name == "ChooseUpgrade" then return remote end
			assert(name == "Shared")
			return shared
		end,
	},
}
local game = { GetService = function(_, name) return assert(services[name]) end }
local script = { Parent = shared }
local function require(name) return assert(modules[name], name) end

local function makePlayer()
	local humanoid = { Health = 100, MaxHealth = 100 }
	local player = {
		Parent = services.Players,
		Character = { FindFirstChildOfClass = function() return humanoid end },
		attributes = {},
		SetAttribute = function(self, name, value) self.attributes[name] = value end,
	}
	return player, humanoid
end

-- INSERT PROJECT MODULES HERE

local Config = modules.UpgradeConfig
local Upgrades = modules.Upgrades
local Experience = modules.Experience
local DamageStreak = modules.DamageStreak
local checkedStates = 0

local function checkRules(levels)
	if Config.getOwnedCount(levels) > Config.MAX_CARDS then return end
	checkedStates += 1
	local eligible = Config.getEligibleCards(levels)
	local choices = Config.rollChoices(levels, Random.new(checkedStates))
	assert(#choices == math.min(3, #eligible))
	local seen = {}
	for _, id in choices do
		assert(not seen[id], "An offer must not contain duplicate cards")
		seen[id] = true
		assert((levels[id] or 0) < 5, "Maxed cards must not be offered")
		assert(Config.getOwnedCount(levels) < 3 or (levels[id] or 0) > 0, "Full inventory must exclude new cards")
	end
	local stats = Config.getWeaponStats(levels)
	assert(stats.maxAmmo >= 6 and stats.maxAmmo <= 11)
	assert(stats.fireInterval >= 0.35 and stats.fireInterval <= 0.7)
	assert(stats.reloadTime >= 0.9 and stats.reloadTime <= 1.8)
end

local function enumerate(index, levels)
	if index > #Config.CARDS then checkRules(levels); return end
	local id = Config.CARDS[index].id
	for level = 0, 5 do
		levels[id] = level
		enumerate(index + 1, levels)
	end
end
enumerate(1, {})
assert(#Config.rollChoices({ Damage = 5, Ammo = 5, Health = 4 }, Random.new()) == 1)
assert(#Config.rollChoices({ Damage = 5, Ammo = 4, Health = 4 }, Random.new()) == 2)
assert(#Config.rollChoices({ Damage = 5, Ammo = 5, Health = 5 }, Random.new()) == 0)

local function snapshot(player) return player.attributes.UpgradeState end
local function submit(player, offerId, cardId)
	now += 1
	remote.OnServerEvent:Fire(player, offerId, cardId)
end

local player, humanoid = makePlayer()
local other = makePlayer()
Experience.Reset(player)
Experience.Reset(other)
for _ = 1, 3 do Experience.AwardKill(player) end
assert(player.attributes.Level == 1 and player.attributes.XP == 75)
assert(not Upgrades.HasPendingChoice(player))
Experience.AwardKill(player)
assert(player.attributes.Level == 2 and player.attributes.XP == 0)
assert(#snapshot(player).choices == 3 and snapshot(player).pending == 1)
assert(snapshot(other).pending == 0 and other.attributes.XP == 0)

local firstOffer = copy(snapshot(player))
local unoffered = nil
for _, card in Config.CARDS do
	if not table.find(firstOffer.choices, card.id) then unoffered = card.id; break end
end
for _, invalid in { 123, {}, "UnknownCard", unoffered } do
	submit(player, firstOffer.offerId, invalid)
	assert(Config.getOwnedCount(snapshot(player).levels) == 0)
end
for _, invalidToken in { "1", {}, math.huge, 0 / 0, -1 } do
	submit(player, invalidToken, firstOffer.choices[1])
	assert(Config.getOwnedCount(snapshot(player).levels) == 0)
end
humanoid.Health = 0
submit(player, firstOffer.offerId, firstOffer.choices[1])
assert(snapshot(player).pending == 1, "Dead players cannot choose")
humanoid.Health = 100

Upgrades.AwardLevels(player, 2)
assert(snapshot(player).offerId == firstOffer.offerId, "Queued levels must preserve the current offer")
assert(snapshot(player).pending == 3)
submit(player, firstOffer.offerId, firstOffer.choices[1])
assert(snapshot(player).pending == 2 and Config.getOwnedCount(snapshot(player).levels) == 1)
local secondOffer = copy(snapshot(player))
assert(secondOffer.offerId ~= firstOffer.offerId)
submit(player, firstOffer.offerId, firstOffer.choices[1])
assert(snapshot(player).pending == 2, "Replayed offers cannot grant another upgrade")
remote.OnServerEvent:Fire(player, secondOffer.offerId, secondOffer.choices[1])
assert(snapshot(player).pending == 2, "Rapid requests must be rate limited")
submit(player, secondOffer.offerId, secondOffer.choices[1])
assert(snapshot(player).pending == 1)
local oldOffer = copy(snapshot(player))
Experience.Reset(player)
assert(Config.getOwnedCount(snapshot(player).levels) == 0 and snapshot(player).pending == 0)
Upgrades.AwardLevels(player, 1)
submit(player, oldOffer.offerId, oldOffer.choices[1])
assert(snapshot(player).pending == 1, "Offers from a previous life must not work")

-- Play a full progression, prioritizing new cards until all three slots are filled.
Experience.Reset(player)
Upgrades.AwardLevels(player, 20)
local picks = 0
local sawHealth = false
humanoid.Health = 50
while Upgrades.HasPendingChoice(player) do
	local offer = snapshot(player)
	local chosen = offer.choices[1]
	for _, id in offer.choices do
		if not offer.levels[id] then chosen = id; break end
	end
	local oldMax, oldHealth = humanoid.MaxHealth, humanoid.Health
	submit(player, offer.offerId, chosen)
	picks += 1
	assert(picks <= 15, "A run can grant at most 3 * 5 upgrades")
	if chosen == "Health" then
		sawHealth = true
		assert(humanoid.MaxHealth == oldMax + 10 and humanoid.Health == oldHealth + 10)
	end
end
assert(picks == 15 and sawHealth)
assert(Config.getOwnedCount(snapshot(player).levels) == 3)
for _, level in snapshot(player).levels do assert(level == 5) end
Upgrades.AwardLevels(player, 1)
assert(snapshot(player).pending == 0 and not Upgrades.HasPendingChoice(player))
assert(Config.getOwnedCount(snapshot(other).levels) == 0)
assert(other.Character:FindFirstChildOfClass("Humanoid").MaxHealth == 100)
for _ = 1, 4 do Experience.AwardKill(player) end
assert(player.attributes.Level == 2 and not Upgrades.HasPendingChoice(player), "XP must continue after all cards are maxed")

local maxStats = Config.getWeaponStats({ Damage = 5, Ammo = 5, FireRate = 5, Reload = 5 })
assert(maxStats.damageBonus == 25 and maxStats.maxAmmo == 11)
assert(maxStats.fireInterval == 0.35 and maxStats.reloadTime == 0.9)
local target = { Health = 100, TakeDamage = function(self, damage) self.Health = math.max(0, self.Health - damage) end }
local hit = DamageStreak.ApplyHit(player, player.Character, target, now, 5)
assert(hit.damage == 40 and target.Health == 60)
hit = DamageStreak.ApplyHit(player, player.Character, target, now + 1, 25)
assert(hit.damage == 60 and hit.totalDamage == 100 and hit.killed)
local protected = { Health = 100, TakeDamage = function() end }
assert(DamageStreak.ApplyHit(player, player.Character, protected, now + 2, 25) == nil)

Experience.RemovePlayer(player)
assert(not Upgrades.HasPendingChoice(player))
assert(Upgrades.GetWeaponStats(player).maxAmmo == 6)
submit(player, snapshot(player).offerId, "Damage")
assert(snapshot(player).pending == 0)
print(`PASS: {checkedStates} inventory states; XP, queue, caps, health, damage, invalid/replayed/rapid picks, reset, and player isolation`)
