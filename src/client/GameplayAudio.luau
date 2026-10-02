local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

type Cue = "LevelUp" | "Dash" | "UpgradeChoose"

local sounds: { [string]: Sound } = {}
for _, name in { "LevelUp", "Dash", "UpgradeChoose" } do
	sounds[name] = SoundService:WaitForChild(name) :: Sound
end

task.spawn(function()
	local assets: { Instance } = {}
	for name, sound in sounds do
		if sound.SoundId == "" then
			warn(`{name} audio needs an uploaded SoundId in default.project.json; see assets/audio/README.md`)
		else
			table.insert(assets, sound)
		end
	end
	if #assets == 0 then return end
	local success, message = pcall(function()
		ContentProvider:PreloadAsync(assets, function(assetId, status)
			if status ~= Enum.AssetFetchStatus.Success then
				warn(`Failed to preload gameplay audio {assetId}: {status.Name}`)
			end
		end)
	end)
	if not success then
		warn(`Failed to preload gameplay audio: {message}`)
	end
end)

local GameplayAudio = {}

function GameplayAudio.play(name: Cue)
	local sound = sounds[name]
	if sound.SoundId == "" then return end
	-- Reuse each UI cue and restart it instead of stacking bursts of confirmations.
	sound:Stop()
	sound:Play()
end

function GameplayAudio.create(name: Cue, parent: Instance): Sound
	local sound = sounds[name]:Clone()
	sound.Parent = parent
	return sound
end

return GameplayAudio
