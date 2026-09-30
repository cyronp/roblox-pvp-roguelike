local Config = {
	START_LEVEL = 1,
	XP_PER_KILL = 25,
	BASE_XP_REQUIRED = 100,
	XP_INCREASE_PER_LEVEL = 50,
}

function Config.getRequiredXp(level: number): number
	return Config.BASE_XP_REQUIRED + math.max(0, level - Config.START_LEVEL) * Config.XP_INCREASE_PER_LEVEL
end

return table.freeze(Config)
