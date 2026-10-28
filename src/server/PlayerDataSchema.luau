-- Saved lifetime stats. Every field is a counter, so servers save the increments they
-- earned instead of whole records; two servers saving the same player can never
-- overwrite each other's progress. Kept free of Roblox services for Luau CLI tests.
export type Field = "Kills" | "Deaths" | "Wins" | "MatchesPlayed"

export type Stats = {
	Kills: number,
	Deaths: number,
	Wins: number,
	MatchesPlayed: number,
}

local FIELDS: { Field } = { "Kills", "Deaths", "Wins", "MatchesPlayed" }

local Schema = {
	VERSION = 1,
	FIELDS = table.freeze(FIELDS),
}

function Schema.empty(): Stats
	return { Kills = 0, Deaths = 0, Wins = 0, MatchesPlayed = 0 }
end

local function readCounter(value: unknown): number
	if typeof(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- Accepts anything the DataStore returns: nothing for new players, older records with
-- missing fields, or corrupted values, which fall back to zero.
function Schema.reconcile(raw: unknown): Stats
	local stats = Schema.empty()
	if typeof(raw) ~= "table" then
		return stats
	end
	local record = raw :: { [string]: unknown }
	for _, field in FIELDS do
		stats[field] = readCounter(record[field])
	end
	return stats
end

function Schema.add(base: Stats, delta: Stats): Stats
	local result = Schema.empty()
	for _, field in FIELDS do
		result[field] = base[field] + delta[field]
	end
	return result
end

function Schema.isEmpty(stats: Stats): boolean
	for _, field in FIELDS do
		if stats[field] ~= 0 then
			return false
		end
	end
	return true
end

function Schema.serialize(stats: Stats): { [string]: number }
	local record: { [string]: number } = { Version = Schema.VERSION }
	for _, field in FIELDS do
		record[field] = stats[field]
	end
	return record
end

return table.freeze(Schema)
