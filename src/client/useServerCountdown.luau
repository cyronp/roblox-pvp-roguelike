local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local TICK = 0.2

local function secondsUntil(endsAt: number?): number
	if not endsAt then
		return 0
	end
	return math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
end

-- Whole seconds left until a server timestamp. React skips renders while the value is unchanged.
return function(endsAt: number?): number
	local remaining, setRemaining = React.useState(function()
		return secondsUntil(endsAt)
	end)

	React.useEffect(function()
		setRemaining(secondsUntil(endsAt))
		if not endsAt then
			return
		end
		local ticker = task.spawn(function()
			while true do
				task.wait(TICK)
				setRemaining(secondsUntil(endsAt))
			end
		end)
		return function()
			task.cancel(ticker)
		end
	end, { endsAt or false })

	return remaining
end
