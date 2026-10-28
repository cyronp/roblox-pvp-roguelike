local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MatchConfig"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local HudKit = require(script.Parent.HudKit)
local useServerCountdown = require(script.Parent.useServerCountdown)
local e = React.createElement

local matchState = ReplicatedStorage:WaitForChild("MatchState") :: Folder

local PANEL_WIDTH = 200
local PANEL_HEIGHT = 58
local PANEL_TOP = 8

type MatchInfo = {
	state: string,
	endsAt: number?,
	leaderName: string?,
	leaderKills: number?,
	winnerName: string?,
	winnerKills: number?,
	endReason: string?,
}

local function readString(name: string): string?
	local value = matchState:GetAttribute(name)
	return if typeof(value) == "string" then value else nil
end

local function readNumber(name: string): number?
	local value = matchState:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

local function readMatch(): MatchInfo
	return {
		state = readString("State") or "Waiting",
		endsAt = readNumber("EndsAt"),
		leaderName = readString("LeaderName"),
		leaderKills = readNumber("LeaderKills"),
		winnerName = readString("WinnerName"),
		winnerKills = readNumber("WinnerKills"),
		endReason = readString("EndReason"),
	}
end

local function formatClock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function useMatchInfo(): MatchInfo
	local info, setInfo = React.useState(readMatch)
	React.useEffect(function()
		local pending: thread? = nil
		-- Several attributes change together at each phase; render them as one update.
		local connection = matchState.AttributeChanged:Connect(function()
			if pending then
				return
			end
			pending = task.defer(function()
				pending = nil
				setInfo(readMatch())
			end)
		end)
		setInfo(readMatch())
		return function()
			connection:Disconnect()
			if pending then
				task.cancel(pending)
			end
		end
	end, {})
	return info
end

local function usePlayerCount(): number
	local count, setCount = React.useState(#Players:GetPlayers())
	React.useEffect(function()
		local function update()
			-- PlayerRemoving fires before the player leaves the list.
			task.defer(function()
				setCount(#Players:GetPlayers())
			end)
		end
		local added = Players.PlayerAdded:Connect(update)
		local removing = Players.PlayerRemoving:Connect(update)
		update()
		return function()
			added:Disconnect()
			removing:Disconnect()
		end
	end, {})
	return count
end

local function ResultsBanner(props: { winnerName: string?, winnerKills: number?, endReason: string? })
	local scaleRef = React.useRef(nil)

	React.useEffect(function()
		local scale = scaleRef.current
		if not scale then
			return
		end
		scale.Scale = 0.6
		local pop = TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		pop:Play()
		return function()
			pop:Cancel()
			pop:Destroy()
		end
	end, {})

	local headline = if props.winnerName then `{string.upper(props.winnerName)} WINS!` else "NO WINNER"
	local detail = if props.winnerName and props.winnerKills
		then `{props.winnerKills} {if props.winnerKills == 1 then "KILL" else "KILLS"}`
		elseif props.endReason == "NotEnoughPlayers" then "Not enough players"
		else "Nobody scored a kill"

	return e("Frame", {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(340, 116),
		BackgroundTransparency = 1,
		Active = false,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Panel = e(HudKit.Panel, {
			position = UDim2.fromScale(0, 0),
			size = UDim2.fromScale(1, 1),
			gradient = Theme.GoldGradient,
			lipColor = Theme.GoldDark,
			children = {
				Caption = HudKit.label({
					Position = UDim2.fromOffset(0, 10),
					Size = UDim2.new(1, 0, 0, 18),
					Text = "ROUND OVER",
					TextSize = 18,
				}, 2),
				Headline = HudKit.label({
					Position = UDim2.fromOffset(12, 32),
					Size = UDim2.new(1, -24, 0, 44),
					Text = headline,
					TextScaled = true,
				}, 3, {
					Bounds = e("UITextSizeConstraint", { MinTextSize = 18, MaxTextSize = 40 }),
				}),
				Detail = HudKit.label({
					Position = UDim2.fromOffset(0, 80),
					Size = UDim2.new(1, 0, 0, 22),
					Text = detail,
					TextSize = 20,
				}, 2),
			},
		}),
	})
end

-- Top-center round status, plus the winner banner while results are shown.
return function()
	local info = useMatchInfo()
	local playerCount = usePlayerCount()
	local remaining = useServerCountdown(info.endsAt)

	local caption: string
	local value: string
	local footer: string?
	if info.state == "Active" then
		caption = "ROUND ENDS IN"
		value = formatClock(remaining)
		footer = if info.leaderName and info.leaderKills
			then `LEADER  {info.leaderName}  {info.leaderKills}/{Config.KILL_TARGET}`
			else `FIRST TO {Config.KILL_TARGET} KILLS`
	elseif info.state == "Intermission" then
		caption = "NEXT ROUND IN"
		value = formatClock(remaining)
		footer = "Warm up on the dummies"
	elseif info.state == "Results" then
		caption = "NEXT ROUND SOON"
		value = formatClock(remaining)
	else
		caption = "WAITING FOR PLAYERS"
		value = `{math.min(playerCount, Config.MIN_PLAYERS)} / {Config.MIN_PLAYERS}`
		footer = "Warm up on the dummies"
	end

	return e("Frame", {
		Name = "MatchStatus",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
	}, {
		Panel = e(HudKit.Panel, {
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, PANEL_TOP),
			size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
			children = {
				Caption = HudKit.label({
					Position = UDim2.fromOffset(0, 6),
					Size = UDim2.new(1, 0, 0, 14),
					Text = caption,
					TextSize = 13,
					TextColor3 = Theme.TextMuted,
				}, 1.5),
				Value = HudKit.label({
					Position = UDim2.fromOffset(0, 21),
					Size = UDim2.new(1, 0, 0, 30),
					Text = value,
					TextSize = 30,
					TextColor3 = if info.state == "Active" and remaining <= 10 then Theme.DangerLight else Theme.Text,
				}, 2.5),
			},
		}),
		Footer = if footer
			then HudKit.label({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, PANEL_TOP + PANEL_HEIGHT + Theme.Lip + 4),
				Size = UDim2.fromOffset(PANEL_WIDTH + 120, 18),
				Text = footer,
				TextSize = 16,
				TextColor3 = Theme.GoldLight,
			}, 2)
			else nil,
		Results = if info.state == "Results"
			then e(ResultsBanner, {
				winnerName = info.winnerName,
				winnerKills = info.winnerKills,
				endReason = info.endReason,
			})
			else nil,
	})
end
