local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MatchConfig"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIFonts"))
local HudKit = require(script.Parent.HudKit)
local deployRemote = ReplicatedStorage:WaitForChild("Deploy") :: RemoteEvent
local e = React.createElement

local GAME_TITLE = "REVOLVER ARENA"
-- Re-enable PLAY if the server has not deployed us by then, e.g. after a dropped request.
local DEPLOY_TIMEOUT = 5
local COLUMN_WIDTH = 420
local BUTTON_HEIGHT = 64

-- The camera slowly circles the arena while the menu is open.
local ORBIT_CENTER = Vector3.new(0, 8, 0)
local ORBIT_RADIUS = 150
local ORBIT_HEIGHT = 70
local ORBIT_SPEED = 0.04

type Stats = { wins: number, kills: number, deaths: number }

local function isDeployed(): boolean
	return player:GetAttribute("Deployed") == true
end

local function readStat(field: string): number
	local value = player:GetAttribute(`Lifetime{field}`)
	return if typeof(value) == "number" then value else 0
end

local function readStats(): Stats
	return { wins = readStat("Wins"), kills = readStat("Kills"), deaths = readStat("Deaths") }
end

local function useMenuCamera()
	React.useEffect(function()
		local angle = 0
		RunService:BindToRenderStep("MainMenuCamera", Enum.RenderPriority.Camera.Value + 2, function(deltaTime: number)
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			angle += deltaTime * ORBIT_SPEED
			camera.CameraType = Enum.CameraType.Scriptable
			local eye = ORBIT_CENTER + Vector3.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(angle) * ORBIT_RADIUS)
			camera.CFrame = CFrame.lookAt(eye, ORBIT_CENTER)
		end)
		return function()
			RunService:UnbindFromRenderStep("MainMenuCamera")
			local camera = workspace.CurrentCamera
			if camera then
				-- Hand control back to the default camera, which follows the new character.
				camera.CameraType = Enum.CameraType.Custom
			end
		end
	end, {})
end

local function useStats(): Stats
	local stats, setStats = React.useState(readStats)
	React.useEffect(function()
		local connections = {}
		for _, field in { "Wins", "Kills", "Deaths" } do
			table.insert(connections, player:GetAttributeChangedSignal(`Lifetime{field}`):Connect(function()
				setStats(readStats())
			end))
		end
		setStats(readStats())
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})
	return stats
end

local function StatColumn(props: { label: string, value: string, order: number })
	return e("Frame", {
		LayoutOrder = props.order,
		Size = UDim2.fromScale(0.25, 1),
		BackgroundTransparency = 1,
		Active = false,
	}, {
		Value = HudKit.label({
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 28),
			Text = props.value,
			TextSize = 28,
		}, 2.5),
		Label = HudKit.label({
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 14),
			Text = props.label,
			TextSize = 13,
			TextColor3 = Theme.TextMuted,
		}, 1.5),
	})
end

local function PlayButton(props: { waiting: boolean, onPress: () -> () })
	local buttonRef = React.useRef(nil)

	React.useEffect(function()
		-- Gamepads need a selected button to press PLAY with the A button.
		if UserInputService.GamepadEnabled and buttonRef.current then
			GuiService.SelectedObject = buttonRef.current
		end
	end, {})

	return e("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(0, 240, 0, BUTTON_HEIGHT + Theme.Lip),
		BackgroundTransparency = 1,
		Active = false,
	}, {
		Lip = e("Frame", {
			Position = UDim2.fromOffset(0, Theme.Lip),
			Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
			BackgroundColor3 = Theme.GoldDark,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.PanelRadius) }),
			Outline = e("UIStroke", { Color = Theme.Outline, Thickness = Theme.PanelBorder, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
		Button = e("TextButton", {
			ref = buttonRef,
			Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
			BackgroundColor3 = Theme.White,
			BorderSizePixel = 0,
			AutoButtonColor = not props.waiting,
			Selectable = true,
			FontFace = UIFonts.Display,
			Text = if props.waiting then "DEPLOYING..." else "PLAY",
			TextColor3 = Theme.Text,
			TextSize = if props.waiting then 26 else 36,
			ZIndex = 2,
			[React.Event.Activated] = function()
				if not props.waiting then
					props.onPress()
				end
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.PanelRadius) }),
			Outline = e("UIStroke", { Color = Theme.Outline, Thickness = Theme.PanelBorder, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Gradient = e("UIGradient", { Color = Theme.GoldGradient, Rotation = 90 }),
			TextOutline = e("UIStroke", { Color = Theme.Outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
		}),
	})
end

local function MainMenu()
	local waiting, setWaiting = React.useState(false)
	local stats = useStats()
	useMenuCamera()

	React.useEffect(function()
		if not waiting then
			return
		end
		local timeout = task.delay(DEPLOY_TIMEOUT, function()
			setWaiting(false)
		end)
		return function()
			task.cancel(timeout)
		end
	end, { waiting })

	local function onPress()
		setWaiting(true)
		deployRemote:FireServer()
	end

	local kd = if stats.deaths > 0 then stats.kills / stats.deaths else stats.kills
	local hint = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "Tap to shoot  ·  DASH button to dash  ·  Tap a number to upgrade"
		else "Click to shoot  ·  SHIFT to dash  ·  1 / 2 / 3 to pick upgrades"

	return e("ScreenGui", {
		Name = "MainMenu",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		-- Darker at the top and bottom so the menu stays readable over the arena and HUD.
		Backdrop = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Outline,
			BorderSizePixel = 0,
			Active = true,
		}, {
			Gradient = e("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.25),
					NumberSequenceKeypoint.new(0.45, 0.6),
					NumberSequenceKeypoint.new(1, 0.1),
				}),
			}),
		}),
		Column = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.92, 0, 0, 380),
			BackgroundTransparency = 1,
			Active = false,
		}, {
			Width = e("UISizeConstraint", { MaxSize = Vector2.new(COLUMN_WIDTH, math.huge) }),
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 16),
			}),
			Title = HudKit.label({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 64),
				Text = GAME_TITLE,
				TextScaled = true,
			}, 4, {
				Bounds = e("UITextSizeConstraint", { MinTextSize = 28, MaxTextSize = 60 }),
			}),
			Subtitle = HudKit.label({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 20),
				Text = `FREE-FOR-ALL  ·  FIRST TO {Config.KILL_TARGET} KILLS`,
				TextSize = 18,
				TextColor3 = Theme.GoldLight,
			}, 2),
			Play = e(PlayButton, { waiting = waiting, onPress = onPress }),
			Stats = e("Frame", {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 64 + Theme.Lip),
				BackgroundTransparency = 1,
				Active = false,
			}, {
				Panel = e(HudKit.Panel, {
					position = UDim2.fromScale(0, 0),
					size = UDim2.new(1, 0, 0, 64),
					children = {
						Layout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						Wins = e(StatColumn, { label = "WINS", value = tostring(stats.wins), order = 1 }),
						Kills = e(StatColumn, { label = "KILLS", value = tostring(stats.kills), order = 2 }),
						Deaths = e(StatColumn, { label = "DEATHS", value = tostring(stats.deaths), order = 3 }),
						Ratio = e(StatColumn, { label = "K/D", value = string.format("%.2f", kd), order = 4 }),
					},
				}),
			}),
			Hint = e("TextLabel", {
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				FontFace = UIFonts.ExtraBold,
				Text = hint,
				TextColor3 = Theme.TextMuted,
				TextSize = 14,
				TextWrapped = true,
			}),
		}),
	})
end

local function App()
	local deployed, setDeployed = React.useState(isDeployed)
	React.useEffect(function()
		local connection = player:GetAttributeChangedSignal("Deployed"):Connect(function()
			setDeployed(isDeployed())
		end)
		setDeployed(isDeployed())
		return function()
			connection:Disconnect()
		end
	end, {})
	return if deployed then nil else e(MainMenu)
end

-- A dedicated root prevents React from clearing other HUDs already in PlayerGui.
local menuContainer = Instance.new("Folder")
menuContainer.Name = "MainMenuRoot"
local menuRoot = ReactRoblox.createRoot(menuContainer)
menuRoot:render(ReactRoblox.createPortal(e(App), playerGui))

script.Destroying:Connect(function()
	menuRoot:unmount()
	menuContainer:Destroy()
end)
