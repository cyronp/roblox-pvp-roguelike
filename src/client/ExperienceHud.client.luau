local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ExperienceConfig"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local e = React.createElement

local BAR_HEIGHT = 24
local BLUE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 90, 225)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(40, 155, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(95, 215, 255)),
})

type Progress = { level: number, xp: number }

local function readProgress(): Progress
	local level = player:GetAttribute("Level")
	local xp = player:GetAttribute("XP")
	return {
		level = if typeof(level) == "number" then math.max(Config.START_LEVEL, math.floor(level)) else Config.START_LEVEL,
		xp = if typeof(xp) == "number" then math.max(0, xp) else 0,
	}
end

local function ExperienceHud()
	local progress, setProgress = React.useState(readProgress())
	local fillRef = React.useRef(nil)
	local previousLevel = React.useRef(progress.level)
	local requiredXp = Config.getRequiredXp(progress.level)
	local fraction = math.clamp(progress.xp / requiredXp, 0, 1)

	React.useEffect(function()
		local pendingUpdate: thread? = nil
		local function scheduleUpdate()
			if pendingUpdate then
				return
			end
			-- Read the level and XP together after a batch of replicated attribute changes.
			pendingUpdate = task.defer(function()
				pendingUpdate = nil
				setProgress(readProgress())
			end)
		end
		local levelConnection = player:GetAttributeChangedSignal("Level"):Connect(scheduleUpdate)
		local xpConnection = player:GetAttributeChangedSignal("XP"):Connect(scheduleUpdate)
		scheduleUpdate()

		return function()
			levelConnection:Disconnect()
			xpConnection:Disconnect()
			if pendingUpdate then
				task.cancel(pendingUpdate)
			end
		end
	end, {})

	React.useEffect(function()
		local fill = fillRef.current
		if not fill then
			return
		end
		if previousLevel.current ~= progress.level or progress.xp == 0 then
			previousLevel.current = progress.level
			fill.Size = UDim2.fromScale(fraction, 1)
			return
		end

		local tween = TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(fraction, 1),
		})
		tween:Play()
		return function()
			tween:Cancel()
			tween:Destroy()
		end
	end, { fraction, progress.level })

	return e(React.Fragment, nil, {
		Bar = e("ScreenGui", {
			Name = "ExperienceBar",
			ResetOnSpawn = false,
			DisplayOrder = 5,
			ScreenInsets = Enum.ScreenInsets.None,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Track = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
				BackgroundColor3 = Color3.fromRGB(12, 24, 45),
				BorderSizePixel = 0,
				ClipsDescendants = true,
			}, {
				Fill = e("Frame", {
					ref = fillRef,
					Size = UDim2.fromScale(0, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
				}, {
					Gradient = e("UIGradient", {
						Color = BLUE_GRADIENT,
					}),
				}),
				Progress = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = UIFonts.Bold,
					Text = `{progress.xp}/{requiredXp}`,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					TextStrokeColor3 = Color3.fromRGB(8, 16, 30),
					TextStrokeTransparency = 0.2,
					ZIndex = 2,
				}),
			}),
		}),
		-- Keep text inside device safe bounds while the decorative bar spans the entire screen.
		Labels = e("ScreenGui", {
			Name = "ExperienceLabels",
			ResetOnSpawn = false,
			DisplayOrder = 5,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		}, {
			Level = e("TextLabel", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -18, 1, -(BAR_HEIGHT + 8)),
				Size = UDim2.new(1, -36, 0, 42),
				BackgroundTransparency = 1,
				FontFace = UIFonts.ExtraBold,
				Text = `LVL {progress.level}`,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 32,
				TextXAlignment = Enum.TextXAlignment.Right,
			}, {
				Gradient = e("UIGradient", { Color = BLUE_GRADIENT, Rotation = -90 }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(8, 16, 30),
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				}),
			}),
		}),
	})
end

-- A dedicated root prevents React from clearing other HUDs already in PlayerGui.
local hudContainer = Instance.new("Folder")
hudContainer.Name = "ExperienceHudRoot"
local hudRoot = ReactRoblox.createRoot(hudContainer)
hudRoot:render(ReactRoblox.createPortal(e(ExperienceHud), playerGui))

script.Destroying:Connect(function()
	hudRoot:unmount()
	hudContainer:Destroy()
end)
