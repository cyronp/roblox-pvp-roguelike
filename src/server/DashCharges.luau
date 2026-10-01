local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DashConfig"))

export type State = {
	charges: number,
	readyAt: number,
	rechargeAt: number,
}

local DashCharges = {}

function DashCharges.new(): State
	return { charges = Config.MAX_CHARGES, readyAt = 0, rechargeAt = 0 }
end

function DashCharges.refill(state: State, now: number)
	if state.rechargeAt == 0 or now < state.rechargeAt then
		return
	end
	local restored = math.floor((now - state.rechargeAt) / Config.RECHARGE_TIME) + 1
	state.charges = math.min(Config.MAX_CHARGES, state.charges + restored)
	state.rechargeAt = if state.charges == Config.MAX_CHARGES then 0
		else state.rechargeAt + restored * Config.RECHARGE_TIME
end

function DashCharges.spend(state: State, now: number): boolean
	DashCharges.refill(state, now)
	if state.charges == 0 or now < state.readyAt then
		return false
	end
	state.charges -= 1
	state.readyAt = now + Config.COOLDOWN
	-- Spent charges refill sequentially; another dash preserves existing progress.
	if state.rechargeAt == 0 then
		state.rechargeAt = now + Config.RECHARGE_TIME
	end
	return true
end

return DashCharges
