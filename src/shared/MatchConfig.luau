-- Free-for-all round rules. The server enforces them; clients read them only for display.
local Config = {
	-- Below this many players the server stays in warmup and nothing is scored.
	MIN_PLAYERS = 2,
	INTERMISSION_DURATION = 15,
	ROUND_DURATION = 300,
	-- A round also ends as soon as one player reaches this many kills.
	KILL_TARGET = 20,
	RESULTS_DURATION = 8,
	RESPAWN_TIME = 3,
}

return table.freeze(Config)
