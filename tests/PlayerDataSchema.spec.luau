local Schema = require("../src/server/PlayerDataSchema")

local function same(a, b): boolean
	for _, field in Schema.FIELDS do
		if a[field] ~= b[field] then
			return false
		end
	end
	return true
end

local empty = Schema.empty()
assert(Schema.isEmpty(empty))
assert(same(Schema.reconcile(nil), empty), "New players start at zero")
assert(same(Schema.reconcile("corrupt"), empty), "Non-table records fall back to zero")

local older = Schema.reconcile({ Kills = 12, Wins = 2 })
assert(older.Kills == 12 and older.Wins == 2 and older.Deaths == 0 and older.MatchesPlayed == 0, "Missing fields get defaults")

local messy = Schema.reconcile({ Kills = -4, Deaths = 0 / 0, Wins = math.huge, MatchesPlayed = 3.7, Extra = "ignored" })
assert(messy.Kills == 0 and messy.Deaths == 0 and messy.Wins == 0, "Invalid counters are rejected")
assert(messy.MatchesPlayed == 3, "Counters are whole numbers")

-- Two servers each add their own increments, so neither overwrites the other.
local stored = Schema.reconcile({ Kills = 10, Deaths = 4, Wins = 1, MatchesPlayed = 5 })
local serverA = { Kills = 3, Deaths = 1, Wins = 0, MatchesPlayed = 1 }
local serverB = { Kills = 2, Deaths = 2, Wins = 1, MatchesPlayed = 1 }
local merged = Schema.add(Schema.add(stored, serverA), serverB)
assert(merged.Kills == 15 and merged.Deaths == 7 and merged.Wins == 2 and merged.MatchesPlayed == 7)
assert(stored.Kills == 10, "add does not mutate its inputs")
assert(not Schema.isEmpty(serverA))

local record = Schema.serialize(merged)
assert(record.Version == Schema.VERSION)
assert(same(Schema.reconcile(record), merged), "Saved records load back unchanged")

print("PlayerDataSchema: all checks passed")
