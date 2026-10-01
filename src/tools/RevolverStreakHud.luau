local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local HitCount = require(script.Parent:WaitForChild("HitCount"))
local StreakTimer = require(script.Parent:WaitForChild("StreakTimer"))
local hitConfirmedRemote = ReplicatedStorage:WaitForChild("HitConfirmed") :: RemoteEvent
local player = Players.LocalPlayer
local e = React.createElement

type Props = { tool: Tool }
type Streak = { count: number, expiresAt: number, duration: number }

local function StreakHud(props: Props)
	local streak, setStreak = React.useState(nil :: Streak?)
	local panelRef = React.useRef(nil)
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local hitConnection = hitConfirmedRemote.OnClientEvent:Connect(function(tool: Tool, count: number, _damage: number, _target: Model?, expiresAt: number, duration: number)
			if tool ~= props.tool or count <= 0 or expiresAt <= workspace:GetServerTimeNow() then
				return
			end
			setStreak({ count = count, expiresAt = expiresAt, duration = duration })
		end)
		local characterConnection = player.CharacterRemoving:Connect(function()
			setStreak(nil)
		end)

		return function()
			hitConnection:Disconnect()
			characterConnection:Disconnect()
		end
	end, { props.tool })

	React.useEffect(function()
		local panel = panelRef.current
		local scale = scaleRef.current
		if not streak or not panel or not scale then
			return
		end
		local remaining = streak.expiresAt - workspace:GetServerTimeNow()
		if remaining <= 0 then
			setStreak(nil)
			return
		end

		panel.GroupTransparency = 0
		scale.Scale = 0.86
		local pop = TweenService:Create(scale, TweenInfo.new(0.065, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1.4 })
		local settle = TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 })
		local popConnection = pop.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				settle:Play()
			end
		end)
		local fadeDuration = math.min(0.25, remaining)
		local fade = TweenService:Create(panel, TweenInfo.new(fadeDuration), { GroupTransparency = 1 })
		local fadeConnection = fade.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				setStreak(nil)
			end
		end)
		pop:Play()
		local expiry: thread? = nil
		expiry = task.delay(remaining - fadeDuration, function()
			expiry = nil
			fade:Play()
		end)

		return function()
			if expiry then
				task.cancel(expiry)
			end
			fadeConnection:Disconnect()
			popConnection:Disconnect()
			for _, tween in { pop, settle, fade } do
				tween:Cancel()
				tween:Destroy()
			end
		end
	end, { streak or false })

	if not streak then
		return nil
	end

	return e("CanvasGroup", {
		ref = panelRef,
		Name = "HitStreak",
		AnchorPoint = Vector2.new(1, 0),
		-- Show temporary streak feedback beneath the combined combat HUD.
		Position = UDim2.new(1, -20, 0, 72),
		Size = UDim2.fromOffset(76, 60),
		BackgroundTransparency = 1,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Count = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(52, 38),
			BackgroundTransparency = 1,
		}, {
			Label = e(HitCount, { count = streak.count }),
		}),
		Timer = e(StreakTimer, { expiresAt = streak.expiresAt, duration = streak.duration, count = streak.count }),
	})
end

return StreakHud
