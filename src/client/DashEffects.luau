local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DashConfig"))
local Theme = require(Shared:WaitForChild("UITheme"))
local GameplayAudio = require(script.Parent.GameplayAudio)
local TRAIL_LIFETIME = 0.18
local MAX_DISTANCE = 250
local BURST_COUNT = 12

type Effect = {
	root: BasePart,
	attachments: { Attachment },
	trails: { Trail },
	burst: Attachment,
	particles: ParticleEmitter,
	sound: Sound,
	connections: { RBXScriptConnection },
	endTask: thread?,
	highlight: Highlight?,
	glowTween: Tween?,
}

local DashEffects = {}
local effects: { [Model]: Effect } = {}

local function stop(effect: Effect)
	if effect.endTask then
		task.cancel(effect.endTask)
		effect.endTask = nil
	end
	for _, trail in effect.trails do trail.Enabled = false end
	if effect.glowTween then
		effect.glowTween:Cancel()
		effect.glowTween = nil
	end
	if effect.highlight then
		effect.highlight:Destroy()
		effect.highlight = nil
	end
end

local function remove(character: Model)
	local effect = effects[character]
	if not effect then return end
	effects[character] = nil
	stop(effect)
	for _, connection in effect.connections do connection:Disconnect() end
	for _, trail in effect.trails do trail:Clear() end
	effect.particles:Clear()
	effect.sound:Destroy()
	for _, attachment in effect.attachments do attachment:Destroy() end
end

local function addTrail(effect: Effect, position: Vector3, width: number)
	local top = Instance.new("Attachment")
	top.Name = "DashTrailTop"
	top.Position = position + Vector3.new(0, width / 2, 0)
	top.Parent = effect.root
	local bottom = Instance.new("Attachment")
	bottom.Name = "DashTrailBottom"
	bottom.Position = position - Vector3.new(0, width / 2, 0)
	bottom.Parent = effect.root
	local trail = Instance.new("Trail")
	trail.Name = "DashTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Enabled = false
	trail.FaceCamera = true
	trail.Lifetime = TRAIL_LIFETIME
	trail.MinLength = 0.05
	trail.MaxLength = Config.SPEED * TRAIL_LIFETIME
	trail.Color = ColorSequence.new(Theme.White, Theme.BlueLight)
	trail.LightEmission = 0.8
	trail.LightInfluence = 0
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.35, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = top
	table.insert(effect.attachments, top)
	table.insert(effect.attachments, bottom)
	table.insert(effect.trails, trail)
end

local function create(character: Model, root: BasePart, humanoid: Humanoid): Effect
	local burst = Instance.new("Attachment")
	burst.Name = "DashBurst"
	burst.Parent = root
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "DashSparks"
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Enabled = false
	particles.Rate = 0
	particles.Color = ColorSequence.new(Theme.White, Theme.BlueLight)
	particles.LightEmission = 1
	particles.LightInfluence = 0
	particles.Lifetime = NumberRange.new(0.15, 0.3)
	particles.Speed = NumberRange.new(12, 24)
	particles.Drag = 8
	particles.EmissionDirection = Enum.NormalId.Front
	particles.SpreadAngle = Vector2.new(55, 55)
	particles.LockedToPart = false
	particles.VelocityInheritance = 0
	particles.Size = NumberSequence.new(0.4, 0)
	particles.Transparency = NumberSequence.new(0.1, 1)
	particles.Parent = burst
	local effect: Effect = {
		root = root, attachments = { burst }, trails = {}, burst = burst,
		particles = particles, connections = {},
		sound = GameplayAudio.create("Dash", root),
	}
	local halfWidth = root.Size.X / 2 + 0.35
	addTrail(effect, Vector3.new(-halfWidth, 0.1, 0), 0.45)
	addTrail(effect, Vector3.new(halfWidth, 0.1, 0), 0.45)
	addTrail(effect, Vector3.new(0, -root.Size.Y / 2, 0), 0.3)
	effects[character] = effect
	effect.connections = {
		humanoid.Died:Connect(function() remove(character) end),
		root.AncestryChanged:Connect(function()
			if not root:IsDescendantOf(workspace) then remove(character) end
		end),
	}
	return effect
end

function DashEffects.play(character: Model?, direction: Vector3)
	-- Streamed-out characters may arrive as nil; never wait and replay a stale dash.
	if not character or not character:IsDescendantOf(workspace) then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - root.Position).Magnitude > MAX_DISTANCE then return end
	local effect = effects[character]
	if effect and effect.root ~= root then
		remove(character)
		effect = nil
	end
	-- Keep emitters and attachments between dashes; no Lua frame loop is needed.
	local active = effect or create(character, root, humanoid)
	stop(active)
	if active.sound.SoundId ~= "" then
		active.sound:Stop()
		active.sound:Play()
	end
	for _, trail in active.trails do
		trail:Clear()
		trail.Enabled = true
	end
	active.burst.WorldCFrame = CFrame.lookAt(root.Position, root.Position - direction)
	active.particles:Emit(BURST_COUNT)
	local highlight = Instance.new("Highlight")
	highlight.Name = "DashGlow"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Theme.BlueLight
	highlight.OutlineColor = Theme.White
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.25
	highlight.Parent = character
	active.highlight = highlight
	active.glowTween = TweenService:Create(highlight, TweenInfo.new(Config.DURATION), {
		FillTransparency = 1, OutlineTransparency = 1,
	})
	active.glowTween:Play()
	active.endTask = task.delay(Config.DURATION, function()
		active.endTask = nil
		stop(active)
	end)
end

function DashEffects.destroy()
	for character in effects do remove(character) end
end

return DashEffects
