local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))

local function getGradient(count: number): ColorSequence
	if count <= 3 then
		return ColorSequence.new(Theme.Paper)
	elseif count <= 6 then
		return Theme.BlueGradient
	elseif count <= 8 then
		return ColorSequence.new(Theme.GoldLight, Theme.Orange)
	end
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.GoldLight),
		ColorSequenceKeypoint.new(0.35, Theme.Gold),
		ColorSequenceKeypoint.new(0.7, Theme.Orange),
		ColorSequenceKeypoint.new(1, Theme.Danger),
	})
end

return getGradient
