local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local HudKit = require(script.Parent.HudKit)
local e = React.createElement

local LOW_HEALTH = 0.35

type Health = { current: number, max: number }
type Props = { player: Player, position: UDim2, size: UDim2 }

local function findHumanoid(character: Model?): Humanoid?
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function readHealth(humanoid: Humanoid?): Health
	if not humanoid then
		return { current = 0, max = 100 }
	end
	return { current = math.max(0, humanoid.Health), max = math.max(1, humanoid.MaxHealth) }
end

-- Displays the replicated Humanoid health; the server remains authoritative.
return function(props: Props)
	local humanoid, setHumanoid = React.useState(findHumanoid(props.player.Character))
	local health, setHealth = React.useState(readHealth(humanoid))
	local fillRef = React.useRef(nil)
	local trailRef = React.useRef(nil)
	local previousFraction = React.useRef(1)
	local fraction = math.clamp(health.current / health.max, 0, 1)

	React.useEffect(function()
		local childConnection: RBXScriptConnection? = nil
		local function watch(character: Model?)
			if childConnection then
				childConnection:Disconnect()
				childConnection = nil
			end
			setHumanoid(findHumanoid(character))
			if character and not findHumanoid(character) then
				childConnection = character.ChildAdded:Connect(function(child: Instance)
					if child:IsA("Humanoid") then
						setHumanoid(child)
					end
				end)
			end
		end
		local added = props.player.CharacterAdded:Connect(watch)
		local removing = props.player.CharacterRemoving:Connect(function()
			watch(nil)
		end)
		watch(props.player.Character)
		return function()
			added:Disconnect()
			removing:Disconnect()
			if childConnection then
				childConnection:Disconnect()
			end
		end
	end, { props.player })

	React.useEffect(function()
		if not humanoid then
			return
		end
		local function update()
			setHealth(readHealth(humanoid))
		end
		local healthConnection = humanoid.HealthChanged:Connect(update)
		local maxConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
		update()
		return function()
			healthConnection:Disconnect()
			maxConnection:Disconnect()
		end
	end, { humanoid or false })

	React.useEffect(function()
		local fill = fillRef.current
		local trail = trailRef.current
		if not fill or not trail then
			return
		end
		local target = UDim2.fromScale(fraction, 1)
		local tweens: { Tween } = {
			TweenService:Create(fill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = target }),
		}
		if fraction < previousFraction.current then
			-- The pale trail lingers briefly so players can read how much damage they just took.
			table.insert(tweens, TweenService:Create(trail,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { Size = target }))
		else
			trail.Size = target
		end
		previousFraction.current = fraction
		for _, tween in tweens do
			tween:Play()
		end
		return function()
			for _, tween in tweens do
				tween:Cancel()
				tween:Destroy()
			end
		end
	end, { fraction })

	return e("Frame", {
		Name = "Health",
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		Active = false,
		Visible = humanoid ~= nil,
	}, {
		Meter = e(HudKit.Meter, {
			position = UDim2.fromScale(0, 0),
			size = UDim2.fromScale(1, 1),
			fraction = fraction,
			fillRef = fillRef,
			gradient = if fraction <= LOW_HEALTH then Theme.DangerGradient else Theme.GreenGradient,
			children = {
				Trail = e("Frame", {
					ref = trailRef,
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.Paper,
					BackgroundTransparency = 0.15,
					BorderSizePixel = 0,
					ZIndex = 1,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(0, Theme.Radius) }) }),
				Amount = HudKit.label({
					Size = UDim2.fromScale(1, 1),
					Text = `{math.ceil(health.current)} / {math.ceil(health.max)}`,
					TextSize = 18,
					ZIndex = 3,
				}, 2),
			},
		}),
	})
end
