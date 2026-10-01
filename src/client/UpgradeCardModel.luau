local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UpgradeCard") :: Model
local Projection = require(script.Parent.UpgradeCardProjection)

local CardModel = {
	-- The local model preserves the uploaded mesh IDs without a runtime InsertService call.
	AssetId = 83993627838046,
	Width = Projection.Width,
	Height = Projection.Height,
	Styles = {
		Damage = {
			color = Theme.Orange,
			image = "rbxassetid://103713376246452",
			description = "Every shot deals\n5 extra damage.",
			buff = "+5 DAMAGE",
		},
		Ammo = {
			color = Theme.Gold,
			image = "rbxassetid://108344419348133",
			description = "Carry 1 more bullet\nin each magazine.",
			buff = "+1 BULLET",
		},
		FireRate = {
			color = Theme.Blue,
			image = "rbxassetid://104341592990847",
			description = "Cut base shot delay\nby another 10%.",
			buff = "-10% SHOT DELAY",
		},
		Health = {
			color = Theme.Green,
			image = "rbxassetid://79870903578934",
			description = "Gain 10 max health\nand heal 10 health.",
			buff = "+10 HEALTH",
		},
		Reload = {
			color = Theme.Purple,
			image = "rbxassetid://110052819157016",
			description = "Cut base reload time\nby another 10%.",
			buff = "-10% RELOAD TIME",
		},
	},
}

function CardModel.mount(viewport: ViewportFrame, color: Color3): (() -> (), (number) -> ())
	local model = template:Clone()
	local body = model:FindFirstChild("Card_Body", true) :: BasePart
	local face = model:FindFirstChild("Card_Colored_Face", true) :: BasePart
	local artwork = model:FindFirstChild("Card_Artwork_Frame", true) :: BasePart
	-- Studio imported this shell lying flat. Derive its front and top from its
	-- named panels so its saved Workspace position/rotation does not affect the HUD.
	local normal = (face.Position - body.Position).Unit
	local toArtwork = artwork.Position - body.Position
	local up = (toArtwork - normal * toArtwork:Dot(normal)).Unit
	local front = CFrame.fromMatrix(body.Position, up:Cross(normal), up, normal)
	local dark = Theme.Ink
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = front:ToObjectSpace(part.CFrame)
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			if part.Name == "Card_Colored_Face" or part.Name == "Card_Back_Face" then
				part.Color = color
			elseif part.Name == "Card_Description_Panel" then
				part.Color = Theme.Paper
			elseif part.Name == "Card_Back_Sigil" then
				part.Color = Color3.new(1, 1, 1)
			else
				part.Color = dark
			end
		end
	end
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = Projection.FieldOfView
	local function setAngle(angle: number)
		-- Orbit around the vertical axis for a horizontal, side-to-side spin.
		camera.CFrame = CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0, Projection.Distance)
	end
	setAngle(0)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return function()
		viewport.CurrentCamera = nil
		camera:Destroy()
		model:Destroy()
	end, setAngle
end

return CardModel
