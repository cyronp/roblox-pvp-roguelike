local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
local hitConfirmedRemote = ReplicatedStorage:WaitForChild("HitConfirmed") :: RemoteEvent
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local e = React.createElement

local BLACK = Color3.fromRGB(0, 0, 0)
local FADE_TIME = 0.25
local START_OFFSET = Vector3.new(0, 1.8, 0)
local KICK_OFFSET = Vector3.new(0, 2.35, 0)
local END_OFFSET = Vector3.new(0, 2.75, 0)

type Props = { tool: Tool }
type Feedback = {
	hitCount: number,
	totalDamage: number,
	adornee: BasePart,
	expiresAt: number,
	duration: number,
}

local function DamageHud(props: Props)
	local feedback, setFeedback = React.useState(nil :: Feedback?)
	local billboardRef = React.useRef(nil)
	local panelRef = React.useRef(nil)
	local scaleRef = React.useRef(nil)
	local rowRef = React.useRef(nil)
	local damageRef = React.useRef(nil)
	local strokeRef = React.useRef(nil)

	React.useEffect(function()
		local hitConnection = hitConfirmedRemote.OnClientEvent:Connect(function(tool: Tool, count: number, total: number, target: Model?, expiresAt: number, duration: number)
			if tool ~= props.tool then
				return
			end
			if count <= 0 or not target or expiresAt <= workspace:GetServerTimeNow() then
				return
			end
			local adornee = target:FindFirstChild("Head")
				or target:FindFirstChild("HumanoidRootPart")
				or target.PrimaryPart
				or target:FindFirstChildWhichIsA("BasePart", true)
			if not adornee or not adornee:IsA("BasePart") or not adornee:IsDescendantOf(workspace) then
				setFeedback(nil)
				return
			end
			setFeedback({ hitCount = count, totalDamage = total, adornee = adornee, expiresAt = expiresAt, duration = duration })
		end)
		local characterConnection = player.CharacterRemoving:Connect(function()
			setFeedback(nil)
		end)

		return function()
			hitConnection:Disconnect()
			characterConnection:Disconnect()
		end
	end, { props.tool })

	React.useEffect(function()
		local billboard = billboardRef.current
		local panel = panelRef.current
		local scale = scaleRef.current
		local row = rowRef.current
		local label = damageRef.current
		local stroke = strokeRef.current
		if not feedback or not billboard or not panel or not scale or not row or not label or not stroke then
			return
		end
		if not feedback.adornee:IsDescendantOf(workspace) then
			setFeedback(nil)
			return
		end
		local remaining = feedback.expiresAt - workspace:GetServerTimeNow()
		if remaining <= 0 then
			setFeedback(nil)
			return
		end

		panel.GroupTransparency = 0
		scale.Scale = 0.82
		row.Rotation = if feedback.hitCount % 2 == 0 then 8 else -8
		label.TextColor3 = Color3.fromRGB(255, 225, 135)
		stroke.Thickness = 5
		billboard.StudsOffsetWorldSpace = START_OFFSET
		local peakScale = 1.6 + math.min(feedback.hitCount, 12) * 0.01
		local pop = TweenService:Create(scale, TweenInfo.new(0.065, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = peakScale })
		local settle = TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		local tilt = TweenService:Create(row, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 })
		local flash = TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextColor3 = Color3.fromRGB(255, 255, 255) })
		local outline = TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Thickness = 3 })
		local kickDuration = math.min(0.12, remaining)
		local kick = TweenService:Create(billboard, TweenInfo.new(kickDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = KICK_OFFSET })
		local rise = TweenService:Create(billboard, TweenInfo.new(math.max(0.01, remaining - kickDuration), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = END_OFFSET })
		local popConnection = pop.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				settle:Play()
			end
		end)
		local kickConnection = kick.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				rise:Play()
			end
		end)
		local fadeDuration = math.min(FADE_TIME, remaining)
		local fade = TweenService:Create(panel, TweenInfo.new(fadeDuration), { GroupTransparency = 1 })
		local fadeConnection = fade.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				setFeedback(nil)
			end
		end)
		local targetConnection = feedback.adornee.AncestryChanged:Connect(function()
			if not feedback.adornee:IsDescendantOf(workspace) then
				setFeedback(nil)
			end
		end)
		pop:Play()
		tilt:Play()
		flash:Play()
		outline:Play()
		kick:Play()
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
			kickConnection:Disconnect()
			targetConnection:Disconnect()
			for _, tween in { pop, settle, tilt, flash, outline, kick, rise, fade } do
				tween:Cancel()
				tween:Destroy()
			end
		end
	end, { feedback or false })

	if not feedback then
		return nil
	end

	-- A portal keeps the world popup independent of the crosshair's position and visibility.
	return ReactRoblox.createPortal(e("BillboardGui", {
		ref = billboardRef,
		Name = "EnemyDamage",
		Adornee = feedback.adornee,
		Size = UDim2.fromOffset(300, 160),
		-- Camera-relative right keeps the popup on the enemy's upper right as the view rotates.
		StudsOffset = Vector3.new(2.1, 0, 0),
		StudsOffsetWorldSpace = START_OFFSET,
		AlwaysOnTop = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		LightInfluence = 0,
		MaxDistance = 350,
	}, {
		Numbers = e("CanvasGroup", {
			ref = panelRef,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Row = e("Frame", {
				ref = rowRef,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 0, 0, 64),
				BackgroundTransparency = 1,
			}, {
				-- Scale the centered row so the larger burst stays inside the billboard.
				Scale = e("UIScale", { ref = scaleRef }),
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Damage = e("TextLabel", {
					ref = damageRef,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 64),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Text = string.format("%.0f", feedback.totalDamage),
					TextSize = math.min(48 + (feedback.hitCount - 1), 56),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					LayoutOrder = 1,
				}, {
					Stroke = e("UIStroke", { ref = strokeRef, Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
				}),
			}),
		}),
	}), playerGui)
end

return DamageHud
