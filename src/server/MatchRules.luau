-- Pure scoring rules, kept free of Roblox services so they can be tested with the Luau CLI.
export type Score = {
	kills: number,
	deaths: number,
	-- When the current kill total was reached; breaks ties in favour of whoever got there first.
	lastKillAt: number,
}

local MatchRules = {}

function MatchRules.newScore(): Score
	return { kills = 0, deaths = 0, lastKillAt = math.huge }
end

function MatchRules.addKill(score: Score, now: number)
	score.kills += 1
	score.lastKillAt = now
end

-- Most kills wins; a tie goes to whoever reached that total first. Nobody wins without a kill.
function MatchRules.pickWinner<K>(scores: { [K]: Score }): K?
	local winner: K? = nil
	local best: Score? = nil
	for key, score in scores do
		if score.kills <= 0 then
			continue
		end
		if not best
			or score.kills > best.kills
			or (score.kills == best.kills and score.lastKillAt < best.lastKillAt)
		then
			winner = key
			best = score
		end
	end
	return winner
end

return table.freeze(MatchRules)
