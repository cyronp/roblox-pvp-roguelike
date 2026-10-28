local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MatchConfig"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local HudKit = require(script.Parent.HudKit)
local useServerCountdown = require(script.Parent.useServerCountdown)
local e = React.createElement

local killFeedRemote = ReplicatedStorage:WaitForChild("KillFeed") :: RemoteEvent
local player = Players.LocalPlayer

-- Shows who eliminated the local player and when they will respawn.
return function()
	local respawnAt, setRespawnAt = React.useState(nil :: number?)
	local killerName, setKillerName = React.useState(nil :: string?)
	local remaining = useServerCountdown(respawnAt)

	React.useEffect(function()
		local diedConnection: RBXScriptConnection? = nil
		local childConnection: RBXScriptConnection? = nil
		local function disconnect()
			if diedConnection then
				diedConnection:Disconnect()
				diedConnection = nil
			end
			if childConnection then
				childConnection:Disconnect()
				childConnection = nil
			end
		end
		local function bind(humanoid: Humanoid)
			diedConnection = humanoid.Died:Connect(function()
				-- The server respawns after Players.RespawnTime; this estimate is presentation only.
				setRespawnAt(workspace:GetServerTimeNow() + Config.RESPAWN_TIME)
			end)
		end
		local function watch(character: Model?)
			disconnect()
			setRespawnAt(nil)
			setKillerName(nil)
			if not character then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				bind(humanoid)
				return
			end
			childConnection = character.ChildAdded:Connect(function(child: Instance)
				if child:IsA("Humanoid") and not diedConnection then
					bind(child)
				end
			end)
		end

		local added = player.CharacterAdded:Connect(watch)
		local feed = killFeedRemote.OnClientEvent:Connect(function(victim: unknown, killer: unknown)
			if victim == player and typeof(killer) == "Instance" and killer:IsA("Player") then
				setKillerName(killer.DisplayName)
			end
		end)
		watch(player.Character)
		return function()
			disconnect()
			added:Disconnect()
			feed:Disconnect()
		end
	end, {})

	if not respawnAt then
		return nil
	end

	return e("Frame", {
		Name = "DeathScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Outline,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Active = false,
	}, {
		Title = HudKit.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.new(0.9, 0, 0, 56),
			Text = "ELIMINATED",
			TextScaled = true,
			TextColor3 = Theme.DangerLight,
		}, 3, {
			Bounds = e("UITextSizeConstraint", { MinTextSize = 28, MaxTextSize = 56 }),
		}),
		Killer = if killerName
			then HudKit.label({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.42, 34),
				Size = UDim2.new(0.9, 0, 0, 26),
				Text = `by {killerName}`,
				TextSize = 24,
			}, 2)
			else nil,
		Respawn = HudKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.42, 68),
			Size = UDim2.new(0.9, 0, 0, 20),
			Text = if remaining > 0 then `Respawning in {remaining}` else "Respawning...",
			TextSize = 18,
			TextColor3 = Theme.TextMuted,
		}, 2),
	})
end
