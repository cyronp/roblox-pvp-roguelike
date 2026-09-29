local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local killConfirmedRemote = ReplicatedStorage:WaitForChild("KillConfirmed") :: RemoteEvent
local sound = SoundService:WaitForChild("KillConfirmation") :: Sound

-- Only the server sends confirmations; playback stays local to the credited shooter.
local confirmationConnection = killConfirmedRemote.OnClientEvent:Connect(function()
	SoundService:PlayLocalSound(sound)
end)

task.spawn(function()
	local success, message = pcall(function()
		ContentProvider:PreloadAsync({ sound })
	end)
	if not success then
		warn(`Failed to preload kill confirmation audio: {message}`)
	end
end)

script.Destroying:Connect(function()
	confirmationConnection:Disconnect()
end)
