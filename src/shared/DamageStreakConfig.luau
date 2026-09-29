local Config = {
	BASE_DAMAGE = 35,
	RESET_AFTER = 4,
	DURATION_REDUCTION = 0.15,
	-- Covers the 0.7-second pre-reload delay, 1.8-second reload, and time to aim again.
	MIN_DURATION = 3.5,
}

function Config.getDuration(hitCount: number): number
	return math.max(Config.MIN_DURATION, Config.RESET_AFTER - math.max(0, hitCount - 1) * Config.DURATION_REDUCTION)
end

return table.freeze(Config)
