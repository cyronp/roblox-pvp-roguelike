local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ExperienceConfig"))

type Progress = {
	level: number,
	xp: number,
}

local progressByPlayer: { [Player]: Progress } = {}
local Experience = {}

local function publishProgress(player: Player, progress: Progress)
	player:SetAttribute("Level", progress.level)
	player:SetAttribute("XP", progress.xp)
end

function Experience.Reset(player: Player)
	local progress = { level = Config.START_LEVEL, xp = 0 }
	progressByPlayer[player] = progress
	publishProgress(player, progress)
end

function Experience.RemovePlayer(player: Player)
	progressByPlayer[player] = nil
end

-- Called only by the server's confirmed lethal-hit path, never by a client remote.
function Experience.AwardKill(player: Player)
	local progress = progressByPlayer[player]
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not progress or player.Parent ~= Players or not humanoid or humanoid.Health <= 0 then
		return
	end

	progress.xp += Config.XP_PER_KILL
	local requiredXp = Config.getRequiredXp(progress.level)
	while progress.xp >= requiredXp do
		progress.xp -= requiredXp
		progress.level += 1
		requiredXp = Config.getRequiredXp(progress.level)
	end

	publishProgress(player, progress)
end

return Experience
