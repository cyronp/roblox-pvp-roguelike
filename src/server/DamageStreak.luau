local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DamageStreakConfig"))

export type HitFeedback = {
	hitCount: number,
	damage: number,
	totalDamage: number,
	killed: boolean,
	expiresAt: number,
	duration: number,
}

type Streak = {
	character: Model,
	hitCount: number,
	expiresAt: number,
	damageByTarget: { [Instance | string]: { totalDamage: number, expiresAt: number } },
}

local streaks: { [Player]: Streak } = {}
local DamageStreak = {}

local function getTargetId(target: Humanoid): Instance | string
	local model = target.Parent
	if not model or not model:IsA("Model") then
		return target
	end

	local targetPlayer = Players:GetPlayerFromCharacter(model)
	if targetPlayer then
		return targetPlayer
	end

	-- Server-spawned NPCs retain this ID when their model and humanoid are replaced.
	local npcId = model:GetAttribute("DamageStreakId")
	if typeof(npcId) == "string" and npcId ~= "" then
		return `npc:{npcId}`
	end
	return target
end

function DamageStreak.Reset(player: Player)
	streaks[player] = nil
end

function DamageStreak.ApplyHit(player: Player, character: Model, target: Humanoid, now: number, damageBonus: number?): HitFeedback?
	if target.Health <= 0 then
		return nil
	end

	local previous = streaks[player]
	local targetId = getTargetId(target)
	local hitCount = 1
	local totalDamage = 0
	local damageByTarget: { [Instance | string]: { totalDamage: number, expiresAt: number } } = {}
	if previous
		and previous.character == character
		and now < previous.expiresAt
	then
		hitCount = previous.hitCount + 1
		damageByTarget = previous.damageByTarget
		local targetDamage = damageByTarget[targetId]
		if targetDamage and now < targetDamage.expiresAt then
			totalDamage = targetDamage.totalDamage
		end
	end

	local healthBefore = target.Health
	target:TakeDamage(Config.BASE_DAMAGE + (damageBonus or 0))
	-- ForceFields and overkill must not inflate the displayed damage or streak.
	local dealtDamage = math.max(0, healthBefore - target.Health)
	if dealtDamage <= 0 then
		return nil
	end

	totalDamage += dealtDamage
	local duration = Config.getDuration(hitCount)
	local expiresAt = now + duration
	local killed = target.Health <= 0
	-- Damage stays specific to each enemy while the hit count spans every target.
	for id, targetDamage in damageByTarget do
		if now >= targetDamage.expiresAt then
			damageByTarget[id] = nil
		end
	end
	damageByTarget[targetId] = { totalDamage = totalDamage, expiresAt = expiresAt }
	streaks[player] = {
		character = character,
		hitCount = hitCount,
		expiresAt = expiresAt,
		damageByTarget = damageByTarget,
	}

	return {
		hitCount = hitCount,
		damage = dealtDamage,
		totalDamage = totalDamage,
		killed = killed,
		expiresAt = expiresAt,
		duration = duration,
	}
end

return DamageStreak
