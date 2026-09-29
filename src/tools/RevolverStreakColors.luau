local function getGradient(count: number): ColorSequence
	if count <= 3 then
		return ColorSequence.new(Color3.fromRGB(255, 255, 255))
	elseif count <= 6 then
		return ColorSequence.new(Color3.fromRGB(130, 235, 255), Color3.fromRGB(40, 105, 255))
	elseif count <= 8 then
		return ColorSequence.new(Color3.fromRGB(255, 214, 106), Color3.fromRGB(255, 125, 28))
	end
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 163)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 196, 45)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 105, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 40, 15)),
	})
end

return getGradient
