local InsertService = game:GetService("InsertService")

-- Studio import of assets/revolver/revolver.fbx; see assets/revolver/README.md.
local MODEL_ID = 112277398227118
-- From the Blender build: the steel mesh is 2.06 studs long and the bore sits 0.148 above its center.
local STEEL_LENGTH = 2.06
local BORE_HEIGHT = 0.148
local GRIP_COLOR = Color3.fromRGB(217, 204, 166)
local STEEL_COLOR = Color3.fromRGB(36, 39, 44)

type Template = {
	grip: MeshPart,
	steel: MeshPart,
	gripOffset: CFrame,
	steelOffset: CFrame,
	muzzle: Vector3,
}

local RevolverModel = {}
local template: Template? = nil
local attempted = false

local function load(): Template?
	local ok, asset = pcall(InsertService.LoadAsset, InsertService, MODEL_ID)
	if not ok then
		warn(`Failed to load revolver model {MODEL_ID}: {asset}`)
		return nil
	end
	local grip = asset:FindFirstChild("Revolver_Grip", true)
	local steel = asset:FindFirstChild("Revolver_Steel", true)
	if not (grip and grip:IsA("MeshPart") and steel and steel:IsA("MeshPart")) then
		warn(`Revolver model {MODEL_ID} has no Revolver_Grip and Revolver_Steel MeshParts`)
		asset:Destroy()
		return nil
	end

	-- Derive the gun's axes from the meshes rather than trusting the importer's orientation:
	-- the barrel runs along the steel mesh's longest side, pointing away from the grip.
	local size = steel.Size
	local axis, halfLength = Vector3.zAxis, size.Z / 2
	if size.X >= size.Y and size.X >= size.Z then
		axis, halfLength = Vector3.xAxis, size.X / 2
	elseif size.Y >= size.Z then
		axis, halfLength = Vector3.yAxis, size.Y / 2
	end
	local toSteel = steel.Position - grip.Position
	local forward = steel.CFrame:VectorToWorldSpace(axis)
	if forward:Dot(toSteel) < 0 then
		forward = -forward
	end
	local rise = toSteel - forward * forward:Dot(toSteel)
	if rise.Magnitude < 0.01 then
		warn(`Revolver model {MODEL_ID} has its barrel level with the grip; check the import`)
		asset:Destroy()
		return nil
	end
	local up = rise.Unit
	-- Handle space matches the placeholder gun: barrel along -Z, up along +Y, origin at the hand.
	local frame = CFrame.fromMatrix(grip.Position, up:Cross(-forward), up, -forward)
	local boreHeight = BORE_HEIGHT * halfLength * 2 / STEEL_LENGTH

	local result: Template = {
		grip = grip,
		steel = steel,
		gripOffset = frame:ToObjectSpace(grip.CFrame),
		steelOffset = frame:ToObjectSpace(steel.CFrame),
		muzzle = frame:PointToObjectSpace(steel.Position + forward * halfLength + up * boreHeight),
	}
	grip.Parent = nil
	steel.Parent = nil
	asset:Destroy()
	return result
end

local function weldPart(handle: BasePart, source: MeshPart, offset: CFrame, color: Color3, material: Enum.Material)
	local part = source:Clone()
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = handle.CFrame * offset
	part.Parent = handle.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
end

-- Welds the revolver meshes around the handle and returns the muzzle position in handle space.
-- Returns nil when the model cannot be loaded so the caller can build the placeholder instead.
-- The first call yields while the asset loads; later calls reuse the result.
function RevolverModel.attach(handle: BasePart): Vector3?
	if not attempted then
		attempted = true
		template = load()
	end
	local loaded = template
	if not loaded then
		return nil
	end
	weldPart(handle, loaded.grip, loaded.gripOffset, GRIP_COLOR, Enum.Material.SmoothPlastic)
	weldPart(handle, loaded.steel, loaded.steelOffset, STEEL_COLOR, Enum.Material.Metal)
	-- The handle stays as the hand anchor and sound source; the meshes provide the visuals.
	handle.Transparency = 1
	return loaded.muzzle
end

return RevolverModel
