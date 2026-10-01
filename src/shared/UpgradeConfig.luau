export type Levels = { [string]: number }
export type Card = {
	id: string,
	name: string,
	description: string,
	color: Color3,
}
export type WeaponStats = {
	damageBonus: number,
	maxAmmo: number,
	fireInterval: number,
	reloadTime: number,
}

local Config = {
	MAX_CARDS = 3,
	MAX_LEVEL = 5,
	CHOICE_COUNT = 3,
	DAMAGE_PER_LEVEL = 5,
	HEALTH_PER_LEVEL = 10,
	SPEED_REDUCTION_PER_LEVEL = 0.1,
	BASE_AMMO = 6,
	BASE_FIRE_INTERVAL = 0.7,
	BASE_RELOAD_TIME = 1.8,
	CARDS = {
		{ id = "Damage", name = "Heavy Hitter", description = "+5 weapon damage", color = Color3.fromRGB(255, 140, 108) },
		{ id = "Ammo", name = "Extra Round", description = "+1 bullet in the magazine", color = Color3.fromRGB(255, 203, 109) },
		{ id = "FireRate", name = "Quick Trigger", description = "-10% base shooting cooldown", color = Color3.fromRGB(114, 199, 255) },
		{ id = "Health", name = "Vitality", description = "+10 maximum and current health", color = Color3.fromRGB(114, 224, 161) },
		{ id = "Reload", name = "Fast Hands", description = "-10% base reload duration", color = Color3.fromRGB(194, 159, 255) },
	} :: { Card },
}

function Config.getCard(id: string): Card?
	for _, card in Config.CARDS do
		if card.id == id then
			return card
		end
	end
	return nil
end

function Config.getCardBuff(id: string, level: number): string?
	if id == "Damage" then
		return `+{level * Config.DAMAGE_PER_LEVEL} DAMAGE`
	elseif id == "Ammo" then
		return `+{level} {if level == 1 then "BULLET" else "BULLETS"}`
	elseif id == "Health" then
		return `+{level * Config.HEALTH_PER_LEVEL} HEALTH`
	elseif id == "FireRate" or id == "Reload" then
		local reduction = math.round(level * Config.SPEED_REDUCTION_PER_LEVEL * 100)
		local stat = if id == "FireRate" then "SHOT DELAY" else "RELOAD TIME"
		return `-{reduction}% {stat}`
	end
	return nil
end

function Config.getOwnedCount(levels: Levels): number
	local count = 0
	for _, card in Config.CARDS do
		if (levels[card.id] or 0) > 0 then
			count += 1
		end
	end
	return count
end

function Config.getEligibleCards(levels: Levels): { string }
	local eligible = {}
	local hasFreeSlot = Config.getOwnedCount(levels) < Config.MAX_CARDS
	for _, card in Config.CARDS do
		local level = levels[card.id] or 0
		if level < Config.MAX_LEVEL and (level > 0 or hasFreeSlot) then
			table.insert(eligible, card.id)
		end
	end
	return eligible
end

function Config.rollChoices(levels: Levels, random: Random): { string }
	local eligible = Config.getEligibleCards(levels)
	local choices = {}
	for _ = 1, math.min(Config.CHOICE_COUNT, #eligible) do
		local index = random:NextInteger(1, #eligible)
		table.insert(choices, table.remove(eligible, index))
	end
	return choices
end

function Config.getWeaponStats(levels: Levels): WeaponStats
	return {
		damageBonus = (levels.Damage or 0) * Config.DAMAGE_PER_LEVEL,
		maxAmmo = Config.BASE_AMMO + (levels.Ammo or 0),
		fireInterval = Config.BASE_FIRE_INTERVAL * (1 - (levels.FireRate or 0) * Config.SPEED_REDUCTION_PER_LEVEL),
		reloadTime = Config.BASE_RELOAD_TIME * (1 - (levels.Reload or 0) * Config.SPEED_REDUCTION_PER_LEVEL),
	}
end

for _, card in Config.CARDS do
	table.freeze(card)
end
table.freeze(Config.CARDS)
return table.freeze(Config)
