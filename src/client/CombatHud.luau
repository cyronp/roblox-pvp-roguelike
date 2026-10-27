local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local DashConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DashConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local HudKit = require(script.Parent.HudKit)
local e = React.createElement

-- The gauge curves around the bottom-right of the crosshair. Angles are in degrees,
-- measured clockwise from screen-right, so 90 points straight down. Gaps are in pixels
-- so the spacing looks the same on both rings.
local DASH_RING = { radius = 46, thickness = 7, from = -6, to = 90, gap = 8 }
local BULLET_RING = { radius = 35, thickness = 4, from = 16, to = 90, gap = 6 }
local OUTLINE = 2
local GAUGE_SIZE = 2 * (DASH_RING.radius + DASH_RING.thickness + OUTLINE) + 8
-- Path2D has no transparency, so dimmed and empty states use solid colours.
local LIT_COLOR = Theme.White
local DIM_COLOR = Theme.TextMuted
local EMPTY_COLOR = Theme.Surface

type DashProgress = { charges: number, readyAt: number, rechargeAt: number }
type AmmoProgress = { ammo: number, capacity: number, reloading: boolean }
type Ring = { radius: number, thickness: number, from: number, to: number, gap: number }
type ArcProps = {
	radius: number,
	thickness: number,
	from: number,
	to: number,
	color: Color3,
	zIndex: number,
}

local function readNumber(instance: Instance?, name: string): number
	local value = if instance then instance:GetAttribute(name) else nil
	return if typeof(value) == "number" then value else 0
end

local function equippedRevolver(character: Model?): Tool?
	local tool = if character then character:FindFirstChild("Revolver") else nil
	return if tool and tool:IsA("Tool") then tool else nil
end

local function readAmmo(tool: Tool?): AmmoProgress
	if not tool then
		return { ammo = UpgradeConfig.BASE_AMMO, capacity = UpgradeConfig.BASE_AMMO, reloading = false }
	end
	local capacity = tool:GetAttribute("MaxAmmo")
	if typeof(capacity) ~= "number" then capacity = UpgradeConfig.BASE_AMMO end
	local ammo = tool:GetAttribute("Ammo")
	if typeof(ammo) ~= "number" then ammo = capacity end
	return {
		ammo = math.clamp(math.floor(ammo), 0, capacity),
		capacity = capacity,
		reloading = tool:GetAttribute("Reloading") == true,
	}
end

-- Slot 1 sits at the bottom of the ring, next to the count, so the gauge drains from the top.
local function slotAngles(ring: Ring, count: number, index: number): (number, number)
	local slot = (ring.to - ring.from) / count
	-- Shrink the gap on big magazines so bullets never collapse to nothing.
	local gap = math.min(math.deg(ring.gap / ring.radius), slot * 0.4)
	return ring.to - index * slot + gap / 2, ring.to - (index - 1) * slot - gap / 2
end

-- One cubic Bezier per arc; the 4/3·tan(θ/4) handle length keeps it on the circle
-- to well under a pixel for the spans used here.
local function arcControlPoints(radius: number, from: number, to: number): { Path2DControlPoint }
	local center = GAUGE_SIZE / 2
	local startAngle, endAngle = math.rad(from), math.rad(to)
	local handle = 4 / 3 * math.tan((endAngle - startAngle) / 4) * radius
	local function pointAt(angle: number): UDim2
		return UDim2.fromOffset(center + math.cos(angle) * radius, center + math.sin(angle) * radius)
	end
	return {
		Path2DControlPoint.new(
			pointAt(startAngle),
			UDim2.new(),
			UDim2.fromOffset(-math.sin(startAngle) * handle, math.cos(startAngle) * handle)
		),
		Path2DControlPoint.new(
			pointAt(endAngle),
			UDim2.fromOffset(math.sin(endAngle) * handle, -math.cos(endAngle) * handle),
			UDim2.new()
		),
	}
end

-- Path2D draws an anti-aliased curve, which reads far cleaner than rotated frames.
local function Arc(props: ArcProps)
	local ref = React.useRef(nil)
	React.useLayoutEffect(function()
		local path = ref.current
		if path then
			path:SetControlPoints(arcControlPoints(props.radius, props.from, props.to))
		end
	end, { props.radius, props.from, props.to })
	return e("Path2D", {
		ref = ref,
		Color3 = props.color,
		Thickness = props.thickness,
		ZIndex = props.zIndex,
	})
end

-- Adds one outlined ring segment to `children`. `fill` grows from the segment's lower end.
local function addSegment(children: { [string]: any }, key: string, ring: Ring, scale: number,
	from: number, to: number, fill: number, color: Color3)
	local radius = ring.radius * scale
	local thickness = ring.thickness * scale
	local outline = OUTLINE * scale
	-- Extend the outline past both ends so the caps get a border too.
	local overhang = math.deg(outline / radius)
	children[`{key}Outline`] = e(Arc, {
		radius = radius, thickness = thickness + 2 * outline,
		from = from - overhang, to = to + overhang,
		color = Theme.Outline, zIndex = 1,
	})
	children[`{key}Track`] = e(Arc, {
		radius = radius, thickness = thickness,
		from = from, to = to,
		color = EMPTY_COLOR, zIndex = 2,
	})
	-- Skip slivers too small to draw cleanly.
	if fill * (to - from) >= 0.5 then
		children[`{key}Fill`] = e(Arc, {
			radius = radius, thickness = thickness,
			from = to - (to - from) * math.min(fill, 1), to = to,
			color = color, zIndex = 3,
		})
	end
end

return function(props: { player: Player })
	local character, setCharacter = React.useState(props.player.Character)
	local tool, setTool = React.useState(equippedRevolver(props.player.Character))
	local dash, setDash = React.useState({ charges = 0, readyAt = 0, rechargeAt = 0 } :: DashProgress)
	local ammo, setAmmo = React.useState(readAmmo(tool))
	local now, setNow = React.useState(workspace:GetServerTimeNow())
	local reloadProgress, setReloadProgress = React.useState(0)
	local hudScale, setHudScale = React.useState(1)

	React.useEffect(function()
		local added = props.player.CharacterAdded:Connect(setCharacter)
		local removing = props.player.CharacterRemoving:Connect(function() setCharacter(nil) end)
		setCharacter(props.player.Character)
		return function()
			added:Disconnect()
			removing:Disconnect()
		end
	end, { props.player })

	React.useEffect(function()
		local function updateTool()
			setTool(equippedRevolver(character))
		end
		local connections: { RBXScriptConnection } = {}
		if character then
			table.insert(connections, character.ChildAdded:Connect(updateTool))
			table.insert(connections, character.ChildRemoved:Connect(updateTool))
		end
		updateTool()
		return function()
			for _, connection in connections do connection:Disconnect() end
		end
	end, { character or false })

	React.useEffect(function()
		local function updateDash()
			setDash({
				charges = readNumber(character, "DashCharges"),
				readyAt = readNumber(character, "DashReadyAt"),
				rechargeAt = readNumber(character, "DashRechargeAt"),
			})
			setNow(workspace:GetServerTimeNow())
		end
		local connections: { RBXScriptConnection } = {}
		if character then
			for _, attribute in { "DashCharges", "DashReadyAt", "DashRechargeAt" } do
				table.insert(connections, character:GetAttributeChangedSignal(attribute):Connect(updateDash))
			end
		end
		updateDash()
		return function()
			for _, connection in connections do connection:Disconnect() end
		end
	end, { character or false })

	React.useEffect(function()
		local function updateAmmo()
			setAmmo(readAmmo(tool))
		end
		local connections: { RBXScriptConnection } = {}
		if tool then
			for _, attribute in { "Ammo", "MaxAmmo", "Reloading" } do
				table.insert(connections, tool:GetAttributeChangedSignal(attribute):Connect(updateAmmo))
			end
		end
		updateAmmo()
		return function()
			for _, connection in connections do connection:Disconnect() end
		end
	end, { tool or false })

	React.useEffect(function()
		local deadline = math.max(dash.readyAt, dash.rechargeAt)
		if deadline <= workspace:GetServerTimeNow() then return end
		local timer = task.spawn(function()
			repeat
				task.wait(0.1)
				setNow(workspace:GetServerTimeNow())
			until workspace:GetServerTimeNow() >= deadline
		end)
		return function()
			if coroutine.status(timer) ~= "dead" then task.cancel(timer) end
		end
	end, { dash.readyAt, dash.rechargeAt })

	React.useEffect(function()
		setReloadProgress(0)
		if not ammo.reloading then
			return
		end
		-- Presentation only: the server's reload timer still decides when ammo refills.
		local configured = if tool then tool:GetAttribute("ReloadTime") else nil
		local duration = if typeof(configured) == "number" and configured > 0
			then configured
			else UpgradeConfig.BASE_RELOAD_TIME
		local startedAt = os.clock()
		local timer = task.spawn(function()
			repeat
				task.wait(0.05)
				setReloadProgress(math.min((os.clock() - startedAt) / duration, 1))
			until os.clock() - startedAt >= duration
		end)
		return function()
			if coroutine.status(timer) ~= "dead" then task.cancel(timer) end
		end
	end, { ammo.reloading })

	local locked = now < dash.readyAt
	local remaining = math.max(0, dash.rechargeAt - now)
	local gauge = {}
	for index = 1, DashConfig.MAX_CHARGES do
		local from, to = slotAngles(DASH_RING, DashConfig.MAX_CHARGES, index)
		local ready = index <= dash.charges
		local fill = if ready then 1
			elseif index == dash.charges + 1 and dash.rechargeAt > 0 then 1 - remaining / DashConfig.RECHARGE_TIME
			else 0
		-- Charges still refilling, or blocked by the post-dash cooldown, stay dim.
		addSegment(gauge, `Dash{index}`, DASH_RING, hudScale, from, to, fill,
			if ready and not locked then LIT_COLOR else DIM_COLOR)
	end

	if tool then
		local capacity = math.max(ammo.capacity, 1)
		local refilled = math.floor(reloadProgress * capacity)
		for index = 1, capacity do
			local from, to = slotAngles(BULLET_RING, capacity, index)
			local loaded = if ammo.reloading then index <= refilled else index <= ammo.ammo
			addSegment(gauge, `Bullet{index}`, BULLET_RING, hudScale, from, to, if loaded then 1 else 0,
				if ammo.reloading then DIM_COLOR else LIT_COLOR)
		end

		local empty = ammo.ammo == 0 and not ammo.reloading
		local countColor = if empty then Theme.DangerLight else Theme.Text
		local smallSize = math.round(15 * hudScale)
		gauge.Count = HudKit.label({
			Position = UDim2.fromOffset(
				GAUGE_SIZE / 2 - 4 * hudScale,
				GAUGE_SIZE / 2 + (DASH_RING.radius + DASH_RING.thickness / 2 + OUTLINE + 4) * hudScale
			),
			Size = UDim2.fromOffset(140 * hudScale, 26 * hudScale),
			RichText = true,
			Text = if ammo.reloading
				then `<font size="{smallSize}" color="#{Theme.GoldLight:ToHex()}">RELOADING</font>`
				else `<font color="#{countColor:ToHex()}">{ammo.ammo}</font>`
					.. `<font size="{smallSize}" color="#{Theme.TextMuted:ToHex()}">  /  {ammo.capacity}</font>`,
			TextSize = math.round(22 * hudScale),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			ZIndex = 4,
		}, 2)
	end

	return e("ScreenGui", {
		Name = "CombatHud",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		-- Match the crosshair's ScreenGui so the gauge stays centred on the reticle.
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Bounds = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Active = false,
			[React.Change.AbsoluteSize] = function(frame: Frame)
				setHudScale(math.clamp(frame.AbsoluteSize.X / 900, 0.8, 1))
			end,
		}, {
			-- A fixed-size box centred on the crosshair. Geometry is scaled by hand rather than
			-- with UIScale, since UIScale isn't documented to affect Path2D.
			Gauge = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(GAUGE_SIZE, GAUGE_SIZE),
				BackgroundTransparency = 1,
				Active = false,
				Visible = character ~= nil and (tool ~= nil or dash.charges > 0 or dash.rechargeAt > 0),
			}, gauge),
		}),
	})
end
