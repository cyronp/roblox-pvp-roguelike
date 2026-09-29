local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local getGradient = require(script.Parent:WaitForChild("StreakColors"))
local e = React.createElement

type Props = {
	expiresAt: number,
	duration: number,
	count: number,
}

local function StreakTimer(props: Props)
	local remaining, setRemaining = React.useBinding(math.max(0, props.expiresAt - workspace:GetServerTimeNow()))

	React.useEffect(function()
		local elapsed = 0
		local function update()
			setRemaining(math.max(0, props.expiresAt - workspace:GetServerTimeNow()))
		end
		update()
		-- Only this active popup updates, at 10 Hz; bindings avoid rerendering the damage UI.
		local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
			elapsed += deltaTime
			if elapsed >= 0.1 then
				elapsed = 0
				update()
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { props.expiresAt, props.duration })

	return e("Frame", {
		Name = "StreakCountdown",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.fromOffset(52, 4),
		BackgroundTransparency = 1,
	}, {
		Track = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("Frame", {
				Size = remaining:map(function(seconds: number)
					return UDim2.fromScale(math.clamp(seconds / props.duration, 0, 1), 1)
				end),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Gradient = e("UIGradient", { Color = getGradient(props.count), Rotation = 0 }),
			}),
		}),
	})
end

return StreakTimer
