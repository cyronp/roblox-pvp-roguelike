local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local e = React.createElement

local killFeedRemote = ReplicatedStorage:WaitForChild("KillFeed") :: RemoteEvent
local localPlayer = Players.LocalPlayer

local MAX_ENTRIES = 4
local ENTRY_LIFETIME = 5
local ENTRY_HEIGHT = 26
-- Below the match status panel and its footer line.
local FEED_TOP = 104

type Entry = {
	id: number,
	text: string,
	involvesYou: boolean,
}

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function colorName(player: Player, color: Color3): string
	return `<font color="#{color:ToHex()}">{escape(player.DisplayName)}</font>`
end

local function describe(victim: Player, killer: Player?): string
	local victimName = colorName(victim, if victim == localPlayer then Theme.GoldLight else Theme.DangerLight)
	if not killer then
		return `{victimName} was eliminated`
	end
	local killerName = colorName(killer, if killer == localPlayer then Theme.GoldLight else Theme.BlueLight)
	return `{killerName}  eliminated  {victimName}`
end

local function FeedEntry(props: { entry: Entry, order: number })
	return e("Frame", {
		LayoutOrder = props.order,
		Size = UDim2.fromOffset(0, ENTRY_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Active = false,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.SmallRadius) }),
		Outline = e("UIStroke", {
			Color = if props.entry.involvesYou then Theme.Gold else Theme.Outline,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Text = e("TextLabel", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = UIFonts.ExtraBold,
			RichText = true,
			Text = props.entry.text,
			TextColor3 = Theme.Text,
			TextSize = 15,
		}),
	})
end

-- Recent eliminations, newest first, visible to everyone in the server.
return function()
	local entries, setEntries = React.useState({} :: { Entry })

	React.useEffect(function()
		local nextId = 0
		local expiries: { thread } = {}
		local connection = killFeedRemote.OnClientEvent:Connect(function(victim: unknown, killer: unknown)
			if typeof(victim) ~= "Instance" or not victim:IsA("Player") then
				return
			end
			local killerPlayer = if typeof(killer) == "Instance" and killer:IsA("Player") then killer else nil
			nextId += 1
			local entry: Entry = {
				id = nextId,
				text = describe(victim, killerPlayer),
				involvesYou = victim == localPlayer or killerPlayer == localPlayer,
			}
			setEntries(function(current: { Entry })
				local updated = { entry }
				for index = 1, math.min(#current, MAX_ENTRIES - 1) do
					table.insert(updated, current[index])
				end
				return updated
			end)
			table.insert(expiries, task.delay(ENTRY_LIFETIME, function()
				setEntries(function(current: { Entry })
					local kept = {}
					for _, existing in current do
						if existing.id ~= entry.id then
							table.insert(kept, existing)
						end
					end
					return kept
				end)
			end))
			-- Forget expiry threads that have already finished.
			if #expiries > MAX_ENTRIES * 4 then
				local alive = {}
				for _, thread in expiries do
					if coroutine.status(thread) == "suspended" then
						table.insert(alive, thread)
					end
				end
				expiries = alive
			end
		end)
		return function()
			connection:Disconnect()
			for _, thread in expiries do
				if coroutine.status(thread) == "suspended" then
					task.cancel(thread)
				end
			end
		end
	end, {})

	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	}
	for index, entry in entries do
		children[`Entry{entry.id}`] = e(FeedEntry, { entry = entry, order = index })
	end

	return e("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, FEED_TOP),
		Size = UDim2.new(0.9, 0, 0, MAX_ENTRIES * (ENTRY_HEIGHT + 4)),
		BackgroundTransparency = 1,
		Active = false,
	}, children)
end
