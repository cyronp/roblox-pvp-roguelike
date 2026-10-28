local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
local DeathScreen = require(script.Parent.DeathScreen)
local KillFeed = require(script.Parent.KillFeed)
local MatchStatus = require(script.Parent.MatchStatus)
local e = React.createElement

local function MatchHud()
	return e(React.Fragment, nil, {
		MatchHud = e("ScreenGui", {
			Name = "MatchHud",
			ResetOnSpawn = false,
			DisplayOrder = 6,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Status = e(MatchStatus),
			Feed = e(KillFeed),
		}),
		-- Below the other HUDs so the vitals and kill feed stay readable over the dimmed view.
		DeathScreen = e("ScreenGui", {
			Name = "DeathScreen",
			ResetOnSpawn = false,
			DisplayOrder = 1,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Overlay = e(DeathScreen),
		}),
	})
end

-- A dedicated root prevents React from clearing other HUDs already in PlayerGui.
local hudContainer = Instance.new("Folder")
hudContainer.Name = "MatchHudRoot"
local hudRoot = ReactRoblox.createRoot(hudContainer)
hudRoot:render(ReactRoblox.createPortal(e(MatchHud), playerGui))

script.Destroying:Connect(function()
	hudRoot:unmount()
	hudContainer:Destroy()
end)
