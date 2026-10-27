local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ExperienceConfig"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local GameplayAudio = require(script.Parent.GameplayAudio)
local HealthBar = require(script.Parent.HealthBar)
local HudKit = require(script.Parent.HudKit)
local e = React.createElement

type Progress = { level: number, xp: number }

local function readProgress(): Progress
	local level = player:GetAttribute("Level")
	local xp = player:GetAttribute("XP")
	return {
		level = if typeof(level) == "number" then math.max(Config.START_LEVEL, math.floor(level)) else Config.START_LEVEL,
		xp = if typeof(xp) == "number" then math.max(0, xp) else 0,
	}
end

local VITALS_GAP = 10

local function LevelBadge(props: { level: number })
	local scaleRef = React.useRef(nil)
	local shownLevel = React.useRef(props.level)

	React.useEffect(function()
		local scale = scaleRef.current
		local leveledUp = props.level > shownLevel.current
		shownLevel.current = props.level
		if not scale or not leveledUp then
			return
		end
		scale.Scale = 1.35
		local settle = TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		settle:Play()
		return function()
			settle:Cancel()
			settle:Destroy()
			scale.Scale = 1
		end
	end, { props.level })

	return e("Frame", {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(Theme.VitalsHeight / 2, Theme.VitalsHeight / 2),
		Size = UDim2.fromOffset(Theme.VitalsHeight, Theme.VitalsHeight),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 2,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Badge = e(HudKit.Panel, {
			position = UDim2.fromScale(0, 0),
			size = UDim2.fromScale(1, 1),
			gradient = Theme.GoldGradient,
			lipColor = Theme.GoldDark,
			children = {
				Caption = HudKit.label({
					Position = UDim2.fromOffset(0, 5),
					Size = UDim2.new(1, 0, 0, 13),
					Text = "LVL",
					TextSize = 13,
				}, 1.5),
				Number = HudKit.label({
					Position = UDim2.fromOffset(4, 18),
					Size = UDim2.new(1, -8, 1, -22),
					Text = tostring(props.level),
					TextScaled = true,
				}, 2.5, {
					Bounds = e("UITextSizeConstraint", { MinTextSize = 14, MaxTextSize = 30 }),
				}),
			},
		}),
	})
end

local function ExperienceHud()
	local progress, setProgress = React.useState(readProgress())
	local viewportWidth, setViewportWidth = React.useState(1280)
	local fillRef = React.useRef(nil)
	local previousLevel = React.useRef(progress.level)
	local requiredXp = Config.getRequiredXp(progress.level)
	local fraction = math.clamp(progress.xp / requiredXp, 0, 1)
	local dockWidth = math.clamp(viewportWidth * 0.42, 260, 460)
	local barsLeft = Theme.VitalsHeight + VITALS_GAP

	React.useEffect(function()
		local pendingUpdate: thread? = nil
		local lastLevel = readProgress().level
		local function scheduleUpdate()
			if pendingUpdate then
				return
			end
			-- Read the level and XP together after a batch of replicated attribute changes.
			pendingUpdate = task.defer(function()
				pendingUpdate = nil
				local nextProgress = readProgress()
				if nextProgress.level > lastLevel then
					GameplayAudio.play("LevelUp")
				end
				lastLevel = nextProgress.level
				setProgress(nextProgress)
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

	return e("ScreenGui", {
		Name = "ExperienceHud",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Bounds = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Active = false,
			[React.Change.AbsoluteSize] = function(frame: Frame)
				setViewportWidth(frame.AbsoluteSize.X)
			end,
		}, {
			-- Level, health, and XP share one compact cluster at the bottom center.
			Dock = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -(Theme.BottomInset + Theme.Lip)),
				Size = UDim2.fromOffset(dockWidth, Theme.VitalsHeight),
				BackgroundTransparency = 1,
				Active = false,
			}, {
				Level = e(LevelBadge, { level = progress.level }),
				Health = e(HealthBar, {
					player = player,
					position = UDim2.fromOffset(barsLeft, 0),
					size = UDim2.new(1, -barsLeft, 0, 32),
				}),
				Experience = e(HudKit.Meter, {
					position = UDim2.fromOffset(barsLeft, 40),
					size = UDim2.new(1, -barsLeft, 0, 18),
					fraction = fraction,
					fillRef = fillRef,
					radius = 8,
					gradient = Theme.BlueGradient,
					children = {
						Progress = HudKit.label({
							Size = UDim2.fromScale(1, 1),
							Text = `{progress.xp} / {requiredXp} XP`,
							TextSize = 13,
							ZIndex = 3,
						}, 1.5),
					},
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
