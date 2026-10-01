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
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
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

	return e("ScreenGui", {
		Name = "ExperienceHud",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Dock = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -Theme.BottomInset),
			Size = UDim2.new(1, -32, 0, Theme.ProgressHeight),
			BackgroundTransparency = 1,
		}, {
			Level = e("TextLabel", {
				Size = UDim2.fromOffset(78, Theme.ProgressHeight),
				BackgroundColor3 = Theme.White,
				BorderSizePixel = 0,
				FontFace = UIFonts.ExtraBold,
				Text = `LVL {progress.level}`,
				TextColor3 = Theme.Ink,
				TextScaled = true,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.Radius) }),
				Outline = e("UIStroke", { Color = Theme.Ink, Thickness = Theme.Border, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Gradient = e("UIGradient", { Color = Theme.GoldGradient, Rotation = 90 }),
				Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
				Bounds = e("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = 18 }),
			}),
			Track = e("Frame", {
				Position = UDim2.fromOffset(88, 3),
				Size = UDim2.new(1, -88, 1, -6),
				BackgroundColor3 = Theme.Ink,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.Radius) }),
				Outline = e("UIStroke", { Color = Theme.Ink, Thickness = Theme.Border }),
				Fill = e("Frame", {
					ref = fillRef,
					Size = UDim2.fromScale(0, 1),
					BackgroundColor3 = Theme.White,
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.Radius) }),
					Gradient = e("UIGradient", { Color = Theme.BlueGradient, Rotation = 90 }),
					Shine = e("Frame", {
						Position = UDim2.fromScale(0.04, 0.12), Size = UDim2.fromScale(0.92, 0.14),
						BackgroundColor3 = Theme.White, BackgroundTransparency = 0.65, BorderSizePixel = 0,
					}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
				}),
				Progress = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = UIFonts.ExtraBold,
					Text = `{progress.xp} / {requiredXp} XP`,
					TextColor3 = Theme.Paper,
					TextSize = 13,
					ZIndex = 2,
				}, {
					Outline = e("UIStroke", { Color = Theme.Ink, Thickness = 1.2 }),
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
