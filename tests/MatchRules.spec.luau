local MatchRules = require("../src/server/MatchRules")

local function scoreWith(kills: number, lastKillAt: number?): MatchRules.Score
	local score = MatchRules.newScore()
	for index = 1, kills do
		MatchRules.addKill(score, if index == kills and lastKillAt then lastKillAt else index)
	end
	return score
end

assert(MatchRules.pickWinner({}) == nil, "An empty server has no winner")
assert(MatchRules.pickWinner({ a = MatchRules.newScore(), b = MatchRules.newScore() }) == nil, "Nobody wins without a kill")

assert(MatchRules.pickWinner({ a = scoreWith(3), b = scoreWith(5), c = scoreWith(4) }) == "b", "Most kills wins")
assert(MatchRules.pickWinner({ a = scoreWith(5, 40), b = scoreWith(5, 12) }) == "b", "A tie goes to whoever got there first")
assert(MatchRules.pickWinner({ a = scoreWith(5, 12), b = scoreWith(5, 40) }) == "a", "Tie-break does not depend on iteration order")

local score = MatchRules.newScore()
assert(score.kills == 0 and score.deaths == 0)
MatchRules.addKill(score, 7)
assert(score.kills == 1 and score.lastKillAt == 7)
local fresh = MatchRules.newScore()
assert(fresh.kills == 0, "Each round starts from a new score table")

print("MatchRules: all checks passed")
